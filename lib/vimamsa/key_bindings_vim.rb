# Vim keybinding scheme: standard vim behavior, as close as the current
# action inventory allows. Standalone scheme file (does not load vimlike);
# selected via cnf.keybindings.scheme = "vim" (applied on restart).
#
# Not implemented (no core primitives) — intentionally left unbound:
#   generic {op}{motion} operator-pending, t/T, %, ?, #, W/B/E/ge,
#   V (linewise) / ctrl-v (blockwise) visual, : ex commands, >>/<<,
#   named registers, faithful change-only "." repeat, backward ranges
#   (db, cb, insert-mode ctrl-w).
# Known deviations kept on purpose:
#   "$" parks the cursor on the newline (one past vim's last char);
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

# ── composite actions for vim commands not covered by a single action ────────

# get_range(:to_line_end) inverts on an empty line / cursor-on-newline and
# would delete the previous newline (buffer.rb get_range) => guard.
reg_act(:vim_delete_to_eol, proc {
  b = buf
  b.delete2(:to_line_end) if b.pos < b.line_ends[b.lpos]
}, "Delete to end of line (vim D)")

reg_act(:vim_change_to_eol, proc {
  b = buf
  b.delete2(:to_line_end) if b.pos < b.line_ends[b.lpos]
  vma.kbd.set_mode(:insert)
}, "Change to end of line (vim C / c$)")

reg_act(:vim_change_line, proc {
  b = buf
  b.jump(BEGINNING_OF_LINE)
  b.delete2(:to_line_end) if b.pos < b.line_ends[b.lpos]
  vma.kbd.set_mode(:insert)
}, "Change whole line, keep newline (vim cc/S)")

reg_act(:vim_change_word, proc {
  buf.delete2(:to_word_end) # vim cw ~= ce semantics; close enough
  vma.kbd.set_mode(:insert)
}, "Change word (vim cw/ce)")

reg_act(:vim_substitute_char, proc {
  buf.delete(CURRENT_CHAR_FORWARD) if buf.current_char != "\n"
  vma.kbd.set_mode(:insert)
}, "Substitute char (vim s)")

reg_act(:vim_delete_char, proc {
  buf.delete(CURRENT_CHAR_FORWARD) if buf.current_char != "\n"
}, "Delete char under cursor; no-op on empty line (vim x)")

reg_act(:vim_delete_char_backward, proc {
  buf.delete(BACKWARD_CHAR) if buf.cpos > 0
}, "Delete char before cursor; no-op at col 0 (vim X)")

reg_act(:vim_open_line_above, proc {
  b = buf
  b.jump(BEGINNING_OF_LINE)
  # insert_txt_at neither auto-indents nor moves the cursor: @pos ends up on
  # the inserted "\n" = the new empty line, matching vim O.
  b.insert_txt_at("\n", b.pos)
  b.set_pos(b.pos) # refresh view + lpos/cpos
  vma.kbd.set_mode(:insert)
}, "Open line above (vim O)")

reg_act(:vim_toggle_case, proc {
  b = buf
  c = b.current_char
  if !c.nil? and c != "\n"
    b.replace_with_char(c.swapcase) # does not advance the cursor
    b.move(FORWARD_CHAR)            # vim ~ advances, even on non-letters
  end
}, "Toggle case of char and advance (vim ~)")

reg_act(:vim_change_selection, proc {
  buf.delete(SELECTION) # ends visual mode itself
  vma.kbd.set_mode(:insert)
}, "Delete selection and enter insert mode (vim visual c/s)")

# APPROXIMATION: set_last_command is currently only fed by f/F finds, so this
# repeats the last find, not the last change like vim's ".".
reg_act(:vim_repeat_last_action, proc { repeat_last_action() },
        "Repeat last recorded command (approximation of vim .)")

# ── motions ──────────────────────────────────────────────────────────────────

add_keys "vim motion", {
  "VCX up" => "buf.move(BACKWARD_LINE)",
  "VCX down" => "buf.move(FORWARD_LINE)",
  "VCX right" => "buf.move(FORWARD_CHAR)",
  "VCX left" => "buf.move(BACKWARD_CHAR)",
  "VC h" => :e_move_backward_char,
  "VC l" => "buf.move(FORWARD_CHAR)",
  "VC j" => :forward_line,
  "VC k" => :backward_line,
  "C space" => "buf.move(FORWARD_CHAR)",
  "C backspace" => "buf.move(BACKWARD_CHAR)",

  "VC e" => :jump_next_word_end,
  "VC b" => :jump_prev_word_start,
  "VC w" => :jump_next_word_start,

  # NOTE: "G(condition)" must be defined before "G"
  "VC G(vma.kbd.next_command_count!=nil)" => "buf.jump_to_line()",
  "VC G" => :jump_end_of_buffer,
  "VC g g" => :jump_start_of_buffer,
  "VC g ;" => :jump_last_edit,

  # Counts; "0" is BOL only when no count is pending
  "VC /[1-9]/" => "vma.kbd.set_next_command_count(<char>)",
  "VC 0(vma.kbd.next_command_count!=nil)" => "set_next_command_count(<char>)",
  "VC 0(vma.kbd.next_command_count==nil)" => "buf.jump(BEGINNING_OF_LINE)",
  "VC ^" => "buf.jump(FIRST_NON_WHITESPACE)",
  "VC $" => "buf.jump(END_OF_LINE)",

  "VC f <char>" => "buf.jump_to_next_instance_of_char(<char>)",
  "VC F <char>" => "buf.jump_to_next_instance_of_char(<char>,BACKWARD)",
  "VC f space" => "buf.jump_to_next_instance_of_char(' ')",
  "VC F space" => "buf.jump_to_next_instance_of_char(' ',BACKWARD)",
  "VC ;" => "repeat_last_find",

  "VC *" => "buf.jump_to_next_instance_of_word",
  "VC /" => :find_in_buffer,
  "C :" => :start_cmd_line,
  "C n" => :find_next,
  "C N" => "$search.jump_to_previous()",

  "VCI pagedown" => :page_down,
  "VCI pageup" => :page_up,
  "C ctrl-f" => :page_down,
  "C ctrl-b" => :page_up,
  "C ctrl-d" => "buf.move(:forward_page)",  # approx: full page, vim: half
  "C ctrl-u" => "buf.move(:backward_page)", # approx: full page, vim: half
  "C ctrl-o" => :jump_to_last_edit,         # approx of vim jumplist back
  "C z z" => :center_on_current_line,

  # Marks
  "CV m <char>" => "buf.mark_current_position(<char>)",
  'CV \' <char>' => "buf.jump_to_mark(<char>)",
  "C ` <char>" => "buf.jump_to_mark(<char>)",
}

# ── editing ──────────────────────────────────────────────────────────────────

add_keys "vim edit", {
  # Enter insert mode
  "C i" => :insert_mode,
  "C a" => "buf.move(FORWARD_CHAR);vma.kbd.set_mode(:insert)",
  "C A" => "buf.jump(END_OF_LINE);vma.kbd.set_mode(:insert)",
  "C I" => "buf.jump(FIRST_NON_WHITESPACE);vma.kbd.set_mode(:insert)",
  "C o" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");vma.kbd.set_mode(:insert)',
  "C O" => :vim_open_line_above,

  # Delete
  "C x" => :vim_delete_char,
  "C X" => :vim_delete_char_backward,
  "C d d" => [:delete_line, proc { buf.delete_line }, "Delete current line"],
  "C d e" => "buf.delete2(:to_word_end)",
  "C d w" => :delete_to_next_word_start,
  "C d $" => :vim_delete_to_eol,
  "C d 0" => :delete_to_line_start,
  "C d ' <char>" => "buf.delete2(:to_mark,<char>)",
  "C D" => :vim_delete_to_eol,

  # Change / substitute
  "C c c" => :vim_change_line,
  "C c w" => :vim_change_word,
  "C c e" => :vim_change_word,
  "C c $" => :vim_change_to_eol,
  "C C" => :vim_change_to_eol,
  "C S" => :vim_change_line,
  "C s" => :vim_substitute_char,

  # Yank / paste
  "C y y" => :copy_cur_line,
  "C Y" => :copy_cur_line,
  "C y w" => "buf.copy(:to_next_word)",
  "C y e" => "buf.copy(:to_word_end)",
  "C y $" => "buf.copy(:to_line_end)",
  "C y 0" => "buf.copy(:to_line_start)",
  "C y ' <char>" => "buf.copy(:to_mark,<char>)",
  "C p" => :paste_after_cursor,
  "C P" => :paste_before_cursor,

  # Misc edits
  "C r <char>" => "buf.replace_with_char(<char>)",
  "C r space" => "buf.replace_with_char(' ')",
  "C J" => "buf.join_lines()",
  "C ~" => :vim_toggle_case,
  "C ctrl-a" => "buf.increment_current_word", # vim ctrl-a: increment number
  "C ." => :vim_repeat_last_action,

  # Undo / redo
  "C u" => :undo,
  "C ctrl-r" => :redo,
}

# ── visual mode ──────────────────────────────────────────────────────────────

add_keys "vim visual", {
  "C v" => :start_visual_mode,
  "V esc" => "buf.end_visual_mode",
  "V ctrl-c" => "buf.end_visual_mode",
  "V y" => "buf.copy_active_selection()",
  "V d" => [:delete_selection, proc { buf.delete(SELECTION) }, ""],
  "V x" => "buf.delete(SELECTION)",
  "V s" => :vim_change_selection,
  "V c" => :vim_change_selection,
  "V J" => :V_join_lines,
  "V u" => "buf.transform_selection(:downcase)",
  "V U" => "buf.transform_selection(:upcase)",
  "V ~" => "buf.transform_selection(:swapcase)",
  "V g U" => :selection_upcase,
  "V g u" => :selection_downcase,
  "V >" => "buf.indent_selection",
  "V <" => "buf.unindent_selection",
}

# ── insert mode ──────────────────────────────────────────────────────────────

add_keys "vim insert", {
  "I esc" => :prev_mode,
  "I ctrl-c" => :prev_mode, # vim: ctrl-c leaves insert mode
  "I <char>" => "buf.insert_txt(<char>)",
  "I space" => 'buf.insert_txt(" ")',
  "I enter" => :insert_new_line,
  "I backspace" => :insert_backspace,
  "I ctrl-h" => :insert_backspace,          # vim i_ctrl-h = backspace
  "I ctrl-j" => "buf.insert_new_line()",    # vim i_ctrl-j = new line

  # Completion (vim i_ctrl-n / i_ctrl-p; popup guards first)
  "I tab(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_next",
  "I shift-tab(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_previous",
  "I shift!(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select",
  "I ctrl-n" => :autocp_manual_trigger,
  "I ctrl-p" => :autocp_manual_trigger,
  "I ctrl-space" => :autocp_manual_trigger,

  "I tab" => "buf.insert_tab",
  "I shift-tab" => "buf.unindent",

  "I shift-up" => :insert_select_up,
  "I shift-down" => "insert_select_move(FORWARD_LINE)",
  "I shift-left" => "insert_select_move(BACKWARD_CHAR)",
  "I shift-right" => "insert_select_move(FORWARD_CHAR)",
  "I shift-pagedown" => "insert_select_move(:pagedown)",
  "I shift-pageup" => "insert_select_move(:pageup)",

  "I left" => "insert_move(BACKWARD_CHAR)",
  "I right" => "insert_move(FORWARD_CHAR)",
  "I down" => "insert_move(FORWARD_LINE)",
  "I up" => "insert_move(BACKWARD_LINE)",
  "I pagedown" => "insert_move(:pagedown)",
  "I pageup" => "insert_move(:pageup)",
}

# ── replace mode (vim R) ─────────────────────────────────────────────────────

add_keys "vim replace", {
  "C R" => "vma.kbd.set_mode(:replace)",
  "X esc" => "vma.kbd.to_previous_mode",
  "X <char>" => "buf.replace_with_char(<char>);buf.move(FORWARD_CHAR)",
}

# ── macros / infrastructure ──────────────────────────────────────────────────

add_keys "vim misc", {
  # Macros: q<char> records, q stops, @<char> runs, @@ repeats
  "VC q <char>" => "vma.kbd.set_mode(:macro);vma.macro.start_recording(<char>)",
  "macro q" => "vma.kbd.to_previous_mode; vma.macro.end_recording",
  "C @ @" => :run_last_macro,
  "C @ <char>" => "vma.macro.run_macro(<char>)",

  # READCHAR mode (argument input for f/F, r, m, ', q, @)
  "R <char>" => "readchar_new_char(<char>)",

  # Kept deviations (documented in the header)
  "C tab" => "bufs.switch_to_last_buf",
  "C enter || C return" => [:line_action, proc { buf.handle_line_action() }, "Line action"],

  # Browse mode keys (mode reachable only via the :start_browse_mode action)
  "B h" => :history_switch_backwards,
  "B l" => :history_switch_forwards,
  "B z" => "center_on_current_line();call_action(:exit_browse_mode)",
  "B enter || B return || B esc || B j || B ctrl!" => :exit_browse_mode,
  "B s" => :page_up,
  "B d" => :page_down,
  "B r" => proc { vma.gui.page_down(multip: 0.25) },
  "B e" => proc { vma.gui.page_up(multip: 0.25) },
  "B i" => :jump_to_start_of_buffer,
  "B o" => :jump_to_end_of_buffer,
  "B c" => :close_current_buffer,
  "B ;" => :jump_last_edit,
  "B q" => :jump_to_last_edit,
  "B w" => :jump_to_next_edit,
  "B m" => :run_last_macro,
}

# Audio minor mode (used by the audio module; unreachable without it)
bindkey "audio f || audio right", [:audio_forward, proc { Audio.seek_forward }, "Seek forward in audio stream"]
bindkey "audio left", [:audio_backward, proc { Audio.seek_forward(-5.0) }, "Seek backward in audio stream"]
bindkey "audio space", :audio_stop
bindkey "audio q || audio esc", "vma.kbd.to_previous_mode"
end # module Vimamsa
