# Vim keybindings missing from Vimamsa

Comparison of Vimamsa's two Vim-style keymaps against standard Vim:

- `vimlike` (default) — `lib/vimamsa/key_bindings_vimlike.rb`
- `vim` (`cnf.keybindings.scheme = "vim"`) — `lib/vimamsa/key_bindings_vim.rb`

The scheme is selected in `lib/vimamsa/editor.rb` (`Editor#start`).

This list comes from reading the binding files, not from testing in the editor.
The generated [vimlike_vim_conflicts.md](vimlike_vim_conflicts.md) compares the two
keymaps binding by binding.

## Operators and motions

Done (2026-11-21): the operator + motion layer (`lib/vimamsa/vim_operators.rb`,
step 1 of `doc/vim_compatibility_plan.md`). Every operator works with every motion and
text object, with counts before the operator and before the motion (`2d3w`):

- Operators: `d c y gU gu g~ > <`. Doubled, they act on lines: `dd cc yy gUU >>`.
- Motions: `h l j k w b e W B E 0 ^ $ gg G f t F T` (with a character or `space`),
  `'x` and `` `x `` (marks). `cw` works like `ce`, and `dw` on the last word of a line
  doesn't join lines, as in vim.
- Text objects: `iw aw iW aW is as ip ap`, the quotes, the brackets and `it at`.

The `vim` keymap has all of them. `vimlike` has every combination it doesn't use for
something else (see [vimlike_vim_conflicts.md](vimlike_vim_conflicts.md)). Its own
`d w`, `d e`, `d $`, `y e`, `g U w`, ... stay, so for those keys vimlike behaves as
before. `vimlike` also gets `W B E t T` as plain motions, and its own `O` (end of line)
works after every operator (`c O`, `g U O`).

Still missing:
- Operators `=` (reindent) and `gq` (format).
- Motions `ge`, `{` / `}` (paragraph), `(` / `)` (sentence), `%` (matching bracket),
  `H` / `M` / `L` (top, middle and bottom of the screen), `,` (repeat `f` backwards),
  `;` after `t` / `T`.
- `#` (search backward for the word under the cursor).
- Repeating `i(` in Visual mode to grow the selection.

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
- `gJ` (join lines without adding a space) is missing.
- Registers are done (2026-11-21, `lib/vimamsa/registers.rb`): `""`, `"0`, `"1`–`"9`,
  `"-`, `"a`–`"z` (`"A` appends), `"+` / `"*` and `"_`, selected with `"x` before any
  copy, delete or put. They remember whether the text was whole lines. Insert-mode
  `ctrl-r x` is in the `vim` keymap only. `:reg` lists them.
