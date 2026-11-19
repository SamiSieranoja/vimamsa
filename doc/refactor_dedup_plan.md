# Deduplication refactor: reduce source size by removing repeated code

## Context

Goal: find repeated source code that can be refactored to shrink the codebase.
Findings come from a mechanical duplicate-block scan plus a file-by-file sweep of the
GUI and core layers; every item below was verified by reading both copies. Total
realistic reduction: **~250–300 lines** (of ~15k in lib/). Ordered in tiers from
zero-risk deletions to the larger structural extraction, so it can be cut short at any
tier boundary. Each tier is committed separately and verified with the test suite
(`ruby exe/run_tests.rb --headless`), plus the binding-scheme tests for Tier 5.

## Tier 1 — dead / duplicate code, pure deletion (~80 lines)

1. **Duplicate `Clipboard` class** — `editor.rb:483-505` re-defines `Clipboard#set/#get`
   identically to `clipboard.rb` (the live, fuller copy with `[]`/`<<`, required at
   rbvma.rb:37). Delete the editor.rb copy.
2. **Dead body of `KeyBindingTree#to_s`** — `key_binding_tree.rb:416-458`: line 417 is
   `return self.class.to_s`, making the remaining ~40 lines unreachable — and they are
   a verbatim copy of the traversal in the method above (`394-413`). Delete the dead
   body, keep the one-line return.
3. **Unreachable fuzzy-filter tail** — `file_finder.rb:167-179`: verbatim copy of
   `FileHistory.fuzzy_filter` (`file_history.rb:63-77`) sitting after an unconditional
   `return` inside `filter_files`. Delete.
4. **Dead wrapper `open_existing_file`** — `editor.rb:677-679` is a pass-through to
   `open_new_file`. Delete and update callers (`grep -rn open_existing_file lib tests`;
   includes `gui_command_line.rb`).

## Tier 2 — route through helpers that already exist (~15 lines)

5. **`get_repeat_num` not reused** — `buffer_changetext.rb:343-348` (`delete_line`) and
   `buffer.rb:1473-1478` (`copy_line`) inline the exact body of the existing
   `get_repeat_num` (`buffer.rb:757`). Replace both blocks with the call.
6. **Margins set line-by-line** — `gui_form_generator.rb:34-37, 45-48` expand 4-line
   margin blocks although `Gtk::Box#margin=` / `Gtk::Frame#margin=` monkeypatches exist
   (`gui_dialog.rb:14-32`). Replace with `frame.margin = 8` etc.

## Tier 3 — small single-file helper extractions (~50 lines)

7. **Visual-selection transform envelope** — `buffer.rb`: `transform_selection` (1403),
   `convert_selected_text` (1428), `style_transform` (1439), `set_line_style` (1453)
   all repeat `return if !@visual_mode; r = get_visual_mode_range; txt = self[r]; …;
   replace_range(r, txt); end_visual_mode`. Extract
   `transform_visual_selection { |txt| ... }`; also share the style-marker wrapping
   (`⦁`/`❙`/clear-gsub) used by the last two.
8. **Indent/unindent shared range math** — `buffer.rb:330-362`: both methods repeat the
   6-line visual-line-range setup + `replace_range` + selection restore. Extract
   `transform_selected_lines { |line| ... }`; each method becomes ~3 lines.
9. **LSP documentSymbol request scaffolding** — `langservp.rb`: `document_functions`
   (336) and `document_functions_grouped` (360) share ~12 lines of
   ensure_open/params/write/wait/validate. Extract private
   `request_document_symbols(fpath)` returning the symbols array or nil.
10. **Git-root lookup** — `diff_buffer.rb:153` and `:182` duplicate the
    `dir = …; git_root = \`git -C … rev-parse --show-toplevel\`` block. Extract
    `buffer_git_root` helper.

## Tier 4 — GUI cross-file widget helpers (~90 lines)

Helpers live next to the existing ones in `gui_dialog.rb` (`set_margin_all`,
margin monkeypatches) as module-level Vimamsa functions.

11. **TreeView + ScrolledWindow scaffolding** — `gui_file_panel.rb:8-48`,
    `gui_func_panel.rb:12-40`, `gui_settings.rb:194-210` build the same
    TreeStore/TreeView (headers off, single-click, one ellipsized expanding text
    column) inside a `ScrolledWindow(:never,:automatic)`, plus structurally identical
    `row-activated` handlers. Extract e.g.
    `build_list_tree(store, ellipsize:, text_col:) { |iter| … }` returning
    `[tree, scrolled_window]`. (~30–40 lines)
12. **Modal popup boilerplate** — `gui_dialog.rb:43-48`, `gui_form_generator.rb:17-31`,
    `gui_settings.rb:90-93`, `gui_select_window.rb:46-52` all do
    `Gtk::Window.new; set_transient_for($vmag.window); modal = true; title = …`, and
    three have identical `run` (show-or-destroy). Extract `make_modal_window(title)`
    factory + share `run`. (~20–25 lines)
13. **Return/Escape CAPTURE key controller** — `gui_dialog.rb:90-108`,
    `gui_form_generator.rb:84-97`, `gui_settings.rb:151-161`,
    `gui_select_window.rb:104-148` wire the same EventControllerKey with
    Return→submit / Escape→destroy. Extract
    `on_submit_escape(widget, submit:, escape:) { |keyval| … }` with an optional block
    for extra keys (select_window's Up/Down/Delete). (~20 lines)
14. **Panel show/hide/toggle in gui.rb** — `gui.rb:1148-1245`: file/func panel pairs
    build the same Paned wrapper and near-identical hide logic; toggle/refresh/init
    trios differ only in the ivar. Extract `make_side_pane(widget, pos)` and collapse
    the trios data-driven. (~15–20 lines)

## Tier 5 — shared key-binding definitions (~80–110 lines, most careful)

15. **`key_bindings_vim.rb` ⇄ `key_bindings_vimlike.rb`** share byte-identical blocks:
    mode/minor-mode setup + cursor colors (vimlike:3-24 / vim:17-35), the
    `_insert_move`/`insert_select_move`/`insert_move` helper methods (19 lines each),
    insert-mode arrow/selection bindings, `f`/`F` char-find + count + BOL/EOL entries,
    marks, READCHAR + macro-record entries, the entire Browse-mode block
    (vimlike:310-324 / vim:323-337), and the audio minor-mode bindkeys.
    Extract into a new `lib/vimamsa/key_bindings_common.rb` (add to rbvma.rb per
    convention — or `require`d by both scheme files directly, like
    key_bindings_notepad.rb already requires vimlike). Both scheme files keep only
    scheme-specific content. Binding semantics must stay identical: later
    `bindkey`/`add_keys` override earlier ones, so common content loads first in each
    scheme file.

## Verification

- After each tier: `ruby exe/run_tests.rb --headless` (full suite, ~150 tests).
- Tier 1 item 4: re-run `test_command_line` + `test_jump_to_file`.
- Tier 4: `test_func_panel`, `test_keylog_panel`, `test_file_manager`, plus a manual
  smoke test of one dialog (search) and the select window (file finder) in a real run.
- Tier 5: additionally `ruby exe/run_tests.rb tests/test_vim_bindings.rb` and
  `tests/test_notepad_bindings.rb` (excluded from the default suite; the vim one
  replays sequences against a real-vim oracle) and `tests/test_key_bindings.rb`.
- Final: line-count before/after (`wc -l lib/vimamsa/*.rb`), E2E cmdline test focused,
  one commit per tier.

## Explicitly not doing (checked, already fine or not worth it)

- Marshal save/load, file-read/run-cmd error handling, forward/backward cursor
  methods: already centralized (`editor.rb:320`, `util.rb:283/108`, direction params).
- CSS-provider one-liners and `GLib::Idle.add { message(…) }` wrappers: savings too
  small relative to churn.
