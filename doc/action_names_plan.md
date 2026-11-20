# Plan: consistent, hierarchical action names

TODO: act next on step 5 of "Order": categories on the key bindings page from
the namespace (step 2 of `doc/key_bindings_report_plan.md`). Steps 1-4 are done
(see DONE at the end).

## Context

Actions are registered with `reg_act(:id, proc, "description", opt)` (`actions.rb:18`)
and with the `act_list` hash in `key_actions.rb:216`. Modules and minor modes register
their own actions. There are about 200 ids, chosen ad hoc over time. Users see and
type them in Search for Actions, in `custom.rb` (`bindkey "C x", :id`), on the key
bindings page, in the keylog panel, and they're stored in recorded macros.

## Problems (checked 2026-11-20)

1. **No common structure.** Some names start with the thing (`buf_save`,
   `selection_upcase`), others with a verb (`close_current_buffer`, `create_new_file`,
   `copy_cur_line`). Others are named after how they start (`start_buf_manager`,
   `invoke_replace`).
2. **Prefixes say where the code lives or which mode it's for, not what it does:**
   `gui_file_finder`, `vim_change_word` (where the binding came from), `e_move_forward_char`,
   `V_join_lines` (a mode letter).
3. **Duplicates under different names:**
   - `undo` / `edit_undo` and `redo` / `edit_redo`
   - `jump_last_edit` / `jump_to_last_edit`
   - `move_backward_char` / `e_move_backward_char`
   - `move_next_line` / `forward_line` and `move_prev_line` / `backward_line`
   - `grep_buffer` / `invoke_grep_search`
4. **Mixed words for the same idea:**
   - next / forward / forwards, prev / backward / backwards
   - beginning / start, cur / current, buf / buffer
   - find / search / grep / ack
   - show / print / toggle
5. **The `:group` option is unused.** About 50 actions set it, but nothing reads
   `opt[:group]`, and the `act_list` loop (`key_actions.rb:326`) drops it.
6. **About half the bindings aren't named actions at all.** They are Ruby strings: 134
   of 281 in vimlike, 80 of 159 in vim. The "Descriptive names for key bindings" item
   in `doc/TODO.md` turns them into actions, using the names from this plan.

## Naming scheme: dotted paths

Ids are dotted paths, from general to specific: `move.word.next`, `buf.save`,
`sel.copy`, `case.line.upper`. This is the same idea as the `cnf.tab.width` settings.

### Dots or underscores (investigated)

I looked at two forms: underscores (`move_word_next`) and dotted paths
(`move.word.next`). **I recommend dots:**

- **Fewer keypresses.** `.` is one key and `_` is two (shift + `-`). The ids are
  typed in Search for Actions, on the command line and in `custom.rb`.
- **An exact hierarchy, at any depth.** Splitting on `.` gives the levels, so
  Move ▸ word ▸ next. With underscores, `color_highlight_toggle` can't be split
  correctly without a list of module ids.
- **Like `cnf`.** A small proxy object `a` gives the same chained syntax as settings:

  ```ruby
  bindkey "C w", a.move.word.next     # a reference; nothing runs
  a.buf.save!                          # runs the action (like cnf.x.y! reads a setting)
  bindkey "C w", "move.word.next"      # the plain string works too
  ```

  On the command line, `:a.buf.save!` runs an action. Completion after `a.move.`
  can list the children.
- **Checked in Ruby 3.4:** a proxy based on `BasicObject` with `method_missing` takes
  every path in the tables below. This includes keyword segments (`a.move.line.end`,
  `a.move.word.next`, `a.case.word.upper`) and names that `Object` already defines
  (`a.class`, `a.send`, `a.display`), because `BasicObject` doesn't have those.

How dotted ids work in the code:
- **The registry key is a string** (`"move.word.next"`). `reg_act` and `bindkey` accept
  that string, the `a.…` reference, or (for old ids) a symbol.
- **String bindings are looked up first.** A string binding is today run as Ruby. The
  dispatcher already tries a registered action first (`key_binding_tree.rb:933`), so
  `"move.word.next"` resolves to the action and any other string still runs as Ruby.
  Some ids are also valid Ruby (`buf.save` calls `Buffer#save`). For those the
  registered action wins, which is what such a binding means anyway.
- **Typos fail when the binding is made.** `a.move.wrod.next` builds a reference
  without complaint, so `bindkey` checks that the id exists. If it doesn't, it
  reports an error and suggests the closest id.
- **A path can be both an action and a parent**, for example `buf.save` and
  `buf.save.as`. The reference is only a name, and running needs `!`, so both work.
- **Use `a` only where it's safe.** A local variable called `a` hides the method `a`,
  and `lib/` assigns `a = …` in 37 places. So `a.` is for `custom.rb` and the command
  line. Code in `lib/` uses the string form.

### Rules

- **The first segment is the namespace** (table below). Module and minor-mode
  actions use the module or mode id: `dictation.toggle`, `fexp.copy`,
  `color_highlight.toggle`.
- **The object comes before the verb or direction:** `move.word.next`, `move.word.prev`,
  `move.word.end`. Related actions sort together, and completion groups them.
- **Prefer one-word segments.** That keeps ids short and free of `_`. Use `_` only when
  a segment really needs two words (`vim_conflicts`).
- **Fixed vocabulary:**
  - direction: `next` / `prev`
  - position: `start` / `end`
  - `eol` means "to the end of the line" after an operator
  - on/off: `toggle` as the last segment
  - `buf`, never `buffer`, and `sel` for the selection
- **Opening a picker or panel takes no verb:** `file.finder`, `buf.switcher`,
  `app.settings`.
- **No mode letters, scheme names (`vim`), layers (`gui`, `e`) or tool names**
  (`ack`) in ids, unless the tool is what the user chooses.

### Namespaces

The namespaces match the categories in `doc/key_bindings_report_plan.md`. A
binding to a named action gets its category from the namespace, with no manual
`cat:` tag.

| Namespace | Category | Contents |
|---|---|---|
| `app` | app | quit, restart, settings, custom.rb, demo |
| `mode` | insert / visual | mode switches, command line |
| `move` | motion | cursor motion inside the buffer |
| `jump` | search | non-local jumps: last edit, easy-jump, file under cursor |
| `search` | search | search and replace in the buffer, action search |
| `grep` | grep | grep, searching file contents (built-in) |
| `ack` | grep | ack, the external search program |
| `edit` | edit | delete, change, paste, join, indent, comment, increment, autocomplete |
| `undo` | undo | undo, redo, repeat |
| `case` | case | case transforms |
| `sel` | visual | operations on the selection |
| `buf` | buffer | the current buffer and the buffer list |
| `file` | file | the file on disk: finder, history, open dialog |
| `panel` | view | file, function and keylog panels |
| `view` | view | columns, scrolling, colors |
| `style` | hpt | hyper plaintext styles |
| `macro` | macro | macros |
| `mark` | marks | bookmarks |
| `lsp` | code | LSP |
| `term` | code | running lines in a terminal |
| `help` | help | key bindings, conflicts, messages |
| `debug` | debug | debug, eval, tests |
| `custom` | custom | the user's own actions in `custom.rb` |
| `<module>` | `module:<name>` | module actions |
| `<minor mode>` | `mode:<id>` | minor-mode actions |

## Renames

These are proposals. Rows marked "check" need a look at what the action really does
before it gets its final name.

### app, mode, help, debug

| Old | New |
|---|---|
| `quit` | `app.quit` |
| `restart_editor` | `app.restart` |
| `show_settings` | `app.settings` |
| `reload_customrb` / `edit_customrb` | `app.customrb.reload` / `app.customrb.edit` |
| `install_demo_files` | `app.demo` |
| `insert_mode` / `start_visual_mode` / `prev_mode` | `mode.insert` / `mode.visual` / `mode.prev` |
| `start_cmd_line` | `mode.cmdline` |
| `notepad_escape` | `mode.notepad.escape` (check) |
| `show_key_bindings` / `show_free_key_bindings` | `help.keys` / `help.keys.free` |
| `show_vim_binding_conflicts` | `help.vim_conflicts` |
| `show_message_history` | `help.messages` |
| `enable_debug` / `disable_debug` | `debug.on` / `debug.off` |
| `savedebug` | `debug.save` |
| `eval_buf` | `debug.eval.buf` |
| `experimental_eval` | `debug.eval.sel` |
| `command_to_buf` | `debug.command` |
| `debug_buf_hex` | `debug.buf.sha256` |
| `print_buffer_access_list` | `debug.buf.access` |
| `run_tests` | `debug.tests` |

### move, jump

| Old | New |
|---|---|
| `e_move_forward_char`, `move_forward_char` | `move.char.next` |
| `e_move_backward_char`, `move_backward_char` | `move.char.prev` |
| `move_next_line`, `forward_line` | `move.line.next` |
| `move_prev_line`, `backward_line` | `move.line.prev` |
| `jump_beginning_of_line` / `jump_end_of_line` | `move.line.start` / `move.line.end` |
| `jump_next_word_start` / `jump_prev_word_start` | `move.word.next` / `move.word.prev` |
| `jump_next_word_end` | `move.word.end` |
| `jump_start_of_buffer` / `jump_end_of_buffer` | `move.buf.start` / `move.buf.end` |
| `jump_to_random` | `move.random` |
| `jump_last_edit`, `jump_to_last_edit` | `jump.edit.prev` |
| `jump_to_next_edit` | `jump.edit.next` |
| `easy_jump` | `jump.easy` |
| `open_file_under_cursor` | `jump.file` |
| `lsp_jump_to_definition` | `lsp.definition` |

### search, grep

| Old | New |
|---|---|
| `find_in_buffer` / `find_next` | `search.buf` / `search.next` |
| `gui_search_replace` | `search.replace` |
| `invoke_replace` | `search.replace.cmd` (check) |
| `search_actions` | `search.actions` |
| `grep_buffer`, `invoke_grep_search` | `grep.buf` |
| `grep_refresh` | `grep.refresh` |
| `content_search` | `grep.files` (built-in, no external program) |
| `ack_search` | `ack.search` (own namespace: ack is an external program, to become a module) |

### edit, undo, case, sel

| Old | New |
|---|---|
| `delete_char_forward`, `vim_delete_char` | `edit.delete.char` |
| `vim_delete_char_backward` | `edit.delete.char.prev` |
| `vim_delete_to_eol` | `edit.delete.eol` |
| `insert_backspace` | `edit.backspace` |
| `insert_delete` | `edit.delete.char_or_sel` |
| `vim_change_line` / `vim_change_word` / `vim_change_to_eol` | `edit.change.line` / `edit.change.word` / `edit.change.eol` |
| `vim_substitute_char` | `edit.change.char` |
| `vim_open_line_above` / `insert_new_line` | `edit.line.above` / `edit.line.below` (check) |
| `copy_cur_line` | `edit.line.copy` |
| `paste_after_cursor` / `paste_before_cursor` | `edit.paste.after` / `edit.paste.before` |
| `paste_over_after` / `paste_over_before` | `edit.paste.over.after` / `edit.paste.over.before` |
| `increment_word` | `edit.word.increment` |
| `auto_indent_buffer` | `edit.indent.buf` |
| `comment_selection` | `edit.comment` |
| `autocp_manual_trigger` / `toggle_autocomplete` | `edit.complete` / `edit.complete.toggle` |
| `undo`, `edit_undo` / `redo`, `edit_redo` | `undo.last` / `undo.redo` |
| `vim_repeat_last_action` | `undo.repeat` |
| `word_upcase` / `_downcase` / `_swapcase` | `case.word.upper` / `.lower` / `.swap` |
| `line_upcase` / `_downcase` / `_swapcase` | `case.line.upper` / `.lower` / `.swap` |
| `selection_upcase` / `_downcase` / `_swapcase` / `_capitalize` | `case.sel.upper` / `.lower` / `.swap` / `.capitalize` |
| `vim_toggle_case` | `case.char.toggle` |
| `select_all` | `sel.all` |
| `insert_select_up` / `insert_select_down` | `sel.line.prev` / `sel.line.next` |
| `copy_selection` / `cut_selection` / `vim_change_selection` | `sel.copy` / `sel.cut` / `sel.change` |
| `selection_reverse` | `sel.reverse` |
| `selection_remove_indent` / `selection_remove_common_indent` | `sel.unindent` / `sel.unindent.common` |
| `V_join_lines` / `V_to_latex_itemize` | `sel.join` / `sel.latex_itemize` |
| converters (`editor.rb:463`, registered by converter id) | `sel.convert.<id>` |

### buf, file

| Old | New |
|---|---|
| `buf_save` / `buf_save_as` | `buf.save` / `buf.save.as` |
| `buf_revert` / `buf_backup` / `backup_all_buffers` | `buf.revert` / `buf.backup` / `buf.backup.all` |
| `buf_new`, `create_new_file` | `buf.new` |
| `close_current_buffer` / `close_all_buffers` | `buf.close` / `buf.close.all` |
| `gui_select_buffer` / `start_buf_manager` | `buf.switcher` / `buf.manager` |
| `history_switch_backwards` / `history_switch_forwards` | `buf.history.prev` / `buf.history.next` |
| `select_buffer_language` | `buf.language` |
| `encrypt_file` / `set_unencrypted` | `buf.encrypt` / `buf.encrypt.off` |
| `git_diff_buffer` / `diff_buffer` | `buf.diff.git` / `buf.diff` (check) |
| `diff_buffer_jump_to_source` | `diffview.source` |
| `git_diff_w` | `file.diff.repo` |
| `open_file_dialog` | `file.open` |
| `gui_file_finder`, `start_file_selector` | `file.finder` (check whether both are needed) |
| `gui_file_history_finder` / `fhist_remove_nonexisting` | `file.history` / `file.history.prune` |
| `delete_current_file` / `set_executable` | `file.delete` / `file.executable` |
| `put_file_path_to_clipboard` / `put_file_ref_to_clipboard` | `file.path.copy` / `file.ref.copy` |
| `extract_file_links` | `file.links` |

### panel, view, style, mark, term, lsp, macro

| Old | New |
|---|---|
| `toggle_file_panel` / `toggle_func_panel` / `toggle_keylog_panel` | `panel.files.toggle` / `panel.funcs.toggle` / `panel.keylog.toggle` |
| `refresh_func_panel` | `panel.funcs.refresh` |
| `file_panel_next_file` / `file_panel_prev_file` / `file_panel_easy_jump` | `panel.files.next` / `panel.files.prev` / `panel.files.jump` |
| `toggle_two_column` / `toggle_active_window` | `view.columns.toggle` / `view.columns.switch` |
| `center_on_current_line` | `view.center` |
| `gui_ensure_cursor_visible` / `gui_refresh_cursor` | `view.cursor.show` / `view.cursor.refresh` |
| `refresh_colors` | `view.colors.reload` |
| `set_line_style_h1` … `_h4`, `_heading`, `_title`, `_bold`, `_italic` | `style.line.h1` … `style.line.italic` |
| `clear_line_styles` | `style.line.clear` |
| `set_style_bold` / `set_style_italic` / `set_style_link` / `clear_formats` | `style.bold` / `style.italic` / `style.link` / `style.clear` |
| `show_images` | `style.images` |
| `bookmark_add` / `bookmark_list` | `mark.add` / `mark.list` |
| `execute_current_line_in_terminal` / `…_autoclose` | `term.line` / `term.line.autoclose` |
| `lsp_print_functions` / `lsp_restart` / `lsp_debug` | `lsp.functions` / `lsp.restart` / `lsp.debug` |
| `run_last_macro` | `macro.run.last` |

### Modules and minor modes

| Old | New |
|---|---|
| `insert_terminal` / `insert_calculator` | `terminal.insert` / `calculator.insert` |
| `toggle_highlight_colors` | `color_highlight.toggle` |
| `audio_stop` | `audio.stop` |
| `dictation_*`, `tts_*`, `ollama_*` | `dictation.*`, `tts.*`, `ollama.*` (first `_` → `.`) |
| `fexp_*`, `bmgr_*`, `bmark_*` | `fexp.*`, `bmgr.*`, `bmark.*` (first `_` → `.`) |

## Keeping old names working

The old ids are used in places this repo doesn't control: users' `custom.rb` and
saved macros. `macro.rb` records action ids and stores them in `named_macros.json` and
in the Marshal backups.

- `ACTION_ALIASES = { old_symbol => "new.id" }` in `actions.rb`.
  - `ActionList#[]`, `#include?` and `#call` resolve aliases, and so do `bindkey`
    and `unbindkey`.
- Using an old id from `custom.rb` logs once per id:
  `action :close_current_buffer is now buf.close`.
- Macros are converted when they're loaded and saved back with the new ids.
- Search for Actions shows only new ids, but searching for an old id still finds the
  action.
- The aliases stay for at least two releases. They're listed here and in the release
  notes.

## Using the hierarchy

- `Action#path` (the segments) replaces `:group`. Remove `:group` from the
  registrations.
- **Search for Actions** shows `move.word.next  Move to the next word  (w)`. A query
  that starts with a namespace and a dot (`move.`) lists only that namespace.
- **Command line:** `:a.<tab>` completes namespaces, then the segments below them.
- **Key bindings page:** the category comes from the namespace. Manual `cat:` tags
  are then needed only for Ruby-string bindings.
- **Menu:** unchanged. `gui_menu.rb` already takes its labels from the action.

## Tests

- Every registered id matches `^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$`. Its first segment is
  a known namespace, or a loaded module or minor-mode id.
- No two actions have the same proc source and description. This catches duplicates
  like `undo` / `edit_undo`.
- Every alias points to a registered action.
- `bindkey` accepts the string, the `a.…` reference and an old symbol (which logs
  once). An unknown id is an error that names the closest id.
- `a.buf.save!` runs the action.
- A macro saved with old ids runs and is resaved with new ids.
- Regenerate `doc/vimlike_vim_conflicts.md`, which `tests/test_vim_conflicts.rb`
  checks.

## Order

1. String ids in the registry, the `a` proxy, aliases, and their tests. No renames
   yet.
2. Merge the duplicates (problem 3), keeping the old names as aliases.
3. Rename one namespace per commit. Each commit changes the registrations, the
   bindings in all three schemes, `gui_menu.rb`, the tests (`act(:…)`) and
   `custom_example.rb`, and adds the aliases. Run the full suite in the VM after each
   commit.
4. `Action#path`, drop `:group`, add namespace filtering and command-line completion.
5. Categories on the key bindings page from the namespace (step 2 of
   `doc/key_bindings_report_plan.md`).
6. Name the Ruby-string bindings with this scheme, as part of the descriptive-names
   TODO item.

## DONE

- **Step 1: string ids, the `a` proxy, aliases** (2026-11-20, `7115ff8`).
  `actions.rb`: `ACTION_ID_RE`, `ACTION_ALIASES`, `ActionRef` (BasicObject;
  `a.x.y` is a reference, `a.x.y!` runs it, an unknown id raises with a "did you
  mean"), and `ActionList#resolve`, which every lookup goes through: a reference
  becomes its string, an old id its new one, with a message once per old id.
  `bindkey` resolves old symbols and rejects an unknown `a.…` reference with the
  closest id (`DidYouMean::SpellChecker`), skipping the binding like an unknown
  mode. Ruby-string bindings are registered with `opt[:code]`, so `exec_action`
  runs a string as an action only when it is a real registered id. Search for
  Actions runs its pick through `exec_action`. Macros are converted on load
  (`Macro#convert_action_aliases`); converted named macros are saved back.
  Tests: `tests/test_action_ids.rb`.
  Left for step 3, when aliases exist in numbers: Search for Actions finding an
  action by its old id.
- **Step 2: duplicates merged** (2026-11-20, `8da8571`). Merged straight
  into their final ids, so step 3 doesn't rename them again: `undo.last`
  (`undo`, `edit_undo`), `undo.redo` (`redo`, `edit_redo`), `jump.edit.prev`
  (`jump_last_edit`, `jump_to_last_edit`), `move.char.prev`
  (`move_backward_char`, `e_move_backward_char`), `move.char.next`
  (`e_move_forward_char`; there was no `move_forward_char`), `move.line.next` /
  `move.line.prev` (`move_next_line` / `forward_line`, `move_prev_line` /
  `backward_line`), `grep.buf` (`grep_buffer`, `invoke_grep_search`). The old
  ids are aliases. `invoke_grep_search` (menu Actions ▸ Grep) called the
  removed `gui_grep` and failed; it now runs `grep.buf`. Every reference in
  the three schemes, `vim_core.rb`, `gui_menu.rb`, `search_replace.rb`,
  `tests.rb` and the tests uses the new ids.
- **Step 3: renames, one namespace per commit** (2026-11-20, `30eff08`..`e236da3`,
  and `53fb148` for ack, plus the commit that adds this entry). Every action
  registered by lib/ and modules/ now has a dotted id; the old ids are aliases
  in `ACTION_ALIASES`. Converters register `sel.convert.<id>` (with the
  converter id as alias, in `reg_conv`). `custom_example.rb` uses a new
  `custom` namespace for the user's own actions. New tests: every id is
  `<namespace>.x.y` with a known namespace, module or minor mode, and no two
  actions share code and description (actions from `custom.rb` are skipped).
  Decisions that differ from the tables above:
  - `ack_search` is `ack.search`: ack is an external program and is to become
    its own module. `content_search` (the built-in `FileContentSearch`) is
    `grep.files`.
  - `delete_char_forward` (`edit.delete.char`) and `vim_delete_char`
    (`edit.delete.char.inline`) are not merged: on an empty line vimlike's `x`
    joins lines and vim's does nothing.
  - `start_file_selector` opens the file explorer, so it is `file.explorer`,
    not `file.finder`. `update_file_index` is `file.finder.reindex`.
  - `insert_new_line` (Enter) is `edit.newline`, not `edit.line.below`.
  - Not in the tables: `line_action` → `jump.line`, `page_down`/`page_up` →
    `move.page.next`/`.prev`, browse mode → `mode.browse`/`mode.browse.exit`,
    `delete_line` → `edit.delete.line`, `delete_selection` → `sel.delete`,
    `kbd_dump_state` → `debug.kbd`, macro finder/naming → `macro.find`/`macro.name`.
  - More duplicates merged: `jump_to_start_of_buffer`/`jump_start_of_buffer`
    (`move.buf.start`), the `end` pair, `buf_new`/`create_new_file` (`buf.new`);
    duplicate registrations of `ack_search` and `open_file_dialog` removed.
  - Hook names that equal an action id (`$hook.call(:insert_new_line)`) are
    not action ids and keep their names.
  Found, not fixed: vimlike `C , , f` is bound to `:file_finder`, which has
  never been registered (since 2021); the finder is on `C , f` and `C , z`.
- **Step 4: using the hierarchy** (2026-11-20, `2882944`).
  `Action#path` gives the segments; the 51 `:group` options are gone (nothing
  read them). `ActionList#complete(prefix)` lists the next level below a
  prefix (`"move."` => `move.buf.`, `move.char.`, ..., `move.random`).
  Search for Actions shows `id  description` and the key; a query starting
  with `<namespace>.` searches only that namespace, `move.` alone lists all of
  it, and an old id finds the renamed action (aliases are matched, not
  shown). Command line: tab after `a.` completes one level at a time; with
  several candidates it fills their common prefix and lists them as a message.
  The tab key itself is tested only through `CommandLine#complete_action_id`,
  not with a real key press.
