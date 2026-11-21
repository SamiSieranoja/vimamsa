# Plan: a better delta (change) format

## Today (checked 2026-11-21)

Every text change is a delta array `[pos, op, len, text]`. It's applied by
`Buffer#run_delta` (`buffer.rb:841`), mirrored to GTK by `GtkView#handle_deltas`
(`gui_sourceview.rb:749`), and grouped for undo in `@edit_history`.

Problems:
- **Magic numbers and indexes:** `INSERT = 2` and `DELETE = 3001` (`constants.rb`).
  `d[1] == DELETE` and similar checks appear in 9 places, and comments explain what
  `d[3]` is.
- **Redundant or inconsistent length:** an insert carries both `len` and `text`, and
  undo creates `[pos, INSERT, 0, text]` with length 0.
- **Mutated in place:** a delete's text is filled in afterwards
  (`delta[3] = slice!`), and `add_delta` clamps `delta[2]`. The same delta means
  different things before and after it runs.
- **Ad-hoc extensions:** the LSP code clones a delta and adds `[4]` and `[5]` (line and
  column). The experimental btree converts it to a separate `Delta` class.
- **A replace is two deltas:** a delete plus an insert. That means two GTK updates,
  two LSP change events, and two undo steps that have to be grouped.
- **Hard to extend:** a new kind (FORMAT for `doc/wysiwyg_plan.md`) needs every `case`
  changed.
- **Every position-based structure is shifted by its own code in `run_delta`:** marks,
  `edit_pos_history`, highlights (`update_highlights`), line ends, fold anchors and the
  cursor.

Deltas aren't saved anywhere except in debug dumps, so the format can change
without migrating any data. There are 18 `add_delta([...])` call sites.

## Options

### 1. Named fields with a Struct (smallest step)

```ruby
Delta = Struct.new(:pos, :op, :len, :text) do   # op: :insert / :delete
  def self.insert(pos, text) = new(pos, :insert, text.size, text)
  def self.delete(pos, len)  = new(pos, :delete, len, nil)
  def end_pos = pos + len
end
```

- A Struct still answers `d[0]`, so the old indexed code keeps working while it's
  migrated file by file.
- Symbols replace the magic numbers, and the constructors derive `len`.
- *Cons:* only the syntax gets better. Mutation, the two-delta replace and the `case`
  statements stay.

### 2. One replace edit

Every change is "at `pos`, replace `removed` with `inserted`":

```ruby
Edit = Data.define(:pos, :removed, :inserted, :attrs) do   # immutable (Ruby 3.2+)
  def self.insert(pos, text)       = new(pos, "", text, nil)
  def self.delete(pos, text)       = new(pos, text, "", nil)
  def self.replace(pos, old, new_) = new(pos, old, new_, nil)
  def inverse   = with(removed: inserted, inserted: removed)
  def delta_len = inserted.size - removed.size        # for shifting positions
end
```

- **Insert, delete and replace have one shape.** `replace_range`, the case transforms
  and `:s` become one edit, so one GTK update and one undo step.
- **Undo is `inverse`.** That replaces `apply_inverse_delta`.
- **It matches LSP directly:** a change event is "replace this range with this text".
  The `[4]` and `[5]` hack goes away, and line and column are computed where they're
  needed.
- **It's immutable.** `run_delta` reads the text to be removed before it creates the
  edit, so nothing is filled in afterwards.
- **`attrs` makes room for WYSIWYG formatting.** Inserted text can carry its spans,
  and a delete carries the spans it removed, so undo restores them.
- *Cons:* touches the 18 `add_delta` call sites and the 9 op checks. Each change is
  mechanical.

### 3. Polymorphic edit classes

```ruby
class Edit::Insert < Edit; def apply(buf) …; def inverse = Edit::Delete.new(pos, text); def shift(p) …; def to_gtk(view) …; end
class Edit::Delete < Edit; …; end
class Edit::Format < Edit; …; end   # WYSIWYG
```

- Each kind knows how to apply itself, invert itself, move a position past itself
  (marks, highlights, fold anchors) and update GTK. New kinds don't touch any `case`.
- *Cons:* more classes and indirection for what is mostly two operations. The logic for
  one consumer (GTK, LSP) gets spread over several classes.
- Can be combined with option 2: a replace edit plus a separate `Format` class.

### 4. Changesets (OT-style, like CodeMirror and Quill) — chosen

A changeset describes one change to the whole document, as a walk from start to
end with three operations:
- `retain(n)`: keep the next `n` characters unchanged
- `delete(n)`: remove the next `n` characters
- `insert(text)`: add `text` here

The retains and deletes together cover the whole old document.

Example. `hello world` → `hello there!`:

```
retain(6)  delete(5)  insert("there!")
└ "hello " ┘└ "world" ┘
```

The old length is 6 + 5 = 11, and the new length is 6 + 6 = 12. An insert of `X` at
position 3 is `retain(3) insert("X") retain(8)`.

The delta array describes *one* change at one position. A changeset describes *what
happened to every part* of the document. That makes these operations possible:

1. **Compose:** `a.compose(b)` is one changeset with the effect of a and then b. An
   undo group (`i … esc`), a macro run or a `:s` over the file becomes a single
   change for GTK, LSP and undo.
2. **Invert:** swaps the inserts and deletes (the deleted text is stored). Undo is
   applying the inverse.
3. **Map positions:** `cs.map_pos(p)` gives where old position `p` ends up. A side
   argument decides whether an insert at exactly `p` goes before or after it.

   This one function replaces the separate shifting code for marks,
   `edit_pos_history`, highlights, line ends, fold anchors, the cursor and the WYSIWYG
   spans.
4. **Transform:** `transform(a, b)` rewrites b, which was made against the same old
   document as a, so that it applies after a with the same intent. For example, if a
   inserts at 2 and b deletes at 8, then b′ deletes at 8 + the length of a's insert.

   This is the basis of collaborative editing. Locally it serves multiple cursors, and
   external changes that arrive while editing: a file reload, or LSP edits computed
   against an older version.
5. **Attributes (rich text, Quill's Delta format):** operations carry formatting.

   ```
   retain(6)  retain(5, bold: true)    # make "world" bold
   insert("new", italic: true)         # insert italic text
   retain(3, bold: nil)                # remove bold
   ```

   Text and formatting changes then share one mechanism: undo, compose and position
   mapping work for formatting too.

Sketch:

```ruby
buf.change { |c| c.retain(6).delete(5).insert("there!") }   # one undo step
buf.apply(ChangeSet.replace(6, "world", "there!"))
mark.pos = cs.map_pos(mark.pos)
undo_group = undo_group.compose(cs)
buf.apply(undo_group.invert)                                  # undo
```

**The document length never needs to be passed by callers:**
- **The trailing retain is implicit.** A changeset ends with "keep the rest", and
  `apply` fills that in from the document's actual length. CodeMirror and Quill both
  work this way.
- **Position constructors cover the common case:** `ChangeSet.insert(pos, text)`,
  `ChangeSet.replace(pos, old, new)`.
- **Built from the buffer:** `buf.changeset` / `buf.change { |c| … }` fill in the
  length and the buffer's `@version`.
- **The version, not the length, detects a stale changeset.** One built against an
  older text (an LSP reply, a background thread) is refused on `apply`. A length check
  catches that only when the size happened to change.
- Compose and transform get the lengths from the changesets themselves.

Costs:
- **Every change site changes.** The 18 `add_delta` calls and the code that reads
  deltas would have to build or consume changesets.
- **Compose and transform are hard to get right** for every combination of retain,
  insert and delete, with attributes too. They need property tests, such as random
  changesets checked with `apply(compose(a, b)) == apply(b, apply(a))`.
- **Size:** a changeset spanning a big file must be stored compactly. Merge runs and
  leave the trailing retain implicit. CodeMirror uses a flat array of lengths.
- **Most of the gain is in features Vimamsa doesn't have yet:** multiple cursors,
  collaboration, merging outside edits.

## Decision: changesets (option 4)

Changesets are the change format (decided 2026-11-21). Options 1–3 are kept above
for the record.

Why:
- **Position mapping:** one `map_pos` replaces the separate shifting code for marks,
  highlights, line ends, fold anchors, the edit history and the cursor.
- **Formatting:** attributes on operations give `doc/wysiwyg_plan.md` text and
  formatting changes, undo and position mapping through one mechanism. No separate
  FORMAT delta is needed.
- **Grouping:** composing turns undo groups, macro runs and `:s` into one change for
  GTK, LSP and undo.
- **Future features:** multiple cursors, merging outside changes (reload, LSP edits
  against an older version) and possibly collaboration need `transform`. It can be
  added later on the same format.

The single-edit convenience of option 2 is kept as constructors:
`ChangeSet.insert(pos, text)`, `ChangeSet.delete(pos, text)` and
`ChangeSet.replace(pos, old, new)`. Most call sites need nothing more.

## Design

### Format

```ruby
# lib/vimamsa/changeset.rb
cs = ChangeSet.new                       # trailing retain implicit
       .retain(6)
       .delete("world")                   # deleted text is stored, for invert
       .insert("there!", bold: true)      # optional attributes
```

- Operations are stored compactly: neighbors of the same kind are merged, and the
  trailing retain is implicit. A flat array of `[op, value, attrs]` is enough at first.
- **Deletes store the removed text** (and its attributes), so `invert` needs no
  document. The text is read from the buffer when the changeset is applied, if the
  caller gave only a length. After that, the changeset is frozen.
- **Version:** `buf.changeset` / `buf.change { |c| … }` record the buffer's
  `@version`. `apply` refuses a changeset built for another version, unless it is
  first transformed (later) or explicitly rebased.

### Operations

| Method | Purpose | Needed for |
|---|---|---|
| `apply(buf)` | change the text, then notify GTK, LSP, the position mappers and undo | step 2 |
| `invert` | undo | step 2 |
| `map_pos(p, assoc: :before/:after)` | where an old position ends up | step 3 |
| `compose(other)` | one changeset with the effect of both | step 4 |
| `each_edit` | the changes as `(pos, removed, inserted, attrs)` in new-document positions, front to back | GTK, LSP |
| `transform(other)` | concurrent changes | later |

### Consumers

- **Buffer text:** `run_delta` becomes `apply_changeset`. It walks the operations
  front to back, keeps a running offset, and uses `String#[]=` per edit. That's cheap,
  because changesets from typing have one or two edits.
- **GTK** (`handle_deltas`): one `delete` / `insert` per `each_edit`, inside a
  `begin_user_action` block, so GTK sees one change. Then apply the attribute tags
  (WYSIWYG).
- **LSP:** incremental sync takes an array of content changes, applied in order. Send
  one per `each_edit`. Line and column are computed from the document as it is at
  that point in the sequence, so the `[4]` / `[5]` clone goes. Fall back to full
  sync for very large changesets.
- **Undo:** an undo group is one composed changeset. Undo applies `invert`, and redo
  applies the changeset again. Grouping (`new_undo_group`) stays as it is and only
  composes instead of appending.
- **Position-based data:** everything that holds positions registers with the buffer
  and is updated through `map_pos` after each apply. That covers marks,
  `edit_pos_history`, highlights, line ends, fold anchors, the cursor and the WYSIWYG
  spans. Line ends may stay specialized for speed, but are checked against `map_pos`
  in tests.
- **Macros** record actions, not deltas, so they don't change.

### Migration

Keep the old interface as an adapter while the call sites move:
`add_delta([pos, INSERT, len, text])` builds `ChangeSet.insert(pos, text)`, and the
delete form builds `ChangeSet.delete(pos, len)`. Everything inside the buffer works
on changesets from step 2. The 18 call sites then move over one file at a time, and
the adapter is removed at the end.

## Tests

Property tests with random documents and random changesets (in the style of
`test_random_edit`):
- `apply(invert(a), apply(a, doc)) == doc`
- `apply(compose(a, b), doc) == apply(b, apply(a, doc))`
- `map_pos` agrees with where a marker character placed at `p` ends up
- `each_edit` applied one by one gives the same text as `apply`
- After random edits, the GTK buffer text equals the `Buffer` string, and the LSP
  document rebuilt from the sent changes equals it too.
- A changeset built for an older `@version` is refused.

Plus examples: `hello world` → `hello there!`, an insert at 0 and at the end, a
delete of everything, a replace over a line break, and merging neighbors of the same
kind.

## Order

1. `ChangeSet` with the constructors, `apply` to a plain string, `invert`, `each_edit`,
   and the property tests. No editor integration yet.
2. The buffer applies changesets: `run_delta` → `apply_changeset`, with `add_delta` as an
   adapter. GTK uses `each_edit`. Undo groups hold changesets (append for now). LSP is
   sent one change per `each_edit`.
3. `map_pos`, and moving the position updates from `run_delta` onto it, one structure
   at a time: marks, edit history, highlights, fold anchors, cursor. Keep line ends
   specialized if faster, but tested.
4. `compose`: undo groups become one changeset. `replace_range`, the case transforms
   and `:s` become one changeset each.
5. Convert the 18 call sites to the constructors. Remove the adapter, the `INSERT` /
   `DELETE` constants and the experimental btree `Delta` class.
6. Attributes on operations, for `doc/wysiwyg_plan.md` (replaces its FORMAT delta).
7. Later: `transform`, for multiple cursors and outside changes.

Run the full suite in the VM after each step. `test_random_edit` covers undo and
redo.
