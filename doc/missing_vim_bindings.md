# Vim keybindings missing from Vimamsa

Comparison of Vimamsa's two Vim-style keymaps against standard Vim:

- `vimlike` (default) — `lib/vimamsa/key_bindings_vimlike.rb`
- `vim` (`cnf.keybindings.scheme = "vim"`) — `lib/vimamsa/key_bindings_vim.rb`

The scheme is selected in `lib/vimamsa/editor.rb` (`Editor#start`).

This list comes from reading the binding files, not from testing in the editor.
The generated [vimlike_vim_conflicts.md](vimlike_vim_conflicts.md) compares the two
keymaps binding by binding.

## Root cause

There is no general operator + motion system. Each combination (`d e`, `c w`, ...)
is bound individually, so any combination nobody wrote out is missing.

## Case changes

Done: `gUw`, `guw`, `g~w`, `gUU`, `guu`, `g~~` and `~` work in both keymaps, and
`vimlike` also has Visual `U`, `u`, `~`. Still missing: counts (`2gUw`) and other
motions or text objects after the operator (`gUe`, `gUiw`, ...), which need the
operator-pending layer below.

## Operators: change, delete, yank

- `vimlike` now has `c w`, `c e`, `c c`, `c $`, `S`, `D` and `Y`, from the shared
  `VIM_BINDINGS` table (`vim_core.rb`). `C` and `s` stay vimlike's own actions, so
  they remain `vim`-keymap only.
- Many combinations are missing in both, such as `d b`, `c b`, `y b`, `d t x`,
  `c f x`, `d G`, `d g g` and `d }`. `d j` and `d k` are missing in both keymaps
  (in `vimlike` they're commented-out TODOs).
- A count after the operator (`d 3 w`, `y 2 y`, `d 2 f x`) works only for `d <num> e`
  in `vimlike`. A count before the command (`3 d w`) works, because the action is
  repeated.
- Text objects are done in both keymaps (`lib/vimamsa/text_objects.rb`): `iw aw iW aW
  is as ip ap`, the quotes, the brackets and `it at`, after `d c y gU gu g~` and in
  Visual mode. Counts work for brackets and tags (`2di(`). Not done yet: a count after
  the operator (`d2i(`) and repeating `i(` in Visual mode to grow the selection.
- Indenting from Command mode (`>>`, `<<`, `=`) is missing. Visual `>` and `<` exist
  only in the `vim` keymap.

## Motions

- `t` / `T` (move to just before a character) and `,` (repeat `f` backwards).
- `W` / `B` / `E` (move by whitespace-separated "WORD"), and `ge`.
- `{` / `}` (paragraph), `(` / `)` (sentence) and `%` (matching bracket).
- `H` / `M` / `L` (top, middle and bottom of the screen).
- `#` (search backward for the word under the cursor).

## Scrolling and jumps

- `ctrl-e` / `ctrl-y` (scroll by one line), and `zt` / `zb`.
- `ctrl-i` (jump forward). `ctrl-o` is only an approximation that goes to the last
  edit.
- `ctrl-d` / `ctrl-u` scroll a full page instead of half a page.
- `gv` (reselect the last visual area) and `gi` (insert where you last inserted).

## Visual mode and other editing

- Line-wise visual (`V`), block visual (`ctrl-v`) and `o` (swap selection ends) are
  missing. `vimlike` binds `V` and `ctrl-v` to other actions.
- `ctrl-x` (decrement a number) is missing; `ctrl-a` is in both keymaps.
- `gJ` (join lines without adding a space) and named registers (`"a` etc.) are
  missing.

## Suggested approach

A small generic operator-pending layer, where an operator (`d`, `c`, `y`, `gU`, `gu`,
`g~`, `>`) waits for any motion or text object, would cover most of the case-change,
operator and text-object gaps at once instead of adding dozens of separate bindings.
