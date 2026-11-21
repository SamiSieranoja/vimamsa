# Plan: introduction page for first-time users

Done (2026-11-21), not committed yet. See DONE.

## Context

A new user starts with an empty buffer and no hint of where to begin. The demos
(basic editing, easy jump, switching files) show the editor well, but they're three
levels deep in the menu (Help ▸ Demos ▸ …), so most people won't find them. The key
bindings page is complete but long.

An introduction page opens automatically on the first start and is always available
as Help ▸ Introduction. It's a short text page with buttons that start the
recommended demos and open the other help pages.

## What exists to build on

- **Hyperplaintext** (`lang/hyperplaintext.lang`, `hyper_plain_text.rb`): `❙title❙`,
  `◼ heading`, `⦁key⦁`, and links `⟦file⟧` / `⟦help:keybindings⟧`, which open with
  enter or the context menu (`Buffer#handle_word`, `wtype == :help`,
  `gui_sourceview.rb` `ctx_open_link`). The key bindings page and `demo.txt` use it.
- **Widgets embedded in the text:** the image code (`buffer.rb`, the
  `create_child_anchor` / `add_child_at_anchor` calls) puts GTK widgets into the
  text. Buttons can work the same way. (Audio widgets use this too, but audio is
  experimental: the intro page doesn't use or mention it.)
- **Demos:** `DemoPlayer.toggle(name)`, the actions `help.demo`,
  `help.demo.easyjump` and `help.demo.files`, and `DemoPlayer::DEMOS`.
- **Bindings generated from the live tree:** `key_bindings_page` uses `BASIC_ACTIONS`
  and `vma.kbd.bindings`, so the keys it shows are right for the current scheme.
- **Vim differences:** `doc/vimlike_vim_conflicts.md` and the `help.vim_conflicts`
  page list every key that differs, and `doc/missing_vim_bindings.md` lists what is
  missing. Both are complete but long; the intro page links to a short summary (see
  "For Vim users").
- **First run:** `Editor#start` already creates `custom.rb` from `custom_example.rb`
  when it doesn't exist.

## Design

### Format: a hyperplaintext page in a read-only buffer, with buttons

The page is a template, `intro.txt` (next to `demo.txt`, shipped in the gem). It
opens in a buffer named `intro` with the hyperplaintext language, like the key
bindings page. Reasons:

- It's an ordinary editor buffer, so the reader is already using the editor: moving
  around and searching work, and so does the key log.
- Every button is also a link, so it can be reached with the keyboard. Put the
  cursor on it and press enter. The mouse works too.
- It's easy to edit: the text is a file, not GTK code.

A separate dialog was rejected: demos play in the main window, and a dialog would
have to close or get in the way.

### New link kind: `⟦run:<action>|<label>⟧`

- `Buffer#handle_word` gets a `:run` type next to `:help`; enter on the link runs the
  action with `call_action`.
- **Only actions in an allowlist run:** `help.*`, `app.demo`, `settings.*` (decide
  the exact list). Any `.txt` file can contain this syntax, so opening a downloaded
  file must not be able to run arbitrary actions. Outside the list, the link only
  shows a message.
- **Buttons:** on a help page, each `⟦run:…⟧` link is shown as a `Gtk::Button`
  with the label after `|`, in place of the link's text. The text stays in the
  buffer but is hidden by an invisible GTK tag. The button is at a child anchor
  that takes the place of a space the page adds before the link (before, because
  GTK doesn't draw a widget that follows invisible text). Clicking the button runs
  the action. In a buffer that can be edited, the link text is shown instead of
  the button while the cursor is on its line. In a read-only one (the help pages)
  the button is always shown; a cursor on the hidden text moves onto the button,
  and enter there runs the link.
- `⟦help:…⟧` gets more targets: `keybindings` (exists), `vim_conflicts`, `intro`,
  `vim_intro`.

### Keys in the text come from the bindings

The template says `{key:mode.insert}`, `{key:buf.save}` and so on. When the page is
opened, these are replaced with the bound keys from `vma.kbd.bindings` (the first
binding in Command mode, formatted as on the key bindings page, in `⦁…⦁`). The page
stays right when bindings change or with the notepad scheme. An action that has no
binding shows its menu path or the `:` command instead. A test checks that every
`{key:…}` in the template resolves.

### Content (keep it to about one screen)

```
❙Welcome to Vimamsa❙
A Vim-inspired text editor. This page: Help ▸ Introduction.

◼ Modes
Command mode: keys move and edit (badge at the bottom right shows the mode).
Insert mode: keys type text. Enter it with {key:mode.insert}, leave it with {key:mode.prev}.
Visual mode: select text, {key:mode.visual}.

◼ Watch a demo  (each plays in its own buffer; the key log on the right
                 shows every key and what it did)
⟦run:help.demo|▶ Basic editing⟧      moving, editing, undo        ~1 min
⟦run:help.demo.easyjump|▶ Easy jump⟧ jump anywhere on screen      ~40 s
⟦run:help.demo.files|▶ Switching files⟧ file finder, buffer history ~40 s

◼ The essentials
Open file {key:file.open}   File finder {key:file.finder}   Save {key:buf.save}
Search {key:search.buf}     Undo {key:undo.last}            Command line {key:mode.cmdline}

◼ Coming from Vim?
⟦help:vim_intro⟧ the main differences, in one screen

◼ Learn more
⟦help:keybindings⟧   all key bindings
⟦run:app.demo|Install demo files⟧ text and images to try
Customize: ⟦~/.config/vimamsa/custom.rb⟧ (Ruby, loaded at startup)

⟦run:help.intro.toggle_startup|Don't show at startup⟧
```

The demo lengths are measured, not guessed: `DemoPlayer` can sum the waits and
delays of a steps file. They could be generated like the keys (`{demo_len:basic}`).

### For Vim users: a one-screen summary

A second short page, `vim_intro.txt`, opened by `⟦help:vim_intro⟧` on the intro
page. It lists the differences a Vim user hits in the first minutes, and ends with
links to the full lists. Its keys use `{key:…}` too, so it stays right when the
bindings change. Content, from what the code does now (2026-11-21):

- **`:` is very limited.** It understands only `:w`, `:q`, `:wq`, `:e <file>`, `:<line
  number>`, `:!<shell command>` (output into a buffer) and `:reg`. Anything else is
  run as Ruby, so there is no `:s///`, `:g`, `:set`, `:%`, ranges or `:help`. Search
  and replace has its own commands (`{key:search.buf}`, the Search menu), and settings
  are in Settings.
- **ctrl alone switches modes.** Press and release ctrl with no other key in between:
  in Command mode it enters Insert mode, and in Insert and Visual mode it leaves
  them. `esc` works
  too, but it doesn't move the cursor one character left as Vim's does.
- **Some keys do other things:**

  | Key | Vim | Vimlike |
  |---|---|---|
  | `s` | change a character | easy jump |
  | `C` | change to end of line | grep in files |
  | `O` | open a line above | end of line |
  | `X` | delete a character back | new line below |
  | `space` | right | prefix: `space <char>` inserts a character |
  | `tab` | jump forward | switch to the last buffer |
  | `z` | prefix (`zz`, `zt`) | Browse mode |
  | `ctrl-o` | jump back | open a file |
  | Insert `ctrl-n` / `ctrl-p` | completion | line down / up |
  | Insert `ctrl-c` | leave Insert mode | copy |

  `,` starts many of vimlike's own commands (see the key bindings page).
- **Not there yet:** line-wise and block visual (`V`, `ctrl-v`); `ge`, `{` / `}`,
  `%`; `=` and `gq`; `ctrl-e` / `ctrl-y`; `gv` and `gi`.
- **The same as Vim:** operators with motions and text objects (`d c y gU gu g~ >
  <`, `dw`, `ci(`, `yap` …), counts, registers (`"a`–`"z`, `"+`), `.`, macros
  (`q` / `@`), marks.
- **Prefer Vim's keys?** Settings ▸ Keybinding scheme ▸ `vim` (restart needed).
- Links: ⟦help:vim_conflicts⟧ (every key that differs, generated) and the list of
  missing Vim bindings.

The table is short on purpose: it doesn't try to list all 42 conflicts. A test
checks each row against the live bindings (e.g. that `s` runs `jump.easy` in
vimlike), so the page can't drift from the keymap unnoticed. Rows could be
generated from `vim_binding_conflicts` with a hand-picked list of keys, but then
someone still has to write each description.

### When it is shown

- **`--intro`** on the command line shows the page at start whatever the setting,
  the user dir or other arguments say, and doesn't change the setting. It's for
  trying the page and for tests: `ruby exe/vimamsa --intro`, or with a fresh
  `--user-dir` to see a real first start.
- Shown on start when `cnf.intro.show_on_startup` is true. It defaults to true and
  is set to false after the page has been shown once, so normally the page appears
  only on the first start.
- The setting is in Settings ▸ Behavior, and the page's last button changes it.
- **Not shown** when:
  - files or dirs are given on the command line;
  - a session is being restored;
  - in test mode (`vma_test_mode?`, as for `check_session_restore`);
  - `cnf.startup_file` is set.

  In those cases the user already knows what they want.
- **Always available:**
  - Help ▸ Introduction, the first item in the Help menu;
  - the action `help.intro` (no key binding: the menu is enough);
  - `:intro` on the command line.
- The intro buffer is read-only and isn't saved in the session or file history.
  Opening it again switches to the existing buffer.

### Demos started from the page

- A demo stops when another buffer is opened. When it was started from the intro
  page, stopping it or letting it finish returns to the page (`DemoPlayer` remembers
  the buffer it was started from), so the next demo is one click away.
- Demos keep looping until stopped (current behaviour). The demo controls (pause,
  speed, ✕) are already shown above the key log.

### Switching demos while one plays

While a demo plays, the demo controls above the key log
(`gui_keylog_panel.rb`, `show_demo_controls`) also list the demos, so the user can
go to another one without the menu or the intro page:

- A dropdown (`Gtk::DropDown`) next to the pause and speed buttons, with the demo
  titles from `DemoPlayer::DEMOS` and the current one selected. Choosing another
  demo calls `DemoPlayer.toggle(name)`, which stops the playing one and starts the
  new one, keeping the speed setting. Optionally add "Next ▸", which starts the next
  demo in the list.
- For this, each demo in `DemoPlayer::DEMOS` gets a `title:` ("Basic editing") and a
  one-line `desc:`. The Help ▸ Demos menu, the intro page and the dropdown all use
  them, so a new demo needs adding in one place only.
- The key log is cleared when the demo changes, as at the start of a round.
- Test: start the basic demo, choose "Easy jump" in the dropdown; the easy jump
  demo runs, the basic one stopped, and the dropdown shows "Easy jump".

## Implementation order

1. `⟦run:action|label⟧` links: parsing in `handle_word` and the context menu, the
   allowlist, and the new `⟦help:…⟧` targets. Tests: an allowed action runs, a
   disallowed one doesn't and shows a message.
2. `intro.txt`, `{key:…}` substitution, the `help.intro` action, the Help menu item,
   `:intro`, and a read-only buffer kept out of the session. Tests: every `{key:…}`
   resolves in vimlike and notepad, and opening the page twice keeps one buffer.
3. Buttons at child anchors for `⟦run:…⟧` links. Test: clicking the button
   (`signal_emit("clicked")`) starts the demo.
4. Show on first start (`cnf.intro.show_on_startup`, the conditions above), plus the
   Settings checkbox. Test: shown with a fresh user dir, not with a file argument,
   not the second time.
5. Return to the intro page after a demo started from it.
6. `title:` / `desc:` in `DemoPlayer::DEMOS`, and the demo dropdown in the demo
   controls.
7. `vim_intro.txt` and `⟦help:vim_intro⟧`, with the test that checks its table
   against the live bindings.
8. Update the README (mention Help ▸ Introduction and `--intro`) and
   `custom_example.rb`.

`--intro` comes with step 2, so every later step can be tried with
`ruby exe/vimamsa --intro`.

Run the suite in the test VM after each step (`./run_tests_vm.rb`).

## Later

- No guided exercises on the intro page: it stays text plus demos. A separate step
  by step tutorial may come later. The intro page would then link to it, and the
  `⟦run:…⟧` links and buttons can be reused there.

## DONE

- 2026-11-21, not committed yet. All the steps:
  - `lib/vimamsa/intro_page.rb`, plus `help/intro.txt` and `help/vim_intro.txt`.
  - `⟦run:…⟧` links with an allowlist (`help.*`, `app.demo`), and inline buttons.
  - `{key:…}`, `{demos}` and `{vim_key_table}` placeholders.
  - Read-only help buffers (`Buffer#read_only`, refused in `add_delta`).
  - Help ▸ Introduction and Help ▸ Vimamsa for Vim users; `:intro`; `--intro`.
  - `cnf.intro.show_on_startup` (Settings ▸ Behavior; set false once shown at
    start).
  - `DEMOS` `title:` / `desc:` / `action:` (used by the menu, the page and the
    dropdown), and `DemoPlayer.duration`.
  - The demo dropdown above the key log (on its own row, so the panel keeps its
    width); switching keeps the speed.
  - Back to the page after a demo started from it.
  - README and `custom_example.rb`.
  - Tests: `tests/test_intro_page.rb` (19). Full suite in the VM: 500 passed.
  - Buttons are only added to help pages. A ⟦run:…⟧ link in an ordinary file
    works with the keyboard and the context menu, but gets no button: that would
    need a placeholder char in the file, as images do.
