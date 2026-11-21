# Plan: WYSIWYG editing (rich text with hidden markup)

## Goal

Edit formatted text as it looks: bold looks bold, and there are no markers on screen.
The formatting is stored in an underlying text format in the file. The user sees that
format **only when they ask for it** ("Show markup"), never because the cursor
moves onto it.

First prototype: **bold, italic and font size**. It renders with the existing
GtkSourceView (a `GtkTextView`), with no HTML or WebKit.

## Today (checked 2026-11-21)

- Hyperplaintext styles are visible marker characters in the text: `⦁bold⦁`,
  `╱italic╱`, `❙title❙`, `⟦link⟧`, and `◼` for headings. `apply_style_markers`
  (`buffer.rb`) inserts them. `lang/hyperplaintext.lang` colors them. Visual
  `, t b`, `, t i` and `, t c` and `C , t 1`… are bound to `style.*`.
- `Buffer < String` holds the text. Every change is a delta
  `[pos, INSERT|DELETE, len, text]`, applied by `Buffer#run_delta` (`buffer.rb:841`).
  `run_delta` already updates position-based data on each change
  (`update_highlights`, `update_line_ends`). `GtkView#handle_deltas`
  (`gui_sourceview.rb:749`) applies the same deltas to the GTK buffer.
- **There's a precedent for buffer text that differs from the file:** closed folds
  (`fold.rb`) are taken out of the buffer string, and `content_for_disk` puts them
  back on save and autosave.

## Design

### 1. The visible text is the buffer

`Buffer` (the String) holds only the text the user sees, with no markers. So the
cursor can't land inside markup, and everything that works on text keeps working
unchanged: motions, counts, search, undo of text changes, `j`/`k` columns, macros,
autocomplete.

The formatting lives beside it in a **span model**, and the file format exists only
on disk:

```
file (markup)  ──parse──▶  visible text (Buffer)  +  spans (RichText)
               ◀─serialize─           │                    │
                                      └──── GTK buffer + tags (view)
```

### 2. Span model (`lib/vimamsa/rich_text.rb`)

A `RichText` object per buffer (`buf.rich`, nil for normal buffers) holds attribute
runs over the visible text:

```ruby
# half-open ranges over Buffer positions; overlapping runs are allowed
[ { range: 0...5,   attr: :bold },
  { range: 3...9,   attr: :italic },
  { range: 12...20, attr: [:size, 1.5] } ]
```

Interface (so the storage can be swapped later):
- `attrs_at(pos)`: the attributes in effect at `pos`
- `runs_in(range)`: the runs that overlap `range`, clipped to it
- `apply(range, attr)` / `remove(range, attr)`: merges with neighbors, splits as needed
- `on_insert(pos, len, attrs)`: shifts later runs, extends the run being typed in, and
  adds `attrs` for the new text
- `on_delete(pos, len)`: shrinks or drops runs, and returns the removed pieces for
  undo

**Storage, in steps:**
1. **Prototype:** one sorted array per attribute, of non-overlapping `[start, end, value]`.
   Overlaps between *different* attributes are then free. Each edit costs O(runs),
   which is fine up to tens of thousands of runs.
2. **If profiling asks for it:** a balanced binary tree (or a rope) whose nodes store
   their subtree's length. Finding the runs at a position and shifting them after an
   edit are then O(log n). Only `RichText` changes, because callers use the interface.

The GTK side needs no extra structure. `GtkTextBuffer` is already a B-tree whose
tags move with the text.

### 3. Keeping things in sync

- **The Ruby spans are the source of truth. The GTK tags only mirror them.**
- `run_delta` calls `rich.on_insert` / `rich.on_delete`, next to `update_highlights`.
- `handle_deltas` applies the tags after each insert: `apply_tag` over the inserted
  range, for the attributes `rich.attrs_at` gives. A plain GTK insert has no tags, so
  the result is deterministic. A delete needs no tag work.
- Changes are changesets (`doc/delta_syntax_plan.md`). Formatting changes are
  `retain` operations with attributes (`retain(5, bold: true)`), and inserted text can
  carry its attributes. Undo, redo, position mapping and the GTK update then use the
  same path as text changes. `RichText` updates its runs through the changeset's
  `map_pos` and attributes, instead of separate `on_insert` / `on_delete` hooks, once
  step 3 of that plan exists.
- A test compares the GTK tag ranges with the `RichText` runs after random edits, in
  the style of `test_random_edit`.

### 4. Typing and editing rules

- **Typing extends the style of the character before the cursor:** at the end of a
  bold word the text stays bold, and at the start it doesn't. This is like word
  processors.
- **Typing style:** toggling bold with no selection (Insert mode) sets the style for
  the next characters typed. It's shown in the status area (**B** *I* 150%) and
  cleared when the cursor moves.
- **Undo:** a changeset's delete operations store the removed text with its
  attributes, so `invert` puts the spans back. Formatting changes invert like text
  changes. One Insert-mode session stays one undo step (one composed changeset).
- **Registers (prototype):** yank and put copy plain text, and pasted text gets the
  typing style. Later, internal registers keep the spans, and the system clipboard
  gets plain text.
- **Vim operators** work on the visible text. `d`, `c` and `x` drop the spans of what
  they delete, through `on_delete`. Nothing needs to know about formatting.

### 5. Rendering (GtkTextView)

- Tags made once per buffer:
  - `rich-bold`: `weight = 700`
  - `rich-italic`: `style = ITALIC`
  - `rich-size-<n>`: `scale = n`, from a small fixed list such as 0.8, 1.2, 1.5 and 2.0,
    so the tags stay few
- Rich tags get a higher priority than syntax-highlighting tags. In a rich buffer,
  turn the hyperplaintext language off, or use a variant without the marker rules,
  because there are no markers left to color.
- Things to check with larger text:
  - cursor drawing (`pos_to_coord`)
  - easy-jump label placement
  - line-height assumptions (in the file panel, scrolling and `view.center`)
  - italic in the user's font (some monospace fonts have no italic and get a slanted
    fallback)

### 6. The file format (hidden)

The format is a serializer behind an interface: `parse(markup) → [text, runs]` and
`serialize(text, runs) → markup`. Several can exist.

**For the prototype, use the hyperplaintext markers.** Files then stay readable and
diffable, and existing hpt files open in rich mode:
- bold `⦁…⦁` and italic `╱…╱`, as today
- size: a new marker, for example `⸨150%|…⸩`

  Decide the exact characters before step 2. They must be rare in normal text and
  easy to type in "Show markup".
- **Escaping:** a literal marker character in the text is written doubled, or with a
  backslash. The test is that `parse(serialize(x)) == x` for random text and runs.

Later serializers: Markdown (`**`, `*`, `#` headings for size) and an HTML subset
(`<b>`, `<i>`, `<span style="font-size:150%">`) for export. The second serializer is
also the test that the model doesn't depend on the format.

Save and autosave go through `content_for_disk`, as folds do. The serializer runs
there, after the folds are put back.

### 7. "Show markup"

- **Prototype:** `rich.markup.show` opens the serialized text in a separate, read-only
  buffer, with the cursor at the matching position.
- **Later:** editable markup. You edit that buffer and apply it back with
  `rich.markup.apply`: parse, then replace the text and runs as one undo step.
  Alternatively, switch the same buffer between rich and markup mode in place.
- `rich.toggle` turns rich mode on or off for a buffer. Turning it off converts to
  the plain hpt buffer with visible markers (today's behavior).

### 8. Which buffers are rich

- Rich mode is off by default. Turn it on with `cnf.rich.enabled = true` and a list
  of languages (`cnf.rich.langs = ["hyperplaintext"]`), or per buffer with
  `rich.toggle`.
- Not rich: buffers with LSP. Positions sent to the language server would be wrong,
  because the file holds markup the buffer doesn't.
- Search and grep across files (`grep.files`) search the file contents, so they see
  the markup. That's acceptable for now. "Jump to match" maps the position from the
  markup to the visible text, using the parse result.

### 9. Actions and keys

The naming follows `doc/action_names_plan.md`:
- `rich.bold.toggle`, `rich.italic.toggle`, `rich.size.up`, `rich.size.down`,
  `rich.size.reset`
- `rich.markup.show`, `rich.toggle`

Keys: in rich buffers, the existing `style.*` bindings (Visual `, t b`, `, t i`,
`, t c`) call the rich actions instead of inserting markers. Size gets `, t +`,
`, t -` and `, t 0`. No new ctrl or alt chords. Insert mode needs a way to set the
typing style without leaving Insert mode. Decide that after trying the prototype.

## Prototype scope

In:
- `RichText` with arrays
- the hpt serializer for bold, italic and size, with escaping
- GTK tags
- typing rules, and undo of text and format changes
- `rich.markup.show` (read-only)
- `rich.toggle`
- the actions above

Out, for later:
- editable markup view
- formatted registers and clipboard
- Markdown and HTML serializers
- links, headings as line styles, images, lists
- the tree storage
- rich buffers in two-column mode

## Tests

- `RichText` unit cases: insert and delete at, inside and around runs; merging and
  splitting; overlapping attributes.
- Serializer round trip: random text and runs go through serialize and parse and come
  back the same. Marker characters in the text are escaped.
- GTK sync: after random inserts, deletes and format toggles, the GTK tag ranges
  equal the `RichText` runs.
- Editing: `d w` over half a bold word, `x` at a run edge, and typing after a bold
  word extends it. Undo and redo restore both the text and the formatting.
- Save and reload give the same text and runs. The file holds markup, and autosave
  writes the same thing.
- "Show markup" shows the serialized text and the right cursor position.

## Order

1. `RichText` (arrays) and its unit tests. No GUI yet.
2. The hpt serializer (bold, italic, size), round-trip tests, and the choice of the
   size marker.
3. Hook it into `run_delta`, `handle_deltas`, load and `content_for_disk`. Add the GTK
   tags and the sync test.
4. Attributes on changeset operations (step 6 of `doc/delta_syntax_plan.md`), undo
   and redo of formatting, and the typing rules.
5. Actions and keys, the typing style in the status area, and `rich.markup.show`.
6. Try it on real notes. Decide the Insert-mode keys, and whether the array storage is
   fast enough.
7. Later: editable markup, formatted registers, the Markdown and HTML serializers, and
   more attributes.

Run the full suite in the VM after each step.
