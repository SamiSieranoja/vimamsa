# Plan: recording demos, and a form input mode

TODO: not started. Act next on step 1 of "Implementation order".

## Context

Demos (Help ▸ Demos, `lib/vimamsa/demo_player.rb`) are step files written by
hand: `keys`, `type`, `wait`, `delay`, `target` (format in the header of
`scripts/demo/demo_steps.txt`). Recording one, the way a macro is recorded,
would make new demos much quicker to write.

The player feeds each key to `KeyBindingTree#match_key_conf`, as if typed. A
recorder can capture keys at the same place. But some input never reaches the
key bindings. Forms (`PopupFormGenerator`, e.g. `, r r` search and replace)
use `Gtk::Entry` widgets that handle their own keys, so typing in them can't be
recorded and the player can't type into them.

The direction (2026-11-21): all text input goes through the key bindings,
including editing form fields. So this plan has two parts:

1. **Form input mode.** Form fields stay normal GTK input widgets, each backed
   by a vimamsa `Buffer`. Key handling in the form window is overridden: keys
   go to the key bindings, in a mode for form input.
2. **Demo recorder.** It captures keys in `match_key_conf` and writes the
   existing step format. Thanks to part 1 it needs no special case for forms.

## Part 1: form input mode

### Design

**The GTK widget is the view, a `Buffer` is the model.** Each field of a form
(`Gtk::Entry` for one line; a `Gtk::TextView` later for several) gets a
vimamsa `Buffer` holding its text and cursor position. The widget only shows
it:

- After each key action, the widget's text and cursor (and selection) are set
  from the buffer: `entry.text = fb.to_s.chomp`, `entry.position = fb.pos`.
- The widget never edits its own text. When something else changes it (a
  middle-click paste, a drop), the `changed` signal copies the new text into
  the buffer as one edit, so the buffer stays the source of truth.
- A mouse click in a field moves the buffer's cursor (`notify::cursor-position`
  → `fb.set_pos`) and makes that field current.

**Overriding the key handling.** The form window gets an
`EventControllerKey` in the capture phase, like the main window
(`VMAgui#reset_controllers`). It translates each key to the editor's key name
and calls `vma.kbd.match_key_conf`, then returns true so the GTK widget never
sees the key.

- The key name translation is now inside `VSourceView#handle_key_event`. Move
  it to one function, e.g. `gui_key_name(keyval, keystr, modifiers)`, used by
  both windows. Then the form window gets the same names (`ctrl-r`, `ctrl!`,
  `space` ...) and the same modifier handling (the `modifiers` signal).
- `@entry_has_focus` / `notify_entry_focus` (the calculator module's way of
  letting a GTK entry take the keys) is the opposite of this direction.
  Migrate it in step 7 and remove it afterwards.

**The mode.** A new mode for form input, e.g. `vma.kbd.add_mode("F", :form)`,
active while a form has the focus:

- Very basic bindings, like a GTK entry works now (decided 2026-11-21):
  typing edits the current field (`F <char>` → `form.insert.char`),
  `backspace`, `delete`, `left` / `right`, `home` / `end`, and the clipboard
  keys `ctrl-a` (select the whole field), `ctrl-c` (copy the selection),
  `ctrl-x` (cut it), `ctrl-v` (paste at the cursor, over the selection). A
  field's selection is set by `ctrl-a` or by selecting with the mouse in the
  widget (mirrored into the buffer); typing or deleting replaces it. Copy and
  paste use the system clipboard (`Clipboard`), not the registers. Plus the
  form keys:
  `tab` / `shift-tab` next and previous field, `enter` submit (or press the
  focused button), `esc` cancel. Nothing modal inside a field.
- Vim-style editing in fields comes later, if at all: a form command sub-mode
  (a minor mode of `:form`: `h l w b e x d w`, `i a`), with `esc` going to it
  and a second `esc` cancelling.
- The mode badge shows FORM. The key log and key hint show form keys like any
  others.
- When the form closes, the mode before it comes back (the mode stack).

**Which buffer actions edit.** Edit actions use `buf` / `vma.buf`. While a
form is current, they must edit the field's buffer:

- `vma.form` holds the current form: its fields, the current field, and its
  buffer `vma.form.buf`.
- Form actions (`form.*`) edit `vma.form.buf` directly. That is all the basic
  bindings need.
- Only for the later vim-style editing: let `buf` resolve to `vma.form.buf`
  while form mode is active, to reuse the normal edit and motion actions. That
  needs care: code that expects `buf.view`, highlighting, autosave, the buffer
  list.
- Field buffers are not in the buffer list or the file history, have no file,
  and need no `VSourceView`. `Buffer` today always creates a GTK view
  (`gui_create_buffer` in `Buffer#initialize`), so it needs a way to be
  created without one, e.g. `Buffer.new(text, nil, prefix, view: false)`.
  `$minibuffer = Buffer.new(">", "")` is a precedent of a buffer outside the
  list.

**Input methods.** Keys taken in the capture phase bypass GTK input methods
(compose, dead keys, CJK input). The main editor already works this way, so
forms get the same behaviour, no worse than the editor. A later improvement
for both is to take committed text from a `Gtk::IMContext`.

### The command line: its own mode

Forms stay simpler than the command line (decided 2026-11-21). The command
line (`gui_command_line.rb`, a `Gtk::Entry`) gets its own mode, e.g.
`cmdline`, not form mode. It uses the same field machinery: a GTK widget as
the view, a field `Buffer` as the model, keys overridden to go to the key
bindings.

- The basic field editing keys are bound in both modes from one shared
  definition (a helper that binds `<char>`, `backspace`, `delete`, `left` /
  `right`, `home` / `end`, `ctrl-a` / `ctrl-c` / `ctrl-x` / `ctrl-v` to a
  given mode). So both edit the same way, without
  form mode growing.
- On top of that, only the command line has history (`up` / `down`), tab
  completion of `a.` action ids, `enter` to run and `esc` to close.
- Form mode keeps only what forms need: the basic keys, `tab` / `shift-tab`
  between fields, `enter` submit, `esc` cancel.
- The existing `M` / `:minibuffer` mode (`key_bindings_vimlike.rb`, marked
  "TODO: needed?") could become the command line's mode, or be removed. Check
  what still uses it before step 7.

### What moves to form mode

1. `PopupFormGenerator` (`gui_form_generator.rb`): search and replace
   (`, r r`), confirmations (`Gui.confirm`, e.g. "Install demo files?"), other
   generated forms.
2. The calculator module's entry (`@entry_has_focus`).
3. Later: the Settings dialog fields, the select windows (`gui_select_window.rb`)
   if they take text. The GTK file chooser stays native, or is replaced by
   the file explorer.

## Part 2: demo recorder

### Recording

- `help.demo.record` toggles recording, like macro recording, as Help ▸ Demos
  ▸ Record demo. A status indicator shows "● REC" while recording
  (`VMAgui#set_status_indicator`). The key that stops recording isn't
  recorded.
- The capture point is `KeyBindingTree#match_key_conf(c, translated_c,
  event_type)`, the one entry point for keys, which is also where
  `DemoPlayer#press` feeds them. For each key it records the time (monotonic
  clock), the key name, the mode before the key, and the action it ran (from
  `:key_action`).
- **Bare modifiers:** `ctrl` is recorded only when its release (`ctrl!`) comes
  with no other key in between. That is what `ctrl!` means, and what
  `press("ctrl")` replays. Otherwise `ctrl-r` would replay as a mode switch
  plus `ctrl-r`. The same goes for `alt` and `shift`.
- **Starting state:** at the start, the current file's text is saved as the
  demo's start file, and the cursor goes to the top (the player starts there),
  or its position is saved.
- **Mouse:** clicks and scrolling aren't recorded (the format has no mouse
  steps). If a click moves the cursor or changes the buffer while recording,
  show a warning in the status line.
- Input that still bypasses the key bindings (dialogs not yet in form mode)
  also gets a warning when it opens during recording.

### Turning the keys into steps

- `delay`: the median gap between keys, rounded to 0.05 s, clamped to
  0.2–0.8 s.
- `wait`: a gap clearly longer than the delay (over 2 × delay), minus the
  delay, rounded to 0.1 s and capped at 3 s, so the recorder's hesitation
  doesn't bore the viewer.
- `type`: runs of plain characters typed in Insert mode (or in a form field).
  Other keys go into `keys` lines, split at waits.
- **Easy jump:** labels depend on the window size, so recorded label keys
  wouldn't replay in another window. After a `jump.easy` action, the label
  keys are replaced with `target line N` (the line the cursor ended on) and
  `keys @JUMP_LABEL@`, as in `demo_easyjump_steps.txt`.
- **Comments:** each group of keys gets the action description from the key
  log (`# Jump to the start of the next word`), so the file reads like the
  hand-written ones and is easy to edit.
- **Forms:** with part 1 done, keys typed into a form are ordinary keys in
  form mode, recorded and replayed like any others. Opening a form can be
  asynchronous (`PopupFormGenerator` queues popups), so the player must not
  type into the editor before the form is up. The recorder writes the mode at
  points where it changed because of a window (`mode form`), and the player
  waits there, up to a timeout, until that mode is active.

### Saving and playing

- A recorded demo is saved in the user dir:
  `<user dir>/demos/<name>/steps.txt` plus its start files.
- The step format gets header commands: `title TEXT`, `desc TEXT`, `file NAME`
  (start files, in the demo's folder). Built-in demos can use them too, in
  place of the `title:` / `desc:` / `files:` in `DemoPlayer::DEMOS`.
- `DemoPlayer` lists user demos after the built-in ones: Help ▸ Demos, the
  demo dropdown above the key log, and (optionally) the introduction page.
- Recording asks for a name when it stops (a form, so in form mode).

### Things that can make playback differ

- **Undo grouping by time** (`cnf.undo.group_threshold`): played back at
  another speed, the same keys may form different undo steps, so `u` undoes a
  different amount. The player could close an undo group after each step, or
  the recorder could note undo boundaries.
- The keymap scheme: record and play in the same one (write it in the header,
  `scheme vimlike`, and refuse or warn on a mismatch).
- Buffer history order, for demos that switch files (the files demo depends
  on it).
- Settings that change what keys do (e.g. `cnf.undo.insert_one_step`).

## Implementation order

1. Move key name translation out of `VSourceView#handle_key_event` into one
   function used by the main window. No behaviour change. Tests: the existing
   suite, plus a few key names (`ctrl-r`, `ctrl!`, `space`, shifted
   characters).
2. Form mode for `PopupFormGenerator`: field buffers (`Buffer` without a
   view), the capture controller on the form window, mode `F` with insert,
   delete, cursor keys, tab, enter, esc, and syncing the widgets from the
   buffers (and back for clicks and pastes). Tests: open the search and
   replace form, type with `keys`, tab, type, enter; the buffer text is
   replaced. Mouse paste into a field reaches its buffer. Esc cancels.
3. (Later, not part of this plan's first round) Vim-style editing in fields:
   a form command sub-mode, with `buf` resolving to the field buffer while in
   form mode.
4. Recorder core: start/stop action and menu item, capture in
   `match_key_conf`, the bare-modifier rule, saving raw keys plus the start
   file. Tests: feed keys with `keys` and fake times, check the recorded list.
5. Converting to steps: `delay`, `wait`, `type`, comments, easy jump targets,
   `mode` sync points. Tests: generated text for known key sequences; record,
   play back, same final buffer text (including `, r r` once step 2 is done).
6. User demos in `DemoPlayer`: header commands, the user `demos` folder,
   listing in the menu and the dropdown, naming on stop.
7. The command line in its own mode (shared basic editing keys, plus
   history, completion, run, close), and the calculator entry in form mode;
   remove `@entry_has_focus`.

Run the suite in the test VM after each step (`./run_tests_vm.rb`).

## Open questions

- Mode letters and names: `F` / `:form` (`F` is free today); the command
  line's mode (a new one, or the existing `M` / `:minibuffer`).
- Should recorded demos be shareable as a single file (steps plus start file
  inlined), for sending to someone?

## DONE

(nothing yet)
