# Plan: better organized "Show key bindings" page

TODO: act next on step 4 of "Implementation order" (text-object renderer and
`<char>`/`<num>` templates). Steps 1-3 are done (see DONE at the end).

## Context

Help ▸ Show key bindings (`show_key_bindings`, `lib/vimamsa/key_bindings_report.rb:18`)
dumps lines like

    [C] d i <char> : buf.text_object_op(:delete, <char>, :i)

into the catch-all **Others** section. The page should be organized by what the user
wants to do, with readable descriptions, and work the same way for every keybinding
scheme.

## Why it's disorganized now (verified 2026-11-19)

1. **Sections are hardcoded to the vimlike keywords.** The report asks
   `get_by_keywords` for `intro`, `hyperplaintext`, `core` and `experimental`, and
   everything else goes to Others. The `vim` scheme tags its bindings `vim motion`,
   `vim edit`, `vim visual`, `vim insert`, `vim replace` and `vim misc`, and notepad
   tags them `notepad`. With those schemes, **almost every binding ends up in Others.**
2. **`core` is one bucket for about 205 bindings** (`key_bindings_vimlike.rb:114-390`):
   motions, file and buffer handling, deleting, marks, macros, mode switches. The
   file already has comment headers for these groups (`# MOVING`, `#### Deleting`,
   `# Marks`, `# Macros`, `# Buffer handling`, …), but the keyword ignores them.
3. **Bindings registered outside the scheme files have ad-hoc or no keywords, so they
   land in Others.** These are text objects (`text_objects.rb:351`, keyword
   `vim text objects`), the file manager (13 `bindkey`s), grep, bookmarks, the buffer
   manager, diff view, the minor modes (`audio`, `macro`, `bmgr`, `bmark`, `grep`,
   `diffview`, `fexp`) and modules (`ollama`, `tts`, `dictation`, `color_highlight`).
4. **Template families show up as cryptic raw lines.** For example, text objects are
   `ops × {i,a} × <char>`: 13 lines that all look the same and don't show which
   objects exist (`iw`, `i(`, `it`, …).
5. **Raw Ruby instead of descriptions.** This is a separate TODO item ("Descriptive
   names for key bindings"), and this plan depends on it.
6. **Raw conditions such as `I tab(vma.buf.view.autocp_active)`** are shown as Ruby
   code.
7. **Lines are sorted alphabetically by the whole `[Mode] keys` string**, so related
   bindings are scattered, and the mode letter is the main sort key. Deduplication is
   done by string-matching rendered lines (`done.concat(x.lines)`).

## Design

### 1. Structured binding list from the tree

Add `KeyBindingTree#bindings` → array of records
`{ mode:, keys:, action:, keywords:, eval_rule:, desc: }`, using the same traversal as
`get_by_keywords` (`key_binding_tree.rb:374`). Fill in `desc` through the
`action_description` helper from the descriptions TODO item. The report, the
free-bindings report and the vim-conflicts report are built from this data instead of
from parsed strings. `get_by_keywords` stays as a thin wrapper for existing callers and
tests.

### 2. A fixed category list, tagged with `cat:<id>` keywords

One ordered list in `key_bindings_report.rb` (or a small `key_categories.rb`):

| id | Heading |
|---|---|
| `basic` | Basics (quick start) |
| `motion` | Moving the cursor |
| `search` | Searching and jumping (`/`, `n`, `*`, `f`/`t`, easy-jump, `gf`) |
| `insert` | Entering insert mode and typing |
| `edit` | Delete, change, copy, paste (operators and their motions) |
| `textobj` | Text objects |
| `case` | Case and text transforms |
| `visual` | Visual mode |
| `undo` | Undo, redo, repeat |
| `marks` | Marks and bookmarks |
| `macro` | Macros |
| `file` | Files (open, save, finder, history, file manager) |
| `buffer` | Buffers and windows (switch, close, two-column) |
| `view` | Panels and view (file/func/keylog panels, folding, font) |
| `grep` | Search across files (grep lines, ack) |
| `code` | Code (LSP, auto-format, comment, run line) |
| `hpt` | Hyper plaintext |
| `module:<name>` | Modules ▸ <name from `_info`> |
| `mode:<id>` | Minor modes (audio, macro, bmgr, bmark, grep, diffview, fexp) |
| `debug` | Debug / experimental |

- **Tagging.** `add_keys` keywords get a `cat:<id>` word, e.g. `add_keys "core cat:motion", {...}`.
  The existing keywords stay, so nothing that queries them breaks.
- **Split vimlike's big `core` block** into several `add_keys` calls at its existing
  comment headers. Do the same for the vim scheme's six sections and for notepad.
- **Automatic categories, so most code doesn't need manual tags:**
  - a binding in a minor mode (first key is a minor-mode id) → `mode:<id>`
  - a binding added from inside a module's `<name>_init` → `module:<name>`. Set a
    "current module" context in `module_set_enabled` / the startup loop, and have
    `bindkey` add the keyword.
  - legacy keyword map: `vim motion` → `motion`, `vim text objects` → `textobj`,
    `hyperplaintext` → `hpt`, `experimental` → `debug`, etc.
- **Basics stays independent of the scheme.** Instead of the vimlike-only `intro`
  keyword, define `BASIC_ACTIONS` (save, quit, undo/redo, insert, esc, search, open
  file, switch buffer, show key bindings, …) and show whatever keys the active scheme
  binds them to. Those bindings still also appear in their own category.

### 3. Page layout

```
❙Key bindings — scheme: vimlike❙
[C]=Command [I]=Insert [V]=Visual …   <key>! = press and release alone

◼ Moving the cursor
  Command / Visual
    h j k l          Move left / down / up / right
    w  b  e          Next word start / previous word start / word end
    <count> G        Go to line <count>
  Insert
    ctrl-a           Start of line
…
◼ Text objects
  Operators: d (delete)  c (change)  y (copy)  gU gu g~ (case)  v (select, Visual)
  Objects:   iw aw  iW aW  is as  ip ap  i" a"  i' a'  i` a`  i( a( (ib ab)  i[ a[
             i{ a{ (iB aB)  i< a<  it at
  Examples:  d i w  delete word · c i "  change inside quotes · y a p  copy paragraph
```

- Within a category, bindings are grouped by **mode** as a subheading, not used as a
  sort key. Inside a group they're kept in **definition order** (the order in the
  scheme file, which is logical: hjkl together), not alphabetical.
- Keys that share one description are merged on one line (`"VCX up" / "VC k"` →
  `k  up`).
- Columns are aligned: keys | description. The raw action is dimmed after the
  description only when it adds something (see the descriptions TODO), or always for
  Ruby-string actions as `⟨code⟩`.
- **Template families get a custom renderer.** A category can provide a block that
  draws its section. `textobj` draws the operator × object table above from the
  text-object definitions in `text_objects.rb`, so it can't go out of date. `<char>`
  / `<num>` bindings show as `d f <char>`, `d <count> e` with a description that
  names the placeholder.
- **Conditions** (`eval_rule`) are shown as readable text through a small table
  (`"vma.buf.view.autocp_active"` → "when the completion popup is open",
  `"vma.kbd.next_command_count!=nil"` → "with a count"). Unknown rules are shown dimmed
  as they are.
- Categories with no bindings in the active scheme are left out. The header says
  which scheme is shown.

### 4. Keep it organized: a test instead of Others

- For each scheme (via `load_scheme_kbd`, `key_bindings_report.rb`), every binding
  resolves to exactly one known category. Any that don't are printed, so a new
  binding without a category fails the suite. Others stays only as a runtime
  fallback, for bindings users add in `custom.rb`, under the heading "Your bindings
  (custom.rb)" if `bindkey` was called during custom.rb loading. Otherwise it's
  "Uncategorized".
- Snapshot-ish test: the rendered page for vimlike contains the headings in order and
  the text-object table, and contains no `buf.text_object_op(` line.

### 5. Optional follow-ups

- Hyperplaintext folding per `◼` section, so long categories can be collapsed.
- `show_key_bindings` takes an optional filter (category or search string). Add menu
  entries "Key bindings: Editing", …, or reuse Search for Actions for that.
- Show the category in Search for Actions results.

## Implementation order

1. `KeyBindingTree#bindings` (structured records) + tests. Port `show_key_bindings`
   to it with the current sections. Output stays the same.
2. Category list, `cat:` tagging, auto-categories (minor mode, module, legacy map).
   Split the big vimlike `core` block and tag the vim/notepad sections. Add the
   "no uncategorized bindings" test.
3. New layout: grouping by mode, definition order, merged keys, aligned columns,
   condition text, scheme in the header, Basics from `BASIC_ACTIONS`.
4. Text-object renderer and `<char>`/`<num>` template rendering.
5. Descriptions (the separate TODO item) fill in the description column. This can run
   in parallel; until then the column shows the raw action.

Run the full suite in the VM after each step.

## DONE

- **Steps 1-2: binding records and categories** (2026-11-21, commit "feat: key
  bindings page grouped by category"). `KeyBindingTree#bindings` returns
  `{ mode:, keys:, action:, keywords:, desc: }` records in definition order,
  including actions on nodes that also have longer bindings; `get_by_keywords`
  is built on it. `desc` now also covers dotted action ids (since the renames
  the page showed raw ids) and shows procs as `proc (file.rb:line)`.
  Categories (`KEY_CATEGORIES` in `key_bindings_report.rb`, the table above
  plus `app`, `help`, `custom` and `internal`): `key_binding_category` takes a
  minor mode, then the namespace of a named action
  (`doc/action_names_plan.md`), then a `cat:<id>` keyword, the
  `module:<name>` / `custom` context, the major mode (`B`, `X`, `R`), and the
  older section words (`vim motion`, `experimental`, ...). The context comes
  from `KeyBindingTree#with_keywords`, wrapped around module inits (startup
  and Settings) and the three places `custom.rb` runs. vimlike's `intro` and
  `core` blocks are split into `cat:` groups (same bindings, same order within
  each group, checked by script); the vim table gets `vim marks` and an
  insert section. The page lists Basics (`intro`, as before), then the
  categories in order; "Others" is gone. `tests/test_key_categories.rb`: every
  binding of vimlike, vim and notepad has a category.
  Left for later: Basics still uses the `intro` keyword (`BASIC_ACTIONS` is
  step 3); the conflict report still uses its own traversal
  (`kbd_leaf_bindings`).
- **Step 3: page layout** (2026-11-21). `key_bindings_page` builds the text,
  `key_bindings_section` one section: rows in definition order
  (`State#seq`, set by `bindkey`; `KeyBindingTree#bindings` is sorted by it),
  the same keys and description in several modes merged into one row,
  rows grouped by modes under `◼◼ Command, Visual` subheadings (ordered by
  their first mode, then by which was defined first; none in minor-mode
  sections), keys of a group with the same description merged (`y y / Y`),
  keys and descriptions in aligned columns. Conditions are shown as text
  through `KEY_CONDITIONS` (`(with a count)`), others as `(if <rule>)`. The
  header names the scheme. Basics lists `BASIC_ACTIONS` with the keys the
  active keymap binds them to in Command, Visual and Insert mode. Tests in
  `tests/test_key_categories.rb` (`test_section_layout`, `test_page_layout`).
  Not done: dimming the raw action after a description (hyperplaintext has
  no dim style).
- **Step 5: descriptions** (2026-11-21): done through step 6 of
  `doc/action_names_plan.md`, which made every Ruby-string binding a named
  action with a description.
