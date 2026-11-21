# Vim keybinding scheme: standard vim behavior, as close as the current
# action inventory allows. Does not load vimlike. The Vim bindings themselves
# are the shared VIM_BINDINGS table (vim_core.rb), which vimlike also loads
# where it doesn't conflict; this file adds the modes and the vim keymap's own
# deviations. Selected via cnf.keybindings.scheme = "vim" (applied on restart).
#
# Operators, motions and text objects combine freely (d w, c 3 e, g U t x,
# > j, d i (, ...): the "vim operators" templates of VIM_BINDINGS and the key
# sets in vim_operators.rb.
# Not implemented (no core primitives) — intentionally left unbound:
#   %, ?, #, ge, { }, ( ), = and gq, V (linewise) / ctrl-v (blockwise)
#   visual, : ex commands, faithful change-only "." repeat,
#   insert-mode ctrl-w.
# Known deviations kept on purpose:
#   C tab = switch to last buffer; C enter = line action;
#   ctrl-d/ctrl-u scroll a full page, not half; ctrl-o approximates the
#   jumplist with jump_to_last_edit; "." repeats only the last f/F find.

module Vimamsa
vma.kbd.add_mode("C", :command)
vma.kbd.add_mode("I", :insert, :insert)
vma.kbd.add_mode("V", :visual, :visual)
vma.kbd.add_mode("M", :minibuffer)
vma.kbd.add_mode("R", :readchar)
vma.kbd.add_minor_mode("audio", :audio, :command)
vma.kbd.add_minor_mode("macro", :macro, :command)
vma.kbd.add_mode("B", :browse, :browse, scope: :editor)
vma.kbd.add_mode("X", :replace, :replace, name: "Replace")
vma.kbd.set_default_mode(:command)
vma.kbd.__set_mode(:command)

cnf.mode.command.cursor.background = "#05c5a0"
cnf.mode.default.cursor.background = "#03fcca"
cnf.mode.visual.cursor.background = "#bc6040"
cnf.mode.replace.cursor.background = "#fc0331"
cnf.mode.browse.cursor.background = "#f803fc"
cnf.mode.insert.cursor.background = "#ffffff"
cnf.mode.inactive.cursor.background = "#777777"

def _insert_move(op)
  if op == :pagedown
    vma.gui.page_down
  elsif op == :pageup
    vma.gui.page_up
  else
    buf.move(op)
  end
end

def insert_select_move(op)
  buf.continue_selection
  _insert_move(op)
end

def insert_move(op)
  buf.end_selection
  _insert_move(op)
end

# Vim behavior: the shared table and its actions, see vim_core.rb
bind_vim_bindings

# ── vim keymap's own bindings (not Vim behavior) ─────────────────────────────

add_keys "vim misc cat:buffer", {
  # Kept deviations (documented in the header)
  "C tab" => "buf.switch.last",
  # prev/next file in file panel order (no-op while the panel is hidden)
  "C alt-h" => "panel.files.prev",
  "C alt-l" => "panel.files.next",
  "C enter || C return" => ["jump.line", proc { buf.handle_line_action() }, "Line action"],

  # Browse mode keys (mode reachable only via the "mode.browse" action)
  "B h" => "buf.history.prev",
  "B l" => "buf.history.next",
  "B p" => "panel.files.prev",
  "B n" => "panel.files.next",
  "B z" => "mode.browse.center",
  "B enter || B return || B esc || B j || B ctrl!" => "mode.browse.exit",
  "B s" => "move.page.prev",
  "B d" => "move.page.next",
  "B r" => "move.page.next.quarter",
  "B e" => "move.page.prev.quarter",
  "B i" => "move.buf.start",
  "B o" => "move.buf.end",
  "B c" => "buf.close",
  "B ;" => "jump.edit.prev",
  "B q" => "jump.edit.prev",
  "B w" => "jump.edit.next",
  "B m" => "macro.run.last",
}

# Audio minor mode (used by the audio module; unreachable without it)
bindkey "audio f || audio right", ["audio.forward", proc { Audio.seek_forward }, "Seek forward in audio stream"]
bindkey "audio left", ["audio.backward", proc { Audio.seek_forward(-5.0) }, "Seek backward in audio stream"]
bindkey "audio space", "audio.stop"
bindkey "audio q || audio esc", "mode.prev"

# vim i_ctrl-r: insert a register. Here, not in VIM_BINDINGS, so vimlike
# doesn't get a new ctrl chord from the shared table.
bindkey "I ctrl-r <char>", "edit.insert.register", keywords: "vim insert"

end # module Vimamsa
