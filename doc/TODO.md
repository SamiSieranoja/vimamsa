# TODO

Generic list of future actions. Larger efforts get their own plan in `doc/*_plan.md`
and are linked from here.

When an item is finished, move it to **DONE**. Add a short summary of what was done and
the git ref(s), as a short commit hash or a range.

## Open

### Record demos; form input through the key bindings

Record a demo like a macro, into the demo step format, by capturing keys in
`match_key_conf`. First, form fields get a form input mode: GTK widgets as the
view, a vimamsa `Buffer` per field as the model, and the form window's keys going
to the key bindings. Then typing in forms (e.g. `, r r`) records and replays too.
Plan: `doc/demo_recording_plan.md`.

### Faster startup

About 0.9 s of a 2.6–3.0 s startup can be saved. The biggest item: the red-colors gem,
which cairo requires, builds every colormap when loaded (0.6–0.8 s); it can be loaded
only when it is used. Plan: `doc/startup_speed_plan.md`.

### Easy jump: line-start labels in the gutter

Easy jump labels are opaque black boxes with bold red text, drawn over the first
characters of words and lines (`easy_jump.rb`, `VMAgui#overlay_draw_text`). While
they're shown, the code under them can't be read: `AA` covers `# E`, `DD` covers `def`
(seen in the easy jump demo, 2026-11-21).

- Draw the line-start labels in the gutter, next to the line numbers, so they cover
  no code.
- Word-start labels stay in the text. Possibly make them see-through, with brighter
  text.
- `DemoPlayer#jump_label` and its test look labels up by position
  (`@easy_jump_wsmarks`), so they should still work.

### Descriptive names for key bindings that lack one

Mostly done: every binding now runs a named action (the dotted action ids, see
"Consistent, hierarchical action names"), and the key bindings page, key log and
toolbar show its description. Left: seven actions are registered with an empty
description, so they show as bare ids: `bmark.select`, `bmark.delete`, `bmgr.select`,
`bmgr.close`, `fexp.select`, `buf.history.prev` and `buf.diff`
(`grep -rn 'reg_act(.*, "")' lib modules`).

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
   - vimlike now has `c w`, `c e`, `c c`, `c $`, `S` from the shared vim table
     (2026-11-20); `C` and `s` stay vimlike's own. See `doc/vimlike_vim_conflicts.md`.
3. **Missing motions** (they then also work after operators):
   - `W` / `E` / `ge` (`B` is commented out in vimlike)
   - `T x`, and `,` (`;` exists)
   - `%`, `{` / `}`, `(` / `)`
   - `H` / `L` (`M` is taken in vimlike), `#`
4. **Doubled operators / other count commands**:
   - `>>` / `<<` with counts (Visual `>` / `<` are now in vimlike too)
   - `ctrl-x` (`ctrl-a` is now in vimlike, from the shared vim table)
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
- `run_tests_vm.rb` restores `provisioned` before every run
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

### Consistent, hierarchical action names

Action ids are ad hoc. They mix verb-first and noun-first names, use implementation
prefixes (`gui_`, `vim_`, `e_`, `V_`), contain duplicates (`undo` / `edit_undo`,
`move_next_line` / `forward_line`, …) and use inconsistent words (forward / next,
buf / buffer). Plan: `doc/action_names_plan.md`.
- dotted ids, from general to specific: `move.word.next`, `buf.close`, `sel.copy`
- an `a` proxy like `cnf`: `bindkey "C w", a.move.word.next`, and `a.buf.save!` runs an action
- namespaces map onto the key bindings report categories
- `ACTION_ALIASES` keep the old ids working in `custom.rb` and in saved macros
- `Action#path` replaces the unused `:group` option

### Tab completes file names on the command line

`:!cat /proc/cpu<tab>` should complete to `:!cat /proc/cpuinfo`. Today the command
line (`lib/vimamsa/gui_command_line.rb`) handles only Escape, Up and Down. Tab
does nothing useful.
- Complete the word before the cursor as a path: absolute, `~/…`, or relative to the
  current buffer's directory (or the working directory for unsaved buffers).
- A single match is completed in place, with `/` added for a directory. Several
  matches complete to their longest common prefix. A second Tab lists them, in the
  message area or a small popup.
- Works for `:!cmd` and `:e`, and anywhere a word looks like a path. Escape spaces,
  or quote the path, as the shell needs.
- Later: complete command names after `:!` from `$PATH`, and action ids after
  `:a.` (`doc/action_names_plan.md`).
- Test: in a temp directory with `foo_one`, `foo_two` and `bar/`, `:e ba<tab>` gives
  `bar/`, and `:e fo<tab>` gives `foo_`.

### Keymap syntax that isn't Ruby code (`map` strings and keymap files)

Declare keymaps in a plain text format, one binding per line, instead of Ruby hashes:

```
# today (key_bindings_vimlike.rb)
"C z " => "mode.browse",

# keymap file
C z         mode.browse
VC l        move.char.next
C d <num> e edit.delete.word_end
```

The last token is the action id; everything before it is the mode and the keys, in
the notation used today. This depends on the dotted ids from
`doc/action_names_plan.md`: an id always contains a `.`, so it can't be mistaken for
a key name.
- The same syntax works in two places:
  - **In Ruby, as a multiline string passed to `map`**, so it can sit in the scheme
    files, in modules and in `custom.rb`:

    ```ruby
    map <<~KEYS
      [motion]
      VC h  move.char.prev
      VC l  move.char.next
      C z   mode.browse
    KEYS
    ```
  - **In separate files** (optional), such as `keymaps/vimlike.keys`, or a user file in
    the config dir that is loaded after the scheme. This lets users rebind keys without
    writing Ruby. Loading a file is just `map(File.read(path))`, with the file name
    used in error messages.
- Lines starting with `#` are comments. A section line such as `[motion]` sets the
  category for the lines below it (`doc/key_bindings_report_plan.md`).
- Conditions (today `I tab(vma.buf.view.autocp_active)`) become named conditions
  defined in Ruby: `I tab  edit.complete.next  when completion_open`.
- Key sets for operators and motions (`doc/vim_compatibility_plan.md`, step 1) need a
  block syntax, e.g. `set op` … `end`, plus template lines like `C <op> <motion>
  operator.motion`.
- No Ruby code in the keymap syntax. The Ruby-string bindings get named actions first (the
  "Descriptive names for key bindings" item).
- The parser reports errors with file and line: an unknown action, an unknown key
  name, a mode that doesn't exist. For a `map` string, the line is the calling
  file's line plus the offset inside the string (`caller_locations`).
- Parse into the same `add_keys` / `bindkey` calls, so the tree, the conflict
  report and the tests don't change. A test checks that the `map` version of a
  scheme gives the same tree as the `add_keys` hashes it replaces.

### Git functions as a separate module

Move the git features into `modules/git/`: "Show git diff" of the current file
(`buf.diff.git`, `git_diff_buffer`) and of the whole repo (`file.diff.repo`, `git_diff_w`).
Both are in `lib/vimamsa/diff_buffer.rb` today.

Stays in core:
- the diff view: the `diffview` minor mode, `DiffLineMapper`, jump to source, and the
  unsaved-changes diff (`buf.diff`, which uses plain `diff`)
- project-root detection by a `.git` directory (`editor.rb:823`). It only looks for a
  marker and doesn't run git.

Changes needed in the module interface (checked 2026-11-20):
- **Default on.** Modules are off unless `cnf.modules.<name>.enabled` is set. Only
  `color_highlight` gets a default, hardcoded in core (`conf.rb:165`). Git diff is an
  existing feature, so add `default_enabled: true` to `_info` and drop the hardcoded
  default.
- **Menu entries anywhere.** `gui_menu.rb:57-58` hardcodes the git items under
  Actions ▸ experimental. Modules can only add items to the top-level Modules menu
  (`add_module_action`). Let a module add items to any menu path, and remove them in
  `<name>_disable`.
- **Core code that knows about git.** `Buffer#git_root` and `resolve_diff_path`, which
  runs `git rev-parse` itself, are git-specific. Replace them with a generic
  `diff_base_dir` (the directory that relative `a/` and `b/` paths in a diff are
  relative to). The module sets it when it creates the diff buffer.
- **A public diff view API.** The module has to open a diff buffer in diff view
  without copying core code. Something like `open_diff_buffer(text, name, base_dir:)`,
  which does what `create_new_buffer` + `gui_set_file_lang("diff")` + `diffview` do
  today.
- **Actions of a disabled module.** Today they give "Unknown action". Instead, say
  "enable the git module (Settings ▸ Modules)". For this, `_info` lists the module's
  action ids (`actions: ["git.diff.buf", "git.diff.repo"]`). This also lets the
  `ACTION_ALIASES` entries (`git_diff_buffer` → …) point to module actions. The alias
  test then allows an alias whose target belongs to a module.
- **Requirements.** The `git` executable, through the `requirements:` key from
  `doc/modules_settings_plan.md`. Check it with `which git`.
- **Tests.** `tests/test_diff_buffer_name.rb` calls `git_diff_buffer` directly. Add a
  test helper that loads and initializes a module for one test (`with_module(:git)`),
  so module tests don't depend on the user's settings.

Renames (with aliases): `buf.diff.git` → `git.diff.buf`, `file.diff.repo` →
`git.diff.repo`. Later candidates for the module: blame, log of the current file,
stage the current file.

### Open links in Markdown files, as with hpt `⟦…⟧` links

Enter (`handle_line_action`) on a link in a `.md` file should open it, as it does
for hyperplaintext links `⟦file⟧`. For example `[vimlike_vim_conflicts.md]` or
`[the report](vimlike_vim_conflicts.md)` in `doc/vim_compatibility_plan.md`.

Why it fails today (`Buffer#get_cur_nonwhitespace_word`, `buffer.rb:1514`):
- The word under the cursor is cut at white space, so it keeps the brackets:
  `[vimlike_vim_conflicts.md](vimlike_vim_conflicts.md)`. That's not an existing
  file, a URL, a `file:line` pointer or a `⟦…⟧` link.
- A relative path resolves against `bufs.last_dir`, not the directory of the file
  that contains the link. `hpt_check_cur_word` does use the buffer's directory.
- In `[link text](target)`, the cursor is often on the link text, which may contain
  spaces, so the target isn't in the "word" at all.

To do:
- Recognize the Markdown link forms around the cursor on the current line (not by
  white-space word):
  - `[text](target)` and `[text](target "title")`, with the cursor anywhere on it
  - `<https://…>` autolinks
  - `[text][ref]` and `[ref]` with a `[ref]: target` definition in the file
  - a bracketed file name `[name.md]` that exists next to the file, as in the
    example above
- Resolve relative targets against the file's directory, like `hpt_check_cur_word`.
- `target#anchor`: open the file and jump to the heading whose GitHub-style slug
  matches.
- Then dispatch as now: text file → open it, URL → browser, other file →
  default program (`handle_word`). Also offer it in the context menu.
- Maybe share this with `file_path_at` (`buffer.rb:1561`), which already strips
  surrounding brackets and punctuation for the hover/open-file check.
- Tests: Enter on each form in a temp `.md` file opens the right file and line.

### WYSIWYG editing: rich text with hidden markup

Bold, italic and font size shown as formatting, with the markup hidden in the file
and shown only on request ("Show markup"). The buffer holds only the visible text,
the formatting is a separate span model mirrored to GtkTextView tags, and the hpt
markers are the file format. Plan: `doc/wysiwyg_plan.md`.

### Changesets as the change format

Replace the `[pos, op, len, text]` delta arrays with OT-style changesets (`retain` /
`delete` / `insert`, with optional attributes), as in CodeMirror and Quill. They give
one `map_pos` for every position-based structure, composed undo groups, formatting
changes for WYSIWYG, and later `transform` for multiple cursors. Decided 2026-11-21.
Plan: `doc/delta_syntax_plan.md`.

### Performance: line ends and UTF-8 indexing in large files

Measured 2026-11-21 in plain Ruby 3.4, ~55-character lines. Fixed already:
`scan_indexes` (O(n^2) on non-ASCII text: 13 s → about 0.1 s for 5.5 MB) and
`get_line_end` (`select` → `bsearch`). See DONE.

Still open:
- **`update_line_ends` shifted every later line end on each edit.** Done: `@line_ends`
  is now a treap of lines (`LineTree`, see DONE and `doc/line_tree_plan.md`).
  Follow-up: loops over all lines (`fold.rb`'s fold search) call `[i]` per line,
  which is now O(log n) each. Walk the tree in order there if it shows up in
  profiles.
- **UTF-8 character indexing.** Ruby strings have no character index. Once a buffer
  contains one non-ASCII character, every `self[pos]`, `insert` and `slice!` scans from
  the start. That's 0.5 ms each at 5.5 MB, versus 0.002 ms for ASCII-only text. Motions
  and syntax checks make many such calls per keystroke.
  - First profile typing and moving around in a large non-ASCII file in the real editor
    (`perf`, or `ruby-prof`) to see whether this dominates.
  - If it does, the options are:
    - a checkpoint index: character → byte offset every ~4 KB, updated through a
      Fenwick tree, used for `byteslice` access
    - a rope: a balanced tree of chunks with character counts per node. This changes
      the `Buffer < String` model, so it's a last resort.
- The GTK side needs nothing: `GtkTextBuffer` is already a B-tree.

### Replace complicated shell scripts with Ruby scripts

The longer scripts have outgrown bash: env-var parsing, error handling, quoting,
retries and many steps. Port them to Ruby. Ruby is already the project language,
so testing and sharing helpers between scripts gets easier.

Candidates (lines as of 2026-11-20):
- ~~`run_tests_vm.sh` (130): host side~~: done, now `run_tests_vm.rb` (see DONE).
- `vm_guest_run.sh` (120): guest side; provisioning, gem build, test run
- `scripts/appimage/build_in_container.sh` (192): the AppImage build

Keep as shell:
- small wrappers: `run_e2e_vm.sh`, `scripts/appimage/build.sh`,
  `scripts/appimage/smoke_test.sh`, `install.sh`, `docker_cmd.sh`

Constraints:
- **Bootstrap without Ruby.** A clean VM (the `clean` snapshot) has no Ruby, and
  `vm_guest_run.sh` is what installs it (`apt-get install ruby ruby-dev …`). So
  keep a few lines of shell that install Ruby if it's missing and then `exec`
  the `.rb` script.
- Same for the AppImage container: the Dockerfile installs no system Ruby, and the
  script builds the bundled Ruby itself. Either add `ruby` to the Dockerfile for the
  build script only (it must not leak into the AppDir), or keep the steps before
  the Ruby build in shell.
- Use only the standard library (`open3`, `fileutils`, `optparse`); no gems,
  because they aren't installed yet when the script runs.
- Keep the same interface: env vars (`VM_NAME`, `VM_USER`, `VM_PASS`, `VM_DISPLAY`,
  `FORCE_PROVISION`, `VMA_TEST_ARGS`, `VMA_REF`, `RUBY_VERSION`), the arguments, and the exit codes
  (the suite's 0/1, 2 for missing variables). Never print `VM_PASS`.
- Shared helpers (run a command and echo `>>` steps, fail with a message) go in
  `scripts/lib/`.
- Update the references in `CLAUDE.md`, `doc/vm_snapshots_plan.md` and
  `doc/bundling_plan.md`.
- Check each port with a full VM run (`run_tests_vm.rb`) or an AppImage build plus its smoke test.

## DONE

Format: `- **Item title** (2026-MM-DD, `abc1234`[..`def5678`]): one or two lines on what was changed.`

- **`V , J <char>`: join the selected lines with a separator** (2026-11-23, `0d775ca`):
  action `sel.join.char`; lines stripped, empty ones dropped. `, J "` / `, J '` make a
  quoted comma list. Tests in `tests/test_text_transforms.rb`.

- **A binding without a key no longer exits the editor** (2026-11-23, `49cef79`):
  `bindkey "fexp ", ...` in custom.rb reached `fatal_error` (`exit!`) and quit at start
  silently. Now reported and skipped; `fatal_error` prints its message.

- **Startup warnings** (2026-11-23, `92b385a`): duplicate `"I <char>"` binding removed;
  no GtkSourceView language guess for the minibuffer's empty file name.

- **Demo playback: no user input while running; restart after edits** (2026-11-22,
  `5254114`): while a demo plays, the user's keys and clicks/drags in the text are
  ignored (`DemoPlayer.blocks_input?`, checked in `gui.rb` and `gui_sourceview.rb`), with a
  message to pause it. Paused, the editor can be used; if the text, cursor, mode or
  current buffer changed, continuing starts the demo from the beginning. Tests in
  `tests/test_demo_player.rb`.

- **XDG dirs instead of `~/.vimamsa`** (2026-11-22, uncommitted): generated files
  (session, buffer list, command and file history, file index, recorded macros,
  backups, crash reports, listen dir) go in `~/.local/share/vimamsa`; config stays in
  `~/.config/vimamsa` (`$XDG_DATA_HOME` / `$XDG_CONFIG_HOME` honored). `--user-dir`
  keeps both in one dir. The old files move once at start (`user_dirs.rb`). Tests in
  `tests/test_user_dirs.rb`, one of which fails on any fixed `~/.vimamsa` path.

- **Introduction page for first-time users** (2026-11-21, `6448bb9`): shown on
  the first start, from Help ▸ Introduction, with `:intro` or with `--intro`. It has
  inline buttons that start the demos, key names taken from the bindings, and a
  one-screen "Vimamsa for Vim users" page, plus a demo dropdown above the key log.
  `doc/intro_page_plan.md`.

- **Switching files demo** (2026-11-21, `9399229`): Help ▸ Demos ▸ Switching files
  (`scripts/demo/demo_files_steps.txt`, on shapes.rb, report.rb and notes.txt): tab,
  browse mode h / l, and the file explorer (`, f`, then k / j and l). Demos can have
  several files, and a demo folder of their own.
- **Easy jump label feedback** (2026-11-21, `2125c34`): after the first key, matching
  labels show it bright yellow and bold, and the others are dimmed. The chosen label
  stays 0.15 s after the others go. `cnf.easy_jump.glow` (off: without a GPU it made
  easy jump about 60% slower). Tests in `tests/test_easy_jump.rb`.
- **Key hint below the row** (2026-11-21, `fef2d63`): `cnf.key_hint.y_offset` px
  below the cursor's row (above it if no room), right of the text it covers.

- **Demo player: loop, pause, speed, demos menu** (2026-11-21, `19e528c`): Help ▸
  Demos ▸ Basic editing / Easy jump (`scripts/demo/demo_easyjump_steps.txt`: moves
  `to_s` with v + easy jump, x, P). A demo loops, with the file restored, until
  stopped. Buttons above the key log (Pause/Continue, −, +), ✕ closes the key log
  (stopping the demo); actions `help.demo.pause` / `.faster` / `.slower` / `.stop` /
  `.easyjump`. Tests in `tests/test_demo_player.rb`.
- **Key hint next to the cursor** (2026-11-21, `19e528c`): while the key log is
  shown, a see-through bubble with a dashed border, right of the end of the cursor's
  line, shows the current mode (badge colors), the last key and action, then fades
  (`gui_key_hint.rb`). The key log is cleared at the start of each demo round. Easy
  jump labels are logged too (`log_jump_label`). Tests in `tests/test_keylog_panel.rb`.

- **`run_tests_vm.sh` ported to Ruby** (2026-11-21, `ac4251a`): `run_tests_vm.rb`, same env
  vars, arguments, steps and exit codes, standard library only; shared helpers in
  `scripts/lib/script_helpers.rb`. `run_e2e_vm.sh` and the docs point to it.

- **Resized window after maximize restored** (2026-11-21, `36c04d3`): GNOME's auto-maximize
  maximized a restored window that covers most of the screen, which was then saved
  as maximized. `VMAgui#undo_auto_maximize` unmaximizes it to the saved size.
  Test: `test_resized_after_maximize_restored` in `tests/test_window_layout.rb`.

- **Line ends in a treap** (2026-11-21, `96234a8`): `@line_ends` is a
  `LineTree` (`lib/vimamsa/line_tree.rb`), an implicit treap with one node per line
  (length, random priority, subtree line and character counts). It answers the Array
  methods the code used (`size`, `[i]`, `bsearch_index`, `bsearch`), so no call site
  changed. An edit costs about 0.005 ms at 100k lines, down from 6.3 ms, and lookups
  about 0.004 ms. Plan: `doc/line_tree_plan.md`. Tests: `tests/test_line_tree.rb`.

- **Fast line ends for non-ASCII text** (2026-11-21, `57d3030`): `scan_indexes`
  (`string_util.rb`) counts characters only between consecutive matches, using byte
  offsets, instead of calling `MatchData#begin`, which counts from the start of the
  file each time. Loading the line ends of a 5.5 MB file with one non-ASCII character
  went from 13 s to about 0.1 s. `get_line_end` uses `bsearch` instead of `select`.
  Tests: `tests/test_line_ends.rb`.

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
