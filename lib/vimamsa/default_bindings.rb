

def e_move_forward_char
  $buffer.move(FORWARD_CHAR)
end

def e_move_backward_char
  $buffer.move(BACKWARD_CHAR)
end

def history_switch_backwards
  $buffers.history_switch_backwards
end

def history_switch_forwards
  $buffers.history_switch_forwards
end

def jump_to_next_edit
  $buffer.jump_to_next_edit
end

def is_command_mode()
  return 1 if $kbd.mode_root_state.to_s() == "C"
  return 0
end

def is_visual_mode()
  return 1 if $kbd.mode_root_state.to_s() == "V"
  return 0
end

reg_act(:savedebug, "savedebug", "Save debug info")

reg_act(:file_finder, "gui_file_finder", "Fuzzy file finder")
reg_act(:open_file_dialog, "open_file_dialog", "Open file")
reg_act(:create_new_file, "create_new_file", "Create new file")
reg_act(:backup_all_buffers, "backup_all_buffers", "Backup all buffers")
reg_act(:invoke_ack_search, "invoke_ack_search", "Invoke ack search")
reg_act(:e_move_forward_char, "e_move_forward_char", "")
reg_act(:e_move_backward_char, "e_move_backward_char", "")
reg_act(:history_switch_backwards, "history_switch_backwards", "")
reg_act(:history_switch_forwards, "history_switch_forwards", "")
reg_act(:center_on_current_line, "center_on_current_line", "")

reg_act(:jump_to_next_edit, "jump_to_next_edit", "")
reg_act(:jump_to_last_edit, proc { $buffer.jump_to_last_edit }, "")


reg_act(:show_key_bindings, proc { show_key_bindings }, "Show key bindings")
bindkey "C , ; s k", :show_key_bindings #TODO: better binding

reg_act(:put_file_path_to_clipboard, proc { $buffer.put_file_path_to_clipboard }, "Put file path of current file to clipboard")
bindkey "C , , c b", :put_file_path_to_clipboard #TODO: better binding or remove?

# reg_act(:encrypt_file, proc{$buffer.set_encrypted},"Set current file to encrypt on save")
reg_act(:encrypt_file, proc { encrypt_cur_buffer }, "Set current file to encrypt on save")
bindkey "C , , e", :encrypt_file #TODO: better binding

reg_act(:set_unencrypted, proc { $buffer.set_unencrypted }, "Set current file to save unencrypted")
bindkey "C , ; u", :set_unencrypted #TODO: better binding

reg_act(:close_current_buffer, proc { $buffers.close_current_buffer(true) }, "Close current buffer")
bindkey "C , c b", :close_current_buffer

reg_act(:comment_selection, proc { $buffer.comment_selection }, "")
bindkey "V ctrl-c", :comment_selection

reg_act(:delete_char_forward, proc { $buffer.delete(CURRENT_CHAR_FORWARD) }, "Delete char forward")
bindkey "C x", :delete_char_forward

reg_act(:load_theme, proc { load_theme }, "Load theme")
bindkey "C , , l t", :load_theme

reg_act(:gui_file_finder, proc { gui_file_finder }, "Fuzzy file finder")
bindkey "C , f", :gui_file_finder

reg_act(:gui_search_replace, proc { gui_search_replace }, "Search and replace")
bindkey "C , r r", :gui_search_replace
bindkey "V , r r", :gui_search_replace

reg_act(:set_style_bold, proc { $buffer.style_transform(:bold) }, "Set text weight to bold")
bindkey "V , t b", :set_style_bold

reg_act(:clear_formats, proc { $buffer.style_transform(:clear) }, "Clear style formats")
bindkey "V , t c", :clear_formats

reg_act(:set_line_style_heading, proc { $buffer.set_line_style(:heading) }, "Set style of current line as heading")
bindkey "C , t h", :set_line_style_heading

reg_act(:set_line_style_bold, proc { $buffer.set_line_style(:bold) }, "Set style of current line as bold")
bindkey "C , t b", :set_line_style_bold

reg_act(:set_line_style_title, proc { $buffer.set_line_style(:title) }, "Set style of current line as title")
bindkey "C , t t", :set_line_style_title

reg_act(:clear_line_styles, proc { $buffer.set_line_style(:clear) }, "Clear styles of current line")
bindkey "C , t c", :clear_line_styles

reg_act(:gui_select_buffer, proc { $kbd.set_mode("S"); gui_select_buffer }, "Select buffer")
bindkey "C , b", :gui_select_buffer

reg_act :open_file_dialog, "open_file_dialog", "Open file"
bindkey "C , f o", :open_file_dialog
bindkey "CI ctrl-o", :open_file_dialog

reg_act :minibuffer_end, proc { minibuffer_end }
bindkey "M return", :minibuffer_end

reg_act(:invoke_replace, "invoke_replace", "")
reg_act(:diff_buffer, "diff_buffer", "")

# reg_act(:invoke_grep_search, proc{invoke_grep_search}, "")
reg_act(:invoke_grep_search, proc { gui_grep }, "Grep current buffer")

reg_act(:ack_search, proc { gui_ack }, "") #invoke_ack_search
bindkey "C , a", :ack_search

reg_act :update_file_index, proc { update_file_index }, "Update file index"


reg_act :delete_to_word_end, proc { $buffer.delete2(:to_word_end) }, "Delete to file end"
bindkey  "C d w", :delete_to_word_end

reg_act :delete_to_line_start, proc { $buffer.delete2(:to_line_start) }, "Delete to line start"
bindkey  "C d 0", :delete_to_line_start


bindkey "C , , f", :file_finder
bindkey "VC h", :e_move_backward_char

bindkey "C , , .", :backup_all_buffers

bindkey "C z ", "$kbd.set_mode(:browse)"
bindkey "B h", :history_switch_backwards
bindkey "B l", :history_switch_forwards
#bindkey 'B z', :center_on_current_line
bindkey "B z", "center_on_current_line();$kbd.set_mode(:command)"
bindkey "B j", "$buffers.add_current_buf_to_history();$kbd.set_mode(:command)"
bindkey "B esc", "$buffers.add_current_buf_to_history();$kbd.set_mode(:command)"
bindkey "B return", "$buffers.add_current_buf_to_history();$kbd.set_mode(:command)"
bindkey "B enter", "$buffers.add_current_buf_to_history();$kbd.set_mode(:command)"
bindkey "B c", :close_current_buffer

bindkey "B ;", "$buffer.jump_to_last_edit"
bindkey "B q", :jump_to_last_edit
bindkey "B w", :jump_to_next_edit

reg_act(:reset_highlight, proc { $buffer.reset_highlight }, "")
bindkey "C , , h", "toggle_highlight"
bindkey "C , r h", :reset_highlight
bindkey "C , d", :diff_buffer
bindkey "C , g", :invoke_grep_search
#bindkey 'C , g', proc{invoke_grep_search}

reg_act(:auto_indent_buffer, proc { $buffer.indent }, "Auto format buffer")
bindkey "C , v", :auto_indent_buffer
bindkey "C , , d", :savedebug
bindkey "C , , u", :update_file_index

bindkey "C , s a", "$buffer.save_as()"

#bindkey 'C z h', :history_switch_backwards
#bindkey 'C z l', :history_switch_forwards

#TODO: Change these evals into  proc{}'s
default_keys = {

  # File handling
  "C ctrl-s" => "$buffer.save",
  "C W" => "$buffer.save",

  # Buffer handling
  "C B" => "$buffers.switch",
  "C tab" => "$buffers.switch_to_last_buf",
  #    'C , s'=> 'gui_select_buffer',
  "C , r v b" => "$buffer.revert",
  "C , c b" => "$buffers.close_current_buffer",
  #"C , b" => '$kbd.set_mode("S");gui_select_buffer',
  "C , n b" => "create_new_file()",
  "C , ." => "$buffer.backup()",
  # "C , , ." => "backup_all_buffers()",
  "VC , , s" => "search_actions()",

  "C enter" => "$buffer.get_cur_nonwhitespace_word()",
  "C return" => "$buffer.get_cur_nonwhitespace_word()",

  # MOVING
  #    'VC h' => '$buffer.move(BACKWARD_CHAR)',
  "VC l" => "$buffer.move(FORWARD_CHAR)",
  "VC j" => "$buffer.move(FORWARD_LINE)",
  "VC k" => "$buffer.move(BACKWARD_LINE)",

  "VC pagedown" => "page_down",
  "VC pageup" => "page_up",

  "VCI left" => "$buffer.move(BACKWARD_CHAR)",
  "VCI right" => "$buffer.move(FORWARD_CHAR)",
  "VCI down" => "$buffer.move(FORWARD_LINE)",
  "VCI up" => "$buffer.move(BACKWARD_LINE)",

  "VC w" => "$buffer.jump_word(FORWARD,WORD_START)",
  "VC b" => "$buffer.jump_word(BACKWARD,WORD_START)",
  "VC e" => "$buffer.jump_word(FORWARD,WORD_END)",
  #    'C '=> '$buffer.jump_word(BACKWARD,END)',#TODO
  "VC f <char>" => "$buffer.jump_to_next_instance_of_char(<char>)",
  "VC F <char>" => "$buffer.jump_to_next_instance_of_char(<char>,BACKWARD)",
  "VC /[1-9]/" => "set_next_command_count(<char>)",
  #    'VC number=/[0-9]/+ g'=> 'jump_to_line(<number>)',
  #    'VC X=/[0-9]/+ * Y=/[0-9]/+ '=> 'x_times_y(<X>,<Y>)',
  "VC ^" => "$buffer.jump(BEGINNING_OF_LINE)",
  "VC G($next_command_count!=nil)" => "$buffer.jump_to_line()",
  "VC 0($next_command_count!=nil)" => "set_next_command_count(<char>)",
  "VC 0($next_command_count==nil)" => "$buffer.jump(BEGINNING_OF_LINE)",
  # 'C 0'=> '$buffer.jump(BEGINNING_OF_LINE)',
  "VC g g" => "$buffer.jump(START_OF_BUFFER)",
  "VC g ;" => "$buffer.jump_to_last_edit",
  "VC G" => "$buffer.jump(END_OF_BUFFER)",
  #    'VC z z' => 'center_on_current_line',
  "VC *" => "$buffer.jump_to_next_instance_of_word",
  "C s" => "easy_jump(:visible_area)",

  # MINIBUFFER bindings
  "VC /" => "invoke_search",
  # 'VC :' => 'invoke_command', #TODO
  "VC , e" => "invoke_command", # Currently eval
  "M enter" => "minibuffer_end()",
  # "M return" => "minibuffer_end()",
  "M esc" => "minibuffer_cancel()",
  "M backspace" => "minibuffer_delete()",
  "M <char>" => "minibuffer_new_char(<char>)",
  "M ctrl-v" => "$minibuffer.paste(BEFORE)",

  # READCHAR bindings

  "R <char>" => "readchar_new_char(<char>)",

  "C n" => "$search.jump_to_next()",
  "C N" => "$search.jump_to_previous()",

  # Debug
  "C , d r p" => "start_ripl",
  "C , D" => "debug_print_buffer",
  "C , c s" => "$buffers.close_scrap_buffers",
  "C , d b" => "debug_print_buffer",
  "C , d c" => "debug_dump_clipboard",
  "C , d d" => "debug_dump_deltas",
  "VC O" => "$buffer.jump(END_OF_LINE)",
  "VC $" => "$buffer.jump(END_OF_LINE)",

  "C o" => '$buffer.jump(END_OF_LINE);$buffer.insert_txt("\n");$kbd.set_mode(:insert)',
  "C X" => '$buffer.jump(END_OF_LINE);$buffer.insert_txt("\n");',
  "C A" => "$buffer.jump(END_OF_LINE);$kbd.set_mode(:insert)",
  "C I" => "$buffer.jump(FIRST_NON_WHITESPACE);$kbd.set_mode(:insert)",
  "C a" => "$buffer.move(FORWARD_CHAR);$kbd.set_mode(:insert)",
  "C J" => "$buffer.join_lines()",
  "C u" => "$buffer.undo()",

  "C ^" => "$buffer.jump(BEGINNING_OF_LINE)",
  "C /[1-9]/" => "set_next_command_count(<char>)",

  # Command mode only:
  "C ctrl-r" => "$buffer.redo()", # TODO:???
  "C R" => "$buffer.redo()",
  "C v" => "$buffer.start_visual_mode",
  "C p" => "$buffer.paste(AFTER)", # TODO: implement as replace for visual mode
  "C P" => "$buffer.paste(BEFORE)", # TODO: implement as replace for visual mode
  "C space <char>" => "$buffer.insert_txt(<char>)",
  "C y y" => "$buffer.copy_line",
  "C y O" => "$buffer.copy(:to_line_end)",
  "C y 0" => "$buffer.copy(:to_line_start)",
  "C y e" => "$buffer.copy(:to_word_end)", # TODO
  #### Deleting
  "C x" => "$buffer.delete(CURRENT_CHAR_FORWARD)",
  # 'C d k'=> 'delete_line(BACKWARD)', #TODO
  # 'C d j'=> 'delete_line(FORWARD)', #TODO
  # 'C d d'=> '$buffer.delete_cur_line',
  "C d d" => "$buffer.delete_line",
  "C d e" => "$buffer.delete2(:to_word_end)",
  "C d O" => "$buffer.delete2(:to_line_end)",
  "C d $" => "$buffer.delete2(:to_line_end)",
  #    'C d e'=> '$buffer.delete_to_next_word_end',
  "C d <num> e" => "delete_next_word",
  "C r <char>" => "$buffer.replace_with_char(<char>)", # TODO
  "C , l b" => "load_buffer_list",
  "C , l l" => "save_buffer_list",
  "C , r <char>" => "set_register(<char>)", # TODO
  "C , p <char>" => "$buffer.paste(BEFORE,<char>)", # TODO

  "C ctrl-c" => "$buffer.comment_line()",
  "C ctrl-x" => "$buffer.comment_line(:uncomment)",

  # 'C 0($next_command_count==nil)'=> 'jump_to_beginning_of_line',

  # Visual mode only:
  "V esc" => "$buffer.end_visual_mode",
  "V ctrl!" => "$buffer.end_visual_mode",
  "V y" => "$buffer.copy_active_selection",
  "V g U" => "$buffer.transform_selection(:upcase)",
  "V g u" => "$buffer.transform_selection(:downcase)",
  "V g c" => "$buffer.transform_selection(:capitalize)",
  "V g s" => "$buffer.transform_selection(:swapcase)",
  "V g r" => "$buffer.transform_selection(:reverse)",

  "V d" => "$buffer.delete(SELECTION)",
  "V x" => "$buffer.delete(SELECTION)",
  # "V ctrl-c" => "$buffer.comment_selection",
  "V ctrl-x" => "$buffer.comment_selection(:uncomment)",

  "CI ctrl-v" => "$buffer.paste(BEFORE)",
  "CI backspace" => "$buffer.delete(BACKWARD_CHAR)",

  # Marks
  "CV m <char>" => "$buffer.mark_current_position(<char>)",
  'CV \' <char>' => "$buffer.jump_to_mark(<char>)",
  # "CV ''" =>'jump_to_mark(NEXT_MARK)', #TODO

  "C i" => "$kbd.set_mode(:insert)",
  "C ctrl!" => "$kbd.set_mode(:insert)",

  # Macros
  # (experimental, may not work correctly)
  "C q a" => '$macro.start_recording("a")',
  "C q($macro.is_recording==true) " => "$macro.end_recording", # TODO
  # 'C q'=> '$macro.end_recording', #TODO
  "C q v" => "$macro.end_recording",
  # 'C v'=> '$macro.end_recording',
  "C M" => '$macro.run_macro("a")',
  "C , m s" => '$macro.save_macro("a")',
  "C , t r" => "run_tests()",

  "C ." => "repeat_last_action", # TODO
  "C ;" => "repeat_last_find",
  "CV Q" => "_quit",
  "CV ctrl-q" => "_quit",
  "CV , R" => "restart_application",
  "I ctrl!" => "$kbd.set_mode(:command)",
  "C shift!" => "$buffer.save",
  "I <char>" => "$buffer.insert_txt(<char>)",
  "I esc" => "$kbd.set_mode(:command)",

  "I ctrl-d" => "$buffer.delete2(:to_word_end)",

  # INSERT MODE: Moving
  "I ctrl-a" => "$buffer.jump(BEGINNING_OF_LINE)",
  "I ctrl-b" => "$buffer.move(BACKWARD_CHAR)",
  "I ctrl-f" => "$buffer.move(FORWARD_CHAR)",
  "I ctrl-n" => "$buffer.move(FORWARD_LINE)",
  "I ctrl-p" => "$buffer.move(BACKWARD_LINE)",
  "I ctrl-e" => "$buffer.jump(END_OF_LINE)", # context: mode:I, buttons down: {C}
  "I alt-f" => "$buffer.jump_word(FORWARD,WORD_START)",
  "I alt-b" => "$buffer.jump_word(BACKWARD,WORD_START)",

  "I tab" => '$buffer.insert_txt("  ")',
  "I space" => '$buffer.insert_txt(" ")',
  "I return" => '$buffer.insert_txt("\n")',
}

default_keys.each { |key, value|
  bindkey(key, value)
}
