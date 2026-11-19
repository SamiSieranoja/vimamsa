# Plan: better Vim compatibility

TODO: act next on item 1 of "Order of work": the shared `VIM_BINDINGS` table,
loading its non-conflicting entries into vimlike. Then step 1, the operator +
motion layer. When an item is finished, move it to the DONE section at the end
of this document with a short summary and the git ref(s).

Goal: someone who knows Vim can start using Vimamsa without relearning basic
editing.

The `vim` keymap (`lib/vimamsa/key_bindings_vim.rb`) is the reference
implementation of Vim behavior. The default `vimlike` keymap
(`lib/vimamsa/key_bindings_vimlike.rb`) gets **every Vim binding that doesn't
conflict with a binding vimlike already has**. A generated report records
every conflict (see "Conflicts" below).

[missing_vim_bindings.md](missing_vim_bindings.md) lists what is missing
today. This file says what to build, and in which order.

## Why the grammar matters most

Today each key combination is bound by hand (`C d e`, `C c w`, `C y $`, ...).
Vim users don't memorize those combinations. They combine an operator, a count
and a motion. Any combination nobody wrote out does nothing, and users notice
that within minutes. So the first and biggest step is a general
operator + motion layer. Most of the later steps build on it.

## Shared Vim bindings

The Vim actions and the binding table go in shared code, for example
`lib/vimamsa/vim_core.rb` (actions, motions, operators, text objects) and a
table `VIM_BINDINGS` of `key => action`. The two keymaps use the table
differently:

- **`vim` keymap:** binds the whole table.
- **`vimlike` keymap:** loads its own bindings first, then binds each table
  entry that doesn't conflict with them. Entries that conflict are skipped.
  Vimlike's own bindings always win, so existing users see no change in
  behavior.

"Conflict" is decided by a function, not by hand (see the next section). New
Vim bindings therefore show up in vimlike automatically, unless they clash.

## Conflicts: definition and automatic report

### What counts as a conflict

The check and its report are done (see DONE); the definition below is the
rule that loading the shared table into vimlike must follow.

A Vim binding `M k1 k2 ... kn` (mode `M`) conflicts with vimlike when one of
these holds:

1. **Same keys, different action:** vimlike binds exactly the same key sequence
   in mode `M` to something else. Example: `C s` is `easy_jump` in vimlike
   but "substitute character" in Vim.
2. **A vimlike binding is a prefix of the Vim one:** vimlike binds a shorter
   sequence that runs at once, so the Vim sequence can never be reached.
   Example: vimlike `C z` (start browse mode) blocks `z t`, `z z` and `z b`.
3. **The Vim binding is a prefix of vimlike ones:** for example, vimlike's
   `,` is a leader key with dozens of `, x` bindings, so Vim's `,` (repeat
   `f`/`t` backwards) can't be bound. The same goes for `space`, which starts
   `C space <char>`.

Bindings for the same action, or ones that agree in meaning, are "shared",
not conflicts.

The check walks the real `KeyBindingTree` after vimlike has loaded, so it
always matches the code. It is not a hand-kept list.

### Known conflicts, for orientation

These are from reading the code; the report is the authority:

| Keys (Command mode)       | vimlike                        | Vim                          |
| ------------------------- | ------------------------------ | ---------------------------- |
| `s`                       | easy_jump                      | substitute char              |
| `C`                       | content search                 | change to end of line        |
| `X`                       | open line below                | delete char before cursor    |
| `,`                       | leader prefix                  | repeat `f`/`t` backwards     |
| `space`                   | `space <char>` insert prefix   | move right                   |
| `z`                       | start browse mode              | `zz`, `zt`, `zb`, folds      |
| `tab`                     | switch to last buffer          | jump forward (`ctrl-i`)      |
| `V`, `ctrl-v`             | other actions                  | linewise / block visual      |

## Steps, in priority order

### 1. Operator + motion layer

- **Motions** are objects that, given a buffer, a position and a count, return
  a target position. Each one is also marked:
  - charwise or linewise (`j`, `k`, `G` and `gg` are linewise),
  - inclusive or exclusive (`e` and `f` are inclusive; `w` and `b` are exclusive).
- **Operators** (`d c y > < = gu gU g~ gq`) take a range plus a
  linewise/charwise flag and act on it. Doubling an operator (`dd`, `cc`, `>>`,
  `gUU`) acts on `count` lines.
- **Counts** work on both and multiply: `3dw`, `d3w`, `2d3w`. Counts inside a
  sequence already work where a binding has `<num>` (see DONE); the layer makes
  them general.
- **Operator-pending state in `KeyBindingTree`.** After an operator key, the
  next keys are read as a motion or text object, with an optional count. `esc`
  cancels.
- The same motion objects drive plain cursor movement and Visual-mode extension,
  so each motion is written only once.
- Keep `cw` behaving like `ce`, and keep `dw` stopping at the end of the line,
  as in Vim.
- Replace the hand-made bindings (`C d e`, `C c w`, `C y $`, ...) with the
  generic layer.

The conflict check applies inside operator-pending state too. When vimlike
binds `d <x>` to something of its own, that wins, and the report lists it.

### 2. Missing motions

- `t` / `T`, with `;` and `,` repeating them.
- `%`.
- `?`, and `#` for the word under the cursor.
- `W B E ge gE`.
- `{ }` and `( )`.
- `H M L`.
- Half-page `ctrl-d` / `ctrl-u`; `ctrl-e` / `ctrl-y`; `zt zz zb`.

Most of these are small once step 1 exists. The ones that don't conflict
(`t`, `%`, `W`, `{`, ...) go into vimlike too.

### 3. Visual modes

- Linewise `V` and blockwise `ctrl-v`. Block mode needs `I` / `A` for inserting
  text on many lines at once.
- `o` (go to the other end of the selection) and `gv` (select the last area again).
- Visual mode applies operators through the step 1 layer (`V>`, `vgU`, ...).

In vimlike, `V` and `ctrl-v` already have other uses, so they are conflicts.
The modes themselves are still shared code, and vimlike can reach them
through other keys if wanted.

### 4. Registers, put, repeat and undo

- Registers remember whether text was yanked linewise or charwise. After `yy`
  or `dd`, `p` / `P` puts it below or above the line, not at the cursor.
- Registers: named (`"a`–`"z`, with `"A` appending), unnamed `""`, yank `"0`,
  numbered `"1`–`"9`, clipboard `"+` / `"*`, and black hole `"_`. Also
  `ctrl-r x` in Insert mode.
- `.` repeats the last change exactly: the operator, the motion and count, and
  any text typed in Insert mode. Recording changes as data (step 1) makes this
  possible.
- One Insert-mode session (`i...esc`) is one undo step.

### 5. Ex commands

Extend `lib/vimamsa/gui_command_line.rb`, which already handles `:w :q :wq :e :42 :!`:

- `:s/pat/rep/flags` with ranges: `%`, `.`, `$`, `N,M`, `'<,'>`. This comes first.
- `:noh`, `:x`, `:wa`, `:qa`.
- `:bn`, `:bp`, `:bd`, `:b N`.
- `:<range>d`, `:<range>y`, `:<range>>`, `:g/pat/cmd`, `:v/pat/cmd`.
- `:set` for common options, mapped onto `cnf`: `ts`, `sw`, `et`, `nu`,
  `wrap`, `ic`, `scs`.
- Translate Vim regex syntax (`\<`, `\>`, `\(`, `\)`, `\v`) to Ruby regex.

The command line already runs Ruby code as a fallback. Vim commands must be
tried first, and Ruby only when nothing matches. The command line is shared,
so this applies to both keymaps.

### 6. Smaller habits

- A real jumplist: `ctrl-o` / `ctrl-i` and ``` `` ```.
- `gi`, `gJ`, `ctrl-x` (decrement), `gq`.
- Insert mode: `ctrl-w`, `ctrl-u`, `ctrl-o {cmd}`.

## Supporting work

### Differential tests against real Vim

A vim-compatibility test suite (for example
`tests/test_vim_compat.rb`) runs each case in both editors and compares the
buffer text and cursor position:

```sh
vim -Nu NONE -i NONE -es -c 'exe "norm! <keys>"' -c 'wq' file
```

A case is just `(start text, start cursor, keys)`, so one table can hold
hundreds of cases. Skip the suite when `vim` isn't installed.

- Run every case with the `vim` keymap.
- Also run it with `vimlike`, except for cases whose keys are in the
  generated conflict list. That proves the shared bindings behave the same in
  both keymaps.

Done so far for text objects only (see DONE); the general suite is open.

This makes "compatible" something the tests measure, and it catches the
off-by-one edge cases (`$`, `e` at the end of a word, `cw`, linewise put) that
reading the code misses.

### Onboarding

- **First run:** ask whether to use "Vim keys" or "Vimamsa keys". Today a
  Vim user has to find the scheme setting on their own.
- **A "differences from Vim" page:** a short list of the deliberate
  differences in the `vim` keymap, built from the header comment of
  `key_bindings_vim.rb`. For vimlike, the generated conflict report already
  covers this. Reach both through `:help vim` or the Help menu.
- **Optional:** read simple mappings (`nnoremap`, `inoremap` and `vnoremap`
  lines only) from `~/.vimrc`, or from a `~/.vimamsa/vimrc`, so personal
  mappings carry over.

### Investigate: switching keymap without restart

Today the scheme (`cnf.keybindings.scheme`) is read once in `Editor#start`, and
changing it needs a restart. Find out whether a switch at runtime (from
Settings, or `:set keymap=vim`) is feasible, and what it would break:

- **Rebuilding the tree:** a new `KeyBindingTree` must be built, and then
  every binding made after the scheme file must be added again. That includes
  module bindings (`search_replace.rb`, `file_manager.rb`, buffer manager,
  bookmarks, diff view), plugins and both phases of `custom.rb`. They are now
  scattered `bindkey` calls run once at startup. They would need to be
  replayable, either by recording every `bindkey` call with its origin or by
  giving each module a `bind_keys` hook.
- **Actions:** scheme files register actions (`reg_act`) and define helper
  methods (`_insert_move`, ...) with the same names in both schemes. Leftovers
  from the old scheme stay in `vma.actions`, and redefinitions overwrite each
  other. Scheme-only actions would need to be namespaced or unregistered.
- **Global side effects:** scheme files also set `cnf.mode.*` cursor colors,
  which overwrites what the user set in `custom.rb`.
- **Live state:** the current mode, a half-typed key sequence, a pending
  count, macro recording, minor modes on open buffers (`fexp`, `grep`,
  `bmgr`) and `vma.kbd` listeners (`setup_kbd_handlers`) all point into the
  old tree. The switch has to happen from a clean state: Command mode, no
  pending keys, listeners moved to the new tree.
- **Things that cache bindings:** the menu labels (`act_bindings`), the key
  binding help buffer and the conflict report must be rebuilt.
- **Macros and muscle memory:** recorded macros are key sequences, so they
  mean something else in the other scheme.
- **Tests:** tests assume vimlike (`--test` forces it). A switch test would
  check that bindings, modes and the user's custom bindings survive vimlike →
  vim → vimlike.

The sandbox loader written for the conflict report (it loads a scheme file
into a separate tree and restores the actions, methods and `cnf` it touches)
is a first step and shows which side effects exist. The outcome of the
investigation is a short note: feasible as is, feasible after a refactor (say
which), or keep the restart.

## Order of work

1. Move the existing Vim bindings into the shared table. Load the
   non-conflicting ones into vimlike. This is small, and it defines the rules
   for everything after. (The conflict report and its test are done.)
2. The operator-pending layer, ported motions, and the differential test suite.
   Port the existing hand-made bindings first, so nothing gets worse. This
   includes the text object bindings, which are bound per operator for now.
3. Registers that remember linewise text, and linewise put.
4. Missing motions.
5. `V` and `ctrl-v`.
6. `.` repeat, and undo grouping for Insert sessions.
7. `:s` with ranges, then the other Ex commands.
8. Onboarding: the first-run question and the differences page.
9. Step 6 items and `.vimrc` import.
10. The investigation into switching keymaps without restart. It can run any
    time; the sandbox loader it builds on exists.

Each step regenerates `doc/vimlike_vim_conflicts.md` and updates
`missing_vim_bindings.md` and the header comment of `key_bindings_vim.rb`.

## DONE

- **Conflict report** (2026-11-18, `b7d113a`): `vim_binding_conflicts` in
  `key_bindings_report.rb` loads both keymap files into separate key trees (a
  sandbox loader that restores `vma.kbd`, actions, helper methods and cursor
  colors) and classifies each vim binding as shared, missing from vimlike, or
  a conflict (same keys with another action, blocked by a shorter vimlike
  binding, vimlike uses the keys as a prefix, or taken by a `<char>` binding).
  Bindings that run the same code count as shared. The report is
  `doc/vimlike_vim_conflicts.md`, regenerated with
  `VMA_UPDATE_DOC=1 ruby exe/run_tests.rb --headless vim_conflicts`;
  `tests/test_vim_conflicts.rb` fails when it is out of date. Help menu:
  "Vim keys that differ in vimlike". Differs from the plan: no "Added to
  vimlike" group yet (needs the shared table), and "Not implemented" lists
  only vim-keymap bindings missing from vimlike, not a full reference list.
- **Text objects** (2026-11-18, `4c5ed8b`): `lib/vimamsa/text_objects.rb`.
  `iw aw iW aW is as ip ap`, quotes (`" ' \``), brackets `( [ { <` with the
  `b`/`B` aliases, and `it`/`at`, after `d c y gU gu g~` and in Visual mode, in
  both keymaps. Follows vim 9.1, including the white space `aw`/`a"` take,
  linewise inner blocks, `di(` using the next block on the line, and a count
  before the operator (`2di(`). Bound per operator for now, not through the
  operator-pending layer (step 1).
- **Differential test against real vim, text objects** (2026-11-18, `4c5ed8b`,
  `e464117`): `tests/test_text_objects.rb` holds 57 cases with vim's results
  and re-checks them against `vim -Nu NONE -es` when vim is installed. The
  test VM now installs vim, so the check runs there.
- **Count inside a key sequence** (2026-11-19, `2e9fb0b`): `d 3 e` works, and
  any binding with `<num>`. The count multiplies one typed before the
  sequence (`2 d 3 e` = 6). A first piece of the counts in step 1.
