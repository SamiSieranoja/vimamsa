# Plan: line ends in a treap (`LineTree`)

## Why

`Buffer#@line_ends` is a sorted Array of the positions of every `\n`. Lookups are
fast (`[i]`, `bsearch_index`), but every edit shifts all later entries in a Ruby
loop (`update_line_ends`, `buffer.rb`): 0.65 ms per edit at 10k lines and 6.3 ms at
100k (measured 2026-11-21, see `doc/TODO.md`, "Performance"). A replace pays it
twice.

An implicit treap of lines makes edits and lookups O(log n) expected. Background
and an interactive walkthrough of the operations: the "Treap of Lines" artifact,
and the "tree structures" discussion in `doc/TODO.md`.

## Design

`lib/vimamsa/line_tree.rb`, class `LineTree`.

- **One node per line**, in document order. Lines are ordered by position in the
  tree; line numbers aren't stored.
  - `len`: characters in the line, its `\n` included
  - `prio`: random, and a parent's is higher than its children's (heap order)
  - `cnt` and `sum`: lines and characters in the subtree
- **The last node is the text after the last `\n`** (usually empty, because buffers
  end with `\n`). So every position, including the end of the text, belongs to a
  node, and `size` (the number of newlines) is the node count minus 1.
- Core operations, as in the artifact: `split` and `merge` by line count, a descent by
  line number or by character position, and an O(k) build from a list of lengths.

### Array-compatible interface

`@line_ends` stays the name, and the tree answers the Array methods the code
uses. The about 75 call sites (`buffer.rb`, `buffer_cursor.rb`, `fold.rb`,
`vim_operators.rb`, `vim_core.rb`, `bookmarks.rb`, `gui_file_panel.rb`) then don't
change:

| Method | Meaning | Cost |
|---|---|---|
| `size` | number of `\n` | O(1) |
| `[i]` (negative `i` allowed) | position of the i-th `\n` | O(log n) |
| `bsearch_index { \|x\| … }` / `bsearch { … }` | find-minimum binary search over the `\n` positions, as `Array#bsearch` | O(log n), one descent |
| `to_a`, `==` | the plain Array, for tests and checks | O(n) |

Extra methods for later callers: `line_start(i)`, `line_len(i)`, `line_at(pos)` →
`[line, column]`, `total`.

### Updates

`Buffer#update_line_ends(pos, changeamount, changestr)` calls
`@line_ends.insert(pos, text)` or `@line_ends.delete(pos, removed_text)`. Both
come from `run_delta`, which already knows the inserted or removed text.

- **Insert `text` at `pos`** (on line j, column c), where `text` has k newlines:
  - **k = 0:** line j gets longer. Only the sums on its path change.
  - **k > 0:**
    - line j becomes `c + first piece + 1`
    - the middle pieces become new lines
    - the last piece plus the rest of line j becomes the last new line
    - the k new lines are added with one split, an O(k) build and two merges
- **Delete `n` chars at `pos`**, where the removed text has m newlines:
  - **m = 0:** line j gets shorter.
  - **m > 0:** lines j … j + m become one line, of length `c + (len(j + m) − end column)`.
    Lines j + 1 … j + m are removed with two splits and a merge.
- **A full rebuild** (`set_content`, `recalc_line_ends`) builds the tree from
  `each_line` in O(n). There's no regex scan any more.

## Tests

- **Random edits compared with a reference:** apply random inserts and deletes
  (with and without newlines, at the start, middle and end, including non-ASCII
  text) to a String and to a `LineTree`, and compare `to_a` with the newline
  positions of the String after every step.
- **Invariants after each step:** heap order, and `cnt` / `sum` consistent.
- **Array interface:** `[]` with negative indexes, `bsearch_index` and `bsearch`
  equal the Array versions for every position.
- **Buffer:** editing a buffer keeps `line_ends.to_a` equal to a fresh scan. The
  existing suite covers the callers.
- **Performance:** 1000 single-character inserts in the middle of a 100k-line
  buffer must be well below the old cost (about 6 ms each).

## Order

1. `LineTree` with unit tests (no Buffer changes).
2. Buffer uses it: `set_content`, `update_line_ends`, `recalc_line_ends`,
   `sanity_check_line_ends`. `require` in `rbvma.rb`. Full suite in the VM.
3. Measure the edit cost at 100k lines, and record it in `doc/TODO.md`.
4. Later: call sites that loop over all lines (`fold.rb`'s fold search) can walk
   the tree in order instead of calling `[i]` per line. Per-line data (the
   highlighter state, tokens) can move into the nodes when own highlighting comes.
