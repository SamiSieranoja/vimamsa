module Vimamsa
# Shared Vim bindings, used by both keymaps (doc/vim_compatibility_plan.md):
#   vim keymap:     bind_vim_bindings            binds the whole table
#   vimlike keymap: bind_vim_bindings(only_free: true) after its own
#                   bindings: binds only entries that don't conflict with
#                   them (vim_binding_status == :missing), so vimlike's own
#                   bindings always win.
# What was added, and every conflict, is listed in the generated
# doc/vimlike_vim_conflicts.md.

# ── composite actions for vim commands not covered by a single action ────────
#TODO: file should be renamed to sort close to  key_actions.rb


def reg_vim_actions
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

  reg_act(:vim_change_selection, proc {
    buf.delete(SELECTION) # ends visual mode itself
    vma.kbd.set_mode(:insert)
  }, "Delete selection and enter insert mode (vim visual c/s)")

  # APPROXIMATION: set_last_command is currently only fed by f/F finds, so this
  # repeats the last find, not the last change like vim's ".".
  reg_act(:vim_repeat_last_action, proc { repeat_last_action() },
          "Repeat last recorded command (approximation of vim .)")
end

# ── the table: section => { keys => action } ─────────────────────────────────
# Same binding syntax as add_keys. Only Vim behavior goes here; the vim
# keymap's own deviations (C tab, C enter, browse mode, ...) stay in
# key_bindings_vim.rb.

VIM_BINDINGS = {
  "vim motion" => {
    "VCX up" => "buf.move(BACKWARD_LINE)",
    "VCX down" => "buf.move(FORWARD_LINE)",
    "VCX right" => "buf.move(FORWARD_CHAR)",
    "VCX left" => "buf.move(BACKWARD_CHAR)",
    "VC h" => "move.char.prev",
    "VC l" => "move.char.next",
    "VC j" => "move.line.next",
    "VC k" => "move.line.prev",
    "C space" => "buf.move(FORWARD_CHAR)",
    "C backspace" => "buf.move(BACKWARD_CHAR)",

    "VC e" => :jump_next_word_end,
    "VC b" => :jump_prev_word_start,
    "VC w" => :jump_next_word_start,

    # NOTE: "G(condition)" must be defined before "G"
    "VC G(vma.kbd.next_command_count!=nil)" => "buf.jump_to_line()",
    "VC G" => :jump_end_of_buffer,
    "VC g g" => :jump_start_of_buffer,
    "VC g ;" => "jump.edit.prev",

    # Counts; "0" is BOL only when no count is pending
    "VC /[1-9]/" => "vma.kbd.set_next_command_count(<char>)",
    "VC 0(vma.kbd.next_command_count!=nil)" => "vma.kbd.set_next_command_count(<char>)",
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
    "C ctrl-o" => "jump.edit.prev",         # approx of vim jumplist back
    "C z z" => :center_on_current_line,

    # Marks
    "CV m <char>" => "buf.mark_current_position(<char>)",
    'CV \' <char>' => "buf.jump_to_mark(<char>)",
    "C ` <char>" => "buf.jump_to_mark(<char>)",
  },

#TODO: should replace all eval actions like "buf.move ... with actual registered actions.
  "vim edit" => {
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
    "C d f <char>" => "buf.delete2(:to_char,<char>)",
    "C d F <char>" => "buf.delete2(:to_char_backward,<char>)",
    "C d f space" => "buf.delete2(:to_char,' ')",
    "C d F space" => "buf.delete2(:to_char_backward,' ')",
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
    "C g U w" => :word_upcase,
    "C g u w" => :word_downcase,
    "C g ~ w" => :word_swapcase,
    "C g U U" => :line_upcase,
    "C g u u" => :line_downcase,
    "C g ~ ~" => :line_swapcase,
    "C ctrl-a" => "buf.increment_current_word", # vim ctrl-a: increment number
    "C ." => :vim_repeat_last_action,

    # Undo / redo
    "C u" => "undo.last",
    "C ctrl-r" => "undo.redo",
  },

  "vim visual" => {
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
  },

  "vim insert" => {
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
  },

  # vim R
  "vim replace" => {
    "C R" => "vma.kbd.set_mode(:replace)",
    "X esc" => "vma.kbd.to_previous_mode",
    "X <char>" => "buf.replace_with_char(<char>);buf.move(FORWARD_CHAR)",
  },

  "vim macros" => {
    # q<char> records, q stops, @<char> runs, @@ repeats
    "VC q <char>" => "vma.kbd.set_mode(:macro);vma.macro.start_recording(<char>)",
    "macro q" => "vma.kbd.to_previous_mode; vma.macro.end_recording",
    "C @ @" => :run_last_macro,
    "C @ <char>" => "vma.macro.run_macro(<char>)",

    # READCHAR mode (argument input for f/F, r, m, ', q, @)
    "R <char>" => "readchar_new_char(<char>)",
  },
}

# Bind VIM_BINDINGS into vma.kbd. With only_free, an entry is bound only if
# vma.kbd has nothing in its way (see vim_binding_status), and binding it
# doesn't change which keys the menus show for an action vimlike already
# binds. Records what was bound as [mode, keys] in vma.kbd.vim_added.
def bind_vim_bindings(only_free: false)
  reg_vim_actions
  kbd = vma.kbd
  added = []
  VIM_BINDINGS.each { |section, h|
    h.each { |key, action|
      if !only_free
        bindkey(key, action, keywords: section)
        next
      end
      act = action.class == Array ? action[0] : action
      key.split("||").each { |k|
        mstr, keydef = k.strip.split(/\s+/, 2)
        modes = mstr.match?(/\A\p{Lu}+\z/) ? mstr.chars : [mstr]
        modes.each { |m|
          keys = keydef.split
          next if vim_binding_status(kbd, m, keys, act)[:status] != :missing
          had = kbd.act_bindings.key?(m) && kbd.act_bindings[m].key?(act)
          prev = had ? kbd.act_bindings[m][act] : nil
          bindkey("#{m} #{keydef}", action, keywords: section)
          kbd.act_bindings[m][act] = prev if had
          added << [m, keys]
        }
      }
    }
  }
  kbd.vim_added = added
  added
end
end # module Vimamsa
