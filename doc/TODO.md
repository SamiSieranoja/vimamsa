# TODO

Generic list of future actions. Larger efforts get their own plan in `doc/*_plan.md`
and are linked from here.

When an item is finished, move it to **DONE**. Add a short summary of what was done and
the git ref(s), as a short commit hash or a range.

## Open

### Stop writing to `~/.vimamsa`; use XDG dirs (`~/.config` / `~/.local/share`)

Nothing should be written to `~/.vimamsa` or other ad-hoc dot dirs. User-edited
configuration goes in `~/.config/vimamsa` (`$XDG_CONFIG_HOME`). Files the program
generates (history, session, backups, caches, downloaded models/venvs) go in
`~/.local/share/vimamsa` (`$XDG_DATA_HOME`).

Hardcoded paths found (2026-11-18). They also bypass `vma_user_dir` / `--user-dir`, so
the test suite (`~/.config/vimamsa-test`) can still touch the real user's files:
- `lib/vimamsa/gui_command_line.rb:20`: `HISTORY_FILE = "~/.vimamsa/cmd_history.txt"`.
  Change to data dir.
- `lib/vimamsa/buffer.rb:2221`: backups in `~/.vimamsa/backup`. Change to data dir.
  `editor.rb:189` already creates `get_dot_path("backup")`, which is a different
  directory from the one backups are written to.
- `lib/vimamsa/macro.rb:219`: `save_macro` writes to `~/.config/.vimamsa`, a stray
  third directory. Unify it with `NAMED_MACROS_FILE` (`macro.rb:46`). Saved macros are
  user content, so they go in the config dir.

Currently everything else goes through `get_dot_path` → `~/.config/vimamsa`, including
generated state. It should be split as follows:
- Stays in config: `custom.rb`, `settings.rb`, `styles/`, bookmarks, named macros.
- Moves to data: `session.txt`, `buffers.txt` (`buffer_list.rb:5,14`), `backup/`,
  `crash/`, `cmd_history.txt`, `dictation_prompts.json`. Also the `listen/` dir and
  `ripl_ctrl` (`gui.rb:535`). Those two are runtime files, so `$XDG_RUNTIME_DIR` could
  be an option, but `~/.local/share` is fine for now. `exe/vimamsa` uses `listen/`
  too, and it must agree with the editor.

Plan sketch:
1. Add `vma_data_dir` / `get_data_path(sfx)` beside `vma_user_dir` / `get_dot_path`
   (`editor.rb:742-755`). They honor `$XDG_DATA_HOME`, and `--user-dir` overrides both
   dirs, so tests stay isolated. Also honor `$XDG_CONFIG_HOME` in `vma_user_dir`.
2. Route the three hardcoded paths and the data files above through these helpers.
3. One-time migration at startup: if the old file exists and the new one doesn't, move
   it (`~/.vimamsa/{cmd_history.txt,backup/}`, `~/.config/.vimamsa/macro_*`, and data
   files from `~/.config/vimamsa`). Log what was moved.
4. Fix docs that say `~/.vimamsa/...`:
   - `README.md:62,158` (custom.rb is actually in `~/.config/vimamsa`)
   - `modules/tts/tts.rb:14` and `modules/dictation/dictation.rb:24` ("settings.rb")
   - `custom_example.rb`, if it applies
5. Tests: with `$vma_user_dir` set, no file outside the test dirs is created. Run a test
   that exercises history, backup and macro save, and check that `~/.vimamsa` is not
   created.
6. `doc/modules_settings_plan.md` already uses `~/.local/share/vimamsa/venv` for its
   shared Python venv. Build it on `get_data_path("venv")`.

### Descriptive names for key bindings that lack one

Many bindings show raw Ruby code instead of a description in Help ▸ Show key bindings
(`show_key_bindings`, `key_bindings_report.rb`) and in other places that show action
names. Example:

    [C] d F space : buf.delete2(:to_char_backward,' ')

It should say something like `Delete backward to previous space`.

Cause: `KeyBindingTree#get_by_keywords` (`key_binding_tree.rb:404-417`) only looks up a
description when the action is a registered **Symbol** (`@actions[sym].method_name`).
Bindings whose action is an eval'd **String** are printed as they are. Counts
(2026-11-19), as `"keys" => "ruby string"` entries:

| Scheme | String bindings | Symbol bindings |
|---|---|---|
| `key_bindings_vimlike.rb` | 97 | 145 |
| `key_bindings_vim.rb` | 78 | 79 |
| `key_bindings_notepad.rb` | 4 | 9 |

Some registered symbols also have an empty description, e.g. `:jump_to_random`
(`key_actions.rb:67`) and `:ack_search` (`key_actions.rb:124`, a duplicate of line 151,
which does have one). These print as the bare symbol.

Other places that show the raw action and would benefit from the same lookup:
- the previous-action label in the toolbar (`gui.rb:829`)
- the key log panel (`gui_keylog_panel.rb:109`)

Plan sketch:
1. **One description table keyed by the action string**, shared by all schemes. Many
   strings are identical in vim and vimlike, e.g. `buf.delete2(:to_char_backward,' ')`
   is in both, so each one is described once. For example, a new
   `lib/vimamsa/key_action_descs.rb` (required in `rbvma.rb`):
   ```ruby
   KEY_ACTION_DESCS = {
     "buf.move(FORWARD_CHAR)"                  => "Move forward one character",
     "buf.delete2(:to_char_backward,' ')"      => "Delete backward to previous space",
     "buf.delete2(:to_char_backward,<char>)"   => "Delete backward to previous <char>",
     "bufs.close_current_buffer"               => "Close current buffer",
     ...
   }
   ```
   Templates with `<char>` keep the placeholder in the description.
   - Alternative: convert each string action to a `reg_act` symbol with a description.
     That's cleaner in the long run (they also become searchable in Search for
     Actions), but it touches every binding line in three scheme files, plus user
     `custom.rb` files that rebind the same strings. Proposed: the table first.
     Convert to symbols opportunistically, and especially convert actions that are
     worth finding through Search for Actions.
2. A helper `action_description(action)`: Symbol → `method_name` (if non-empty);
   String → `KEY_ACTION_DESCS[action]`; otherwise the action itself. Use it in
   `get_by_keywords`, `gui.rb:829` and the key log panel.
3. Report format: show the description, with the raw code dimmed after it so power
   users still see what runs. For example:
   `[C] d F space : Delete backward to previous space  ⟨buf.delete2(:to_char_backward,' ')⟩`.
   Or show the code only for entries without a description.
4. Fill in descriptions for all ~180 string bindings and the symbols with empty
   descriptions. Remove the duplicate `:ack_search` registration.
5. Test (`tests/test_key_bindings.rb` or a new one): for each scheme (load it with
   `load_scheme_kbd`), every binding resolves to a non-empty description that isn't
   the raw action. Print the missing ones, so new bindings without a description fail
   the suite.

### More Vim bindings: counts after operators, missing operator + motion combinations

The full design is step 1 of `doc/vim_compatibility_plan.md` (a generic operator +
motion layer). The gap list is in `doc/missing_vim_bindings.md`. This item tracks the
concrete bindings, ordered by usefulness and cost.

State (2026-11-19):
- A count *before* the command (`3dw`) works, because the key tree repeats the action
  (`key_binding_tree.rb:888`).
- A count *after* the operator works only where a `<num>` binding was written out.
  The only one is `"C d <num> e"` (`key_bindings_vimlike.rb:229`, handled by
  `KeyBindingTree#match_num_key`).

1. **Counts after the operator for bindings that already exist** (quick win, can come
   before the operator layer):
   - `d <num> w`, `d <num> d` (= `3dd`), `d <num> f x`, `d <num> F x`
   - `y <num> w`, `y <num> e`, `y <num> y`
   - `g U <num> w`, `g u <num> w`, `g ~ <num> w`
   - vim scheme: `c <num> w`, `c <num> e`, `c <num> c`
   - text objects: `d 2 i (` (today only `2 d i (` works)

   Rather than writing every `<num>` binding by hand, let `match_num_key` accept digits
   after any registered operator prefix (`C d`, `C y`, `C c`, `C g U`, `C g u`,
   `C g ~`), so current and future operator bindings all get counts. Caveat: `c …`
   must not just repeat its action (three insert-mode entries), so the change bindings
   need actions that apply the count themselves (`method_handles_repeat`). Check
   `delete_line` / `copy_cur_line` the same way.
2. **Missing operator + motion combinations** (both schemes unless noted):
   - `d b`, `c b`, `y b`
   - `d t x`, `c t x`, `d T x`, `y t x`
   - `d j`, `d k`: missing in both; in vimlike they're commented-out TODOs at
     `key_bindings_vimlike.rb:222-223`
   - `d G`, `d g g`; `d }`, `d {`, `y }`; `d %`; `d ^`, `y ^`
   - vimlike has no change operator at all (`c`, `C`, `s`, `S` are bound to other
     things), so it needs a key decision first. See `doc/vimlike_vim_conflicts.md`.
3. **Missing motions** (they then also work after operators):
   - `W` / `E` / `ge` (`B` is commented out in vimlike)
   - `T x`, and `,` (`;` exists)
   - `%`, `{` / `}`, `(` / `)`
   - `H` / `L` (`M` is taken in vimlike), `#`
4. **Doubled operators / other count commands**:
   - `>>` / `<<` with counts, and Visual `>` / `<` in vimlike
   - `ctrl-a` / `ctrl-x` (neither is in vimlike)
   - check that `3 r x`, `3 p` and `J` / `gJ` with counts apply the count correctly
5. **Larger, already planned**: line-wise `V`, block `ctrl-v`, `o` / `gv` in Visual
   mode, named registers (`"a`). See plan steps 4–5.

Groups 2–3 should be done through the operator layer (plan step 1), not as about 100
hand-written bindings. Where there's a choice, new vimlike bindings avoid alt-/ctrl-
chords. Each group needs tests (`keys("d 3 w")` + `assert_buf`), and the real-Vim differential
check where available.

### Organize the "Show key bindings" page

Bindings like `[C] d i <char> : buf.text_object_op(:delete, <char>, :i)` land in
**Others**. With the vim or notepad scheme almost everything does, because the report's
sections are hardcoded to vimlike keywords. Plan: `doc/key_bindings_report_plan.md`.
It covers:
- structured binding records
- a fixed category list via `cat:` keywords, plus automatic categories for minor
  modes and modules
- splitting vimlike's 205-binding `core` block
- grouping by mode in definition order
- a text-object table
- readable conditions
- a test that fails on uncategorized bindings

Depends on the "Descriptive names for key bindings" item above for the description
column.

### Function panel shows nothing on the key bindings help page

The key bindings page (`show_key_bindings`) is a hyperplaintext buffer with `❙…❙` /
`◼ …` headings, which the function panel can outline (`FuncPanel#hyperplaintext_outline_entries`).
On this page it shows "(no file)" instead. Three causes (found 2026-11-19):

1. **The `fname` guard runs first.** `FuncPanel#refresh` (`gui_func_panel.rb:50-53`)
   returns "(no file)" for any buffer without a file name before it checks for
   hyperplaintext. Generated buffers (`create_new_buffer`) have `fname = nil`.
2. **The language is only set on the GTK side.** The report calls
   `gui_set_file_lang(b.id, "hyperplaintext")` (`key_bindings_report.rb:15,70`), which
   sets the GtkSource buffer's language but not `Buffer#lang`. So
   `hyperplaintext_buffer?` (`buf.lang == "hyperplaintext" || fname.end_with?(".txt")`)
   is false even without the guard. `Buffer#set_language` (`buffer.rb:195`) sets both.
3. **Refresh runs too early.** `create_new_buffer` (`editor.rb:622-629`) makes the
   buffer current, which triggers `func_panel_refresh` from `buffer_list.rb:133`,
   *before* `set_content` and before the caller sets the language. Nothing refreshes
   the panel afterwards (the only other triggers are a buffer switch and the manual
   `:refresh_func_panel`).

The same problem affects the other generated buffers that use `gui_set_file_lang`:
- the free-bindings report (`key_bindings_report.rb:15`)
- the vim-conflicts report (markdown, `:259`)
- diff buffers (`diff_buffer.rb:110,184,210`)

Fix:
1. In `refresh`, check for hyperplaintext before the `fname` guard (it only needs the
   text), and keep "(no file)" just for the LSP path.
2. Make the report and other generated-buffer callers use `buf.set_language(...)`
   instead of `gui_set_file_lang`. Or make `gui_set_file_lang` also update
   `Buffer#lang`, which fixes every caller at once.
3. Refresh the panel when a buffer's language changes (in `set_language`), and after
   `create_new_buffer` has set the content. A debounced refresh on text change
   (like `file_panel_marks_changed`) would also keep the outline current while editing
   `.txt` files.
4. Optional: outline markdown (`#` headings) the same way, so the vim-conflicts
   report, README.md and the `doc/*.md` files get an outline without LSP. This fits
   with the markdown highlighting item.
5. Test (`tests/test_func_panel.rb`): with the panel shown, run `:show_key_bindings`
   and assert that the panel's store has a row for the "Key bindings" title and the
   `◼` sections, and does not show "(no file)".

### Single downloadable app (AppImage, later Flatpak)

Plan: `doc/bundling_plan.md`. AppImage is recommended: one file, and no sandbox, so
external tools keep working. It has to bundle relocatable Ruby, the gems, the GI
typelibs and the GTK/GStreamer/VTE libs, built on Ubuntu 24.04 (to match the tested GTK 4.14; see "GTK version differences"). Code fixes needed
first:
- `exe/vimamsa` puts CWD-relative `lib`/`ext` on the load path
- the dead `ext/stridx` path
- `Exec=` in `desktop_install.rb` has to point at `$APPIMAGE`
- `ruby-lsp` stays bundled for now; AppRun exposes a `ruby-lsp` binstub on `PATH`
Before the AppImage helps non-Ubuntu users (see "Running on non-Ubuntu distros" in the plan):
- a `cnf.terminal.command` setting with auto-detection, to replace the hardcoded `gnome-terminal`
- modules page install commands per distro (read from `/etc/os-release`)

### Resettable test VM: occasional fresh-install runs

The test VM (`$VM_NAME`) isn't blank any more. It was provisioned once and has collected state from
every run since, so a fresh install is never tested. Plan:
`doc/vm_snapshots_plan.md`.
- two VirtualBox snapshots: `clean` (fresh 24.04 + Guest Additions) and
  `provisioned`
- `run_tests_vm.sh` restores `provisioned` before every run
- it automatically does a fresh run from `clean` when install inputs change or
  weekly, and then retakes `provisioned`

The `clean` baseline needs a newly installed VM (one-time, manual).

### Start in insert mode (command stays the base), new buffers inherit the mode, esc toggle

Goal: easier for new users without giving up modal editing. Command mode stays the
**base** of the mode stack, so `to_previous_mode` (`key_binding_tree.rb:156`) and
Visual → command keep working. Only the mode a buffer *starts* in changes.

**Rule for a new buffer's start mode** (decided 2026-11-19):
- A new buffer starts in **the most recent of command/insert in the previous buffer**,
  i.e. the buffer that was current when the new one was created. Use the topmost
  `:command` or `:insert` in its mode stack, and skip transient modes (Visual,
  replace, minor modes) above it. Examples:
  - `[command, visual]` → command
  - `[command, insert]` → insert
  - `[command, insert, visual]` → insert (Visual entered from insert, e.g.
    shift-arrows)
  - `[command]` → command
- Read the live stack (`vma.kbd.default_mode_stack`), not the buffer's saved
  `mode_stack`. The saved copy is only updated on a buffer switch
  (`buffer_list.rb:116`) and on mode changes with buffer scope (`editor.rb:111`), so
  it can be stale.
- Start in insert → the new buffer's stack is `[command, insert]`, so esc returns to
  command as usual. Start in command → `[command]`.
- **Fallbacks:**
  - The previous buffer is a special-mode buffer (grep, bookmarks, file manager,
    buffer list: `@buf.default_mode = :grep/:bmark/:file_exp/:buf_mgr`, so its stack
    has no command/insert), or the keyboard is in an editor-scope mode
    (`get_scope == :editor`): use the mode of the most recently used *regular*
    buffer.
  - The first buffer at startup, or no regular buffer yet: the **remembered last
    mode** (see below). Only when nothing is remembered yet (first run ever, or the
    state file is missing) use `cnf.start_in_insert`. It defaults to on for new
    installs and is written as off into existing installs' `settings.rb` on first
    start after the upgrade, so current users see no change.
  - Session restore: all restored buffers get the startup mode, and the buffer that
    becomes current decides what comes next.
- **Remembered across restarts** (decided 2026-11-19): the last command/insert mode
  (the same "topmost command or insert" value the inheritance rule uses, taken from
  the last *regular* buffer) is saved and used as the start mode at the next startup.
  - Store it in the **data dir** (`get_data_path`, `editor.rb:776`), like the window
    layout. `marshal_save` / `save_var_to_file` (`editor.rb:345-364`) currently write
    to `get_dot_path` (the config dir), so either give them a data-dir variant or put
    the value into the same state file as the layout.
  - Save it in `Editor#save_state` / `shutdown` (`editor.rb:388-391`, next to
    `save_window_layout`) **and** when the command/insert value changes, so it
    survives a crash. Saving only on change keeps writes rare: one per mode toggle,
    not per key.
  - Ignore transient and special modes when saving. Leaving the editor in Visual
    mode or with the grep buffer current stores the underlying command/insert of the
    last regular buffer.
  - One global value, not per file. (Per-buffer modes for session-restored buffers
    could come later through `session.txt`.)
  - Test mode (`vma_test_mode?`) neither reads nor writes it, as with the layout. A
    corrupt or unknown value is ignored and falls back to `cnf.start_in_insert`.
- **Exempt buffers** keep their own mode: generated pages (key bindings help,
  free-bindings and vim-conflicts reports, diffs, shell-command output,
  `filelinks`) start in command, so a stray key can't edit them and `enter` still
  follows links. Special-mode buffers keep their `default_mode`. Mark them with a
  `create_new_buffer(..., start_mode: :command)` argument, or by the callers that
  set `default_mode`.
- **Switching** to an existing buffer restores its own saved mode, as now. The
  inheritance rule applies to *new* buffers only. Opening an already-open file is a
  switch, not a new buffer.
- Implementation point: `Buffer#initialize` sets `@mode_stack = [@default_mode]`
  (`buffer.rb:31-32`). Compute the start stack there (or in `create_new_buffer` /
  the open-file path) through a helper such as `vma.kbd.inherited_start_mode`, and
  apply it when the buffer becomes current.

**Esc toggles command → insert** (`cnf.esc_toggles_insert`):
- In Vim, esc in normal mode only cancels a pending command or count, and otherwise
  does nothing (at most a beep). `C esc` is unbound in vimlike and vim today.
  Vimlike already has the same toggle on a ctrl tap (`"C ctrl!" => :insert_mode`,
  `"I esc || I ctrl!" => :prev_mode`, `key_bindings_vimlike.rb:78,83`).
- **The second esc in a row does nothing**, so `esc esc` (Vim users' "make sure I'm
  in command mode") always ends in command mode. It's a deterministic rule, not a
  timeout.
- Esc with a pending count (`3 esc`) only clears the count. Esc mid-sequence
  (`, esc`) only cancels, as now (no matching child → back to root,
  `key_binding_tree.rb:592-606`).
- On in vimlike (and notepad, where it's moot). **Never in the `vim` scheme**, which
  must behave like Vim.
- The current mode must be clearly visible (cursor shape/color *and* a mode label).
  Check that the label is prominent enough once modes toggle.

**Tests:**
- The harness forces command mode before each test (`test_framework.rb:124`), so
  existing tests are unaffected.
- New tests:
  - inheritance from `[command]`, `[command, insert]`, `[command, visual]` and
    `[command, insert, visual]`
  - fallback from a special-mode buffer
  - generated pages start in command
  - switching restores the saved mode
  - `esc` toggles, `esc esc` ends in command, `3 esc` clears the count
  - Visual → esc → esc
  - in the vim scheme `esc` does nothing
  - `cnf.start_in_insert` off reproduces today's behavior
  - the remembered mode round-trips: save insert → "restart" (reload the state) →
    first buffer starts in insert. A remembered value wins over
    `cnf.start_in_insert`. A missing or corrupt file falls back to the setting.
    Visual/special modes at shutdown store the underlying command/insert.

### Help panel: the ~20 most important key bindings, shown by default for new users

A small side panel that lists the essential bindings for the **active scheme**. It
opens by default for new users and closes with a click (× button). The full list
stays on Help ▸ Show key bindings, which today is bound to `C , ; s k`. That's hard to
find, which is part of why this panel is needed.

Comments / design decisions:
- **Content is derived, not hardcoded.** Use a curated list of ~20 action symbols
  (the same `BASIC_ACTIONS` list proposed in `doc/key_bindings_report_plan.md`, so the
  panel and the "Basics" section of the full page agree). Look up their keys in the
  live tree (`KeyBindingTree#act_bindings[mode][action]`, `key_binding_tree.rb:89,799`).
  That way the panel is right for vimlike, vim and notepad, and for rebinds in
  `custom.rb`. Actions with no binding in the active scheme are left out.
- List for vimlike, grouped (revised 2026-11-19):
  - **Modes**: **`ctrl` (tap: press and release alone)**, the main way to switch:
    command → insert (`"C ctrl!" => :insert_mode`), insert → command
    (`"I ctrl!"`, `:prev_mode`), visual → command (`"V ctrl!"`). Then `esc`
    command, `v` visual. (`i` is not listed: ctrl covers entering insert mode.) Show `ctrl` first and explain "tap" in the label,
    since `ctrl!` notation means nothing to new users.
  - **Moving** (command/visual): `h` `j` `k` `l` left / down / up / right, `w` next
    word, `b` previous word
  - **Files**: `ctrl-s` save, `ctrl-w` close, `, n b` new. File finding (`, f`,
    `, h`, `, b`) is left out: menus and the file panel cover it, and the full page
    lists it.
  - **Editing** (command): `u` undo, `ctrl-r` redo, `x` delete char, `d d` delete
    line, `y y` copy line, `p` paste
  - **Selection** (visual): `d` delete, `y` copy
  - **Search**: `/` find, `s` easy-jump
  - **Help**: `, , s` search actions, `, ; s k` all key bindings
  - **Quit**: `Q`

  That's about 25 keys in about 20 rows: `h j k l` is one row, `w b` one row, and
  the three `ctrl` tap directions one row.
  - `l` was bound to a Ruby string (`buf.move(FORWARD_CHAR)`), which the
    action-symbol lookup can't find. Fixed 2026-11-19 (`374cca1`): `"VC l"` now uses the existing
    `:e_move_forward_char` in vimlike and vim. All the moving keys (`h j k l w b`) are
    named actions now.

  Labels come from the action descriptions (see the "Descriptive names" item), with
  the keys shown as keycaps.
- **Mode-aware.** The top line shows the current mode in large text ("INSERT — type
  normally, esc for commands" / "COMMAND — keys run commands, i to type"). The
  group for the current mode is highlighted, and it updates on mode change. That
  makes the panel the prominent mode indicator the start-in-insert / esc-toggle
  item asks for.
- **Rows are clickable** and run the action (`call_action`). That helps new users
  and means the panel is useful even before they learn the keys. The panel must
  **not take keyboard focus** (`focusable = false` on its widgets), so typing always
  goes to the editor. The e2e tests depend on that too.
- **Placement**: a right-side panel built like the key log panel, which wraps
  `@minibuf_vpane` at the grid level, independent of the file/func panel and
  two-column nesting (`gui.rb:1264-1300`). Narrow, about 220 px, and scrollable.
  Not an overlay on the text, which would cover code. If both are open, the key log
  panel and the help panel share the right side (stack them, or let showing one
  hide the other).
- **Open by default only for new users.** Shown when there's no saved state (new
  install). Closing it saves `help_panel_closed` once, globally (not per screen
  resolution), together with the window/view layout state in the data dir
  (`save_window_layout`), and it stays closed from then on. Existing installs get it
  closed by default, using the same settings migration as `cnf.start_in_insert`.
  Option: show it again once after a major version upgrade that changes bindings.
- **Reopening** must be easy to find: Help ▸ "Show help panel", a View-menu toggle
  next to the other panels, and an action for Search for Actions. Add a vimlike
  binding in the `, ;` help prefix without modifier chords, e.g. `, ; h`; check it's
  free with Show free key bindings. The panel's footer says "Reopen: Help ▸ Show help
  panel".
- Footer link: "All key bindings…" opens the full page (`show_key_bindings`).
- Test mode (`vma_test_mode?`) never auto-opens it, like the other panels.

Tests:
- In each scheme, the panel's rows resolve to non-empty keys and descriptions. No
  raw Ruby is shown.
- Closing persists (reload the state → stays closed). A new state shows it.
- Clicking a row runs its action. Typing after a click still goes to the buffer.
- The mode header follows `esc` / `i`.

Depends on / ties in with:
- "Descriptive names for key bindings" (labels)
- "Organize the Show key bindings page" (`BASIC_ACTIONS`)
- "Start in insert mode" (mode indicator)
- the layout persistence in DONE

### Modules page and module extraction

See `doc/modules_settings_plan.md`.

## DONE

Format: `- **Item title** (2026-MM-DD, `abc1234`[..`def5678`]): one or two lines on what was changed.`

- **Restore window geometry and view layout on startup** (2026-11-18, `99cd484`): window
  size/maximized, file/func/keylog panels with widths, two-column split and file, and
  minibuffer history height are saved per screen resolution (last 5) in the data dir
  and fitted to the current monitor on start. `idle_set_size` replaced by one
  `set_default_size` before show. Off in test mode or with `cnf.restore_layout = false`.
  Not yet checked in the VM: switching the guest resolution between runs.
- **Markdown (`.md`) syntax highlighting shows almost nothing with the bundled schemes**
  (2026-11-19, `7a92079`): `markup_overlay_styles` (`gui_settings.rb`) adds `def:heading`,
  `def:inline-code`, `def:link-text`, … to the generated overlay where the base scheme
  lacks them, colored from its keyword/string/comment/hyperlink styles. Optional step 2
  (hand-picked colors in `molokai_edit.xml`) not done.
