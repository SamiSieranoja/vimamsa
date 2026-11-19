# Unused-code removal plan: further source size reduction

## Context

Follow-up to refactor_dedup_plan.md (tiers 1–4 done, tier 5 skipped). Fresh scan
(July 2026) for methods whose names appear nowhere outside their own definition —
searched across lib/, exe/, tests/, modules/, custom_example.rb, and a real-world
user config (custom.rb + settings.rb), counting references in eval'd key-binding
strings and symbols but ignoring comment-only lines. Older local scan
reports (not in the repo) are stale — everything in
them was either already deleted or is now used; this file supersedes them.

Caveat that applies to everything below: any function is technically reachable
from the `:` command line (it evals Ruby) and from ~/.vimamsa/custom.rb on other
machines. "Unused" here means: no reference anywhere in the shipped code or this
machine's user config.

Realistic total: **~530 lines** (tiers A–C), plus an optional ~390-line
commented-out-code sweep (tier D). Verify each tier with
`ruby exe/run_tests.rb --headless`.

## Tier A — dead methods, pure deletion (~350 lines)

Verified individually; body sizes in parens. Delete, including any
now-orphaned ivars/config noted inline.

**buffer.rb** (~87): `get_short_path` (7), `recalc_line_ends` (13),
`sanity_check_line_ends` (12) — near-duplicates of each other, both dead;
`context_menu_items` (34); `need_redraw!`/`need_redraw?`/`set_redrawed` (9) —
also remove the now-write-only `@need_redraw` assignment at buffer.rb:458;
`delete_active_selection` (7, marked "TODO: remove this function");
`save_as_check_callback` (5, references a commented-out `@unconfirmed_path`
mechanism; `save_as_callback` itself stays — it's live via editor.rb:474).

**buffer_changetext.rb** (~10): `paste_start_xclip` (10) — superseded GTK-clipboard
fallback; its only call site is already commented out (line ~115). Remove that
comment too and the `xclip` mention.

**debug.rb** (~48): `run_test` (16), `run_random_jump_test__tmpl` (32) — legacy
test infra referencing tests/test_<id>_output.txt files that no longer exist.
(`gui_sleep` stays — used elsewhere.)

**editor.rb** (~25): `paste_register` (4), `plug` (3),
`can_open_extension?` (7) — also delete the orphaned
`cnf.extensions_to_open = [...]` default in conf.rb:129; `filter_buffer` (11).

**file_finder.rb**: `updating?` (3).

**gui.rb** (~49): `start_profiler` (4) + `end_profiler` (5) — dev tools, keep if
used interactively; `gui_set_cursor_pos` (3), `handle_image_resize` (15,
"TODO:gtk4", connects a GTK3-only signal), `editor_area` (3),
`remove_extra_controllers` (15), `is_buffer_open` (4).

**gui_sourceview.rb** (~24): `show_controllers` (7), `cur_pos_xy` (3),
`sanity_check` (14).

**hyper_plain_text.rb**: `hpt_scan_audio` (26).

**key_binding_tree.rb**: `clear_modifiers` (3, body already commented out),
`cur_mode_str` (3).

**langservp.rb** (~15): `add_workspaces` (11, TODO stub),
`handle_responses` (4, empty TODO stub).

**macro.rb**: `dump_last_macro` (5).

**tests.rb**: `run_tests_0` (15) — broken (evals `test_write_0`, which doesn't
exist) and unused. Subsumed by Tier B if that is taken.

**util.rb** (~34): `running_wayland?` (11), `pipe_to_external` (17),
`expand_if_existing` (6).

## Tier B — delete legacy tests.rb entirely (~190 further lines)

`lib/vimamsa/tests.rb` (201 lines) predates the tests/ + test_framework.rb
suite: `run_tests`/`run_edit_tests`/`EditorTests`, two hash-oracle macro tests
(`test_paste_0` is a hard `return` stub), and the LOREM_IPSUM/JABBERWOCKY
constants (referenced nowhere else). Only entry point is the `:run_tests`
action (key_actions.rb:259) bound to `C , t r` (key_bindings_vimlike.rb:376).
Delete the file, the require in rbvma.rb:73, the action entry, and the binding.
If an in-editor test runner is still wanted on that key, repoint it at the
modern suite instead.

## Tier C — unbound actions (~40–70 lines, feature decision)

12 registered actions are never bound to a key, never called from code, and not
referenced in the default custom.rb. They remain reachable through the
action-search palette (`, , s`), so deleting them removes (obscure) features,
not just dead code — prune to taste:

`fhist_remove_nonexisting` (file_history.rb); from key_actions.rb: `eval_buf`,
`refresh_colors`, `gui_ensure_cursor_visible`, `close_all_buffers` (refs=0 —
its proc body references a method that doesn't exist), `refresh_func_panel`,
`V_to_latex_itemize`, `invoke_grep_search` (registered twice),
`execute_current_line_in_terminal_autoclose`, `delete_current_file`,
`buf_backup`, `debug_buf_hex`.

Check each proc body for helper functions that become orphaned once the action
is gone (then re-run the tier-A style scan).

## Tier D — commented-out code sweep (optional, ~390 lines)

Heuristic count of comment lines that look like code (assignments, method
calls, `signal_connect`, old `require`s): ~391 across lib/, concentrated in
buffer.rb (52), key_binding_tree.rb (48), key_bindings_vimlike.rb (42),
gui_sourceview.rb (38), gui.rb (27). Much of it is pre-GTK4 leftovers
(`#TODO:gtk4`) and abandoned experiments. This contradicts the repo's
"match the surrounding style" convention, so do it only as a deliberate,
per-file pass — keep comments that document intent (e.g. the guarded-binding
ordering notes), delete only mechanical dead code. Git history preserves
everything.

## Verification

- After each tier: `ruby exe/run_tests.rb --headless` (full suite).
- Tier B: verify `C , t r` is unbound (or repointed) and startup is clean with
  scheme "vim" and "notepad" too (`cnf.keybindings.scheme`).
- Tier A langservp/editor items: open a Ruby file with LSP enabled once.
- Final: `wc -l lib/vimamsa/*.rb` before/after; one commit per tier.
- Also delete the superseded local scan reports (not in the repo).
