

def e_move_forward_char
  buf.move(FORWARD_CHAR)
end

def e_move_backward_char
  buf.move(BACKWARD_CHAR)
end

def history_switch_backwards
  bufs.history_switch_backwards
end

def history_switch_forwards
  bufs.history_switch_forwards
end

def jump_to_next_edit
  buf.jump_to_next_edit
end

def is_command_mode()
  return 1 if $kbd.mode_root_state.to_s() == "C"
  return 0
end

def is_visual_mode()
  return 1 if $kbd.mode_root_state.to_s() == "V"
  return 0
end

reg_act(:easy_jump, proc { easy_jump(:visible_area) }, "Easy jump")
bindkey "VC s", :easy_jump

reg_act(:savedebug, "savedebug", "Save debug info")

# reg_act(:file_finder, "gui_file_finder", "Fuzzy file finder")

reg_act(:open_file_dialog, "open_file_dialog", "Open file")
reg_act(:create_new_file, "create_new_file", "Create new file")
reg_act(:backup_all_buffers, "backup_all_buffers", "Backup all buffers")
reg_act(:invoke_ack_search, "invoke_ack_search", "Invoke ack search")
reg_act(:e_move_forward_char, "e_move_forward_char", "")
reg_act(:e_move_backward_char, "e_move_backward_char", "")
reg_act(:history_switch_backwards, "history_switch_backwards", "")
reg_act(:history_switch_forwards, "history_switch_forwards", "")
reg_act(:center_on_current_line, "center_on_current_line", "")

reg_act(:center_on_current_line, "center_on_current_line", "")

# a = Action.new(:transform_upcase, "Transform selection upcase", proc{ buf.transform_selection(:upcase)  } , [:selection]) 

reg_act(:run_last_macro, proc { $macro.run_last_macro }, "Run last recorded or executed macro")
bindkey ["VCB M","B m"], :run_last_macro

bindkey "VC , m f", [:find_macro_gui, proc{$macro.find_macro_gui}, "Find named macro"]
bindkey "C , m n", [:gui_name_macro, proc{$macro.gui_name_macro}, "Name last macro"]


reg_act(:jump_to_next_edit, "jump_to_next_edit", "")
reg_act(:jump_to_last_edit, proc { buf.jump_to_last_edit }, "")


reg_act(:jump_to_random, proc { buf.jump_to_random_pos }, "")
bindkey "C , j r", :jump_to_random

reg_act(:insert_new_line, proc { buf.insert_new_line()}, "")
bindkey "I return", :insert_new_line

reg_act(:show_key_bindings, proc { show_key_bindings }, "Show key bindings")
bindkey "C , ; s k", :show_key_bindings #TODO: better binding

reg_act(:put_file_path_to_clipboard, proc { buf.put_file_path_to_clipboard }, "Put file path of current file to clipboard")
bindkey "C , , c b", :put_file_path_to_clipboard #TODO: better binding or remove?

# reg_act(:encrypt_file, proc{buf.set_encrypted},"Set current file to encrypt on save")
reg_act(:encrypt_file, proc { encrypt_cur_buffer }, "Set current file to encrypt on save")
bindkey "C , , e", :encrypt_file #TODO: better binding

reg_act(:set_unencrypted, proc { buf.set_unencrypted }, "Set current file to save unencrypted")
bindkey "C , ; u", :set_unencrypted #TODO: better binding

reg_act(:close_all_buffers, proc { bufs.close_all_buffers()  }, "Close all buffers")

reg_act(:close_current_buffer, proc { bufs.close_current_buffer(true) }, "Close current buffer")
bindkey "C , c b", :close_current_buffer

reg_act(:comment_selection, proc { buf.comment_selection }, "")
bindkey "V ctrl-c", :comment_selection

reg_act(:delete_char_forward, proc { buf.delete(CURRENT_CHAR_FORWARD) }, "Delete char forward")
bindkey "C x", :delete_char_forward

reg_act(:load_theme, proc { load_theme }, "Load theme")
bindkey "C , , l t", :load_theme

reg_act(:gui_file_finder, proc { vma.FileFinder.start_gui }, "Fuzzy file finder")
bindkey "C , f", :gui_file_finder

reg_act(:gui_file_history_finder, proc { vma.FileHistory.start_gui }, "Fuzzy file history finder")
bindkey "C , h", :gui_file_history_finder


reg_act(:gui_search_replace, proc { gui_search_replace }, "Search and replace")
bindkey "C , r r", :gui_search_replace
bindkey "V , r r", :gui_search_replace

reg_act(:set_style_bold, proc { buf.style_transform(:bold) }, "Set text weight to bold")
bindkey "V , t b", :set_style_bold

reg_act(:set_style_link, proc { buf.style_transform(:link) }, "Set text as link")
bindkey "V , t l", :set_style_link

reg_act(:V_join_lines, proc { vma.buf.convert_selected_text(:joinlines) }, "Join lines")
bindkey "V J", :V_join_lines


reg_act(:clear_formats, proc { buf.style_transform(:clear) }, "Clear style formats")
bindkey "V , t c", :clear_formats

reg_act(:set_line_style_heading, proc { buf.set_line_style(:heading) }, "Set style of current line as heading")
bindkey "C , t h", :set_line_style_heading

reg_act(:set_line_style_h1, proc { buf.set_line_style(:h1) }, "Set cur line as Heading 1")
bindkey "C , t 1", :set_line_style_h1
reg_act(:set_line_style_h2, proc { buf.set_line_style(:h2) }, "Set cur line as Heading 1")
bindkey "C , t 2", :set_line_style_h2
reg_act(:set_line_style_h3, proc { buf.set_line_style(:h3) }, "Set cur line as Heading 1")
bindkey "C , t 3", :set_line_style_h3
reg_act(:set_line_style_h4, proc { buf.set_line_style(:h4) }, "Set cur line as Heading 1")
bindkey "C , t 4", :set_line_style_h4


reg_act(:set_line_style_bold, proc { buf.set_line_style(:bold) }, "Set style of current line as bold")
bindkey "C , t b", :set_line_style_bold

reg_act(:set_line_style_title, proc { buf.set_line_style(:title) }, "Set style of current line as title")
bindkey "C , t t", :set_line_style_title

reg_act(:clear_line_styles, proc { buf.set_line_style(:clear) }, "Clear styles of current line")
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


reg_act :delete_to_word_end, proc { buf.delete2(:to_word_end) }, "Delete to file end"
bindkey  "C d w", :delete_to_word_end

reg_act :delete_to_line_start, proc { buf.delete2(:to_line_start) }, "Delete to line start"
bindkey  "C d 0", :delete_to_line_start


bindkey "C , , f", :file_finder
bindkey "VC h", :e_move_backward_char

bindkey "C , , .", :backup_all_buffers

bindkey "C z ", "$kbd.set_mode(:browse)"
bindkey "B h", :history_switch_backwards
bindkey "B l", :history_switch_forwards
#bindkey 'B z', :center_on_current_line
bindkey "B z", "center_on_current_line();$kbd.set_mode(:command)"

reg_act :exit_browse_mode, proc { bufs.add_current_buf_to_history();$kbd.set_mode(:command)
}, "Exit browse mode"
#TODO: Need to deside which of these is best:
bindkey "B enter || B return || B esc || B j || B ctrl!", :exit_browse_mode

reg_act :page_down, proc {page_down}
reg_act :page_up, proc {page_up}
bindkey "B s", :page_up
bindkey "B d", :page_down
bindkey "B s", :page_up
bindkey "B d", :page_down

reg_act :jump_to_start_of_buffer, proc{buf.jump(START_OF_BUFFER)}, "Jump to start of buffer"
reg_act :jump_to_end_of_buffer, proc{buf.jump(END_OF_BUFFER)}, "Jump to end of buffer"

bindkey "B i", :jump_to_start_of_buffer
bindkey "B o", :jump_to_end_of_buffer

bindkey "B c", :close_current_buffer
bindkey "B ;", "buf.jump_to_last_edit"
bindkey "B q", :jump_to_last_edit
bindkey "B w", :jump_to_next_edit

reg_act(:reset_highlight, proc { buf.reset_highlight }, "")
bindkey "C , , h", "toggle_highlight"
bindkey "C , r h", :reset_highlight
bindkey "C , d", :diff_buffer
bindkey "C , g", :invoke_grep_search
#bindkey 'C , g', proc{invoke_grep_search}

reg_act(:auto_indent_buffer, proc { buf.indent }, "Auto format buffer")
bindkey "C , v", :auto_indent_buffer
bindkey "C , , d", :savedebug
bindkey "C , , u", :update_file_index

bindkey "C , s a", "buf.save_as()"


reg_act(:show_images, proc { hpt_scan_images() }, "Show images inserted with ⟦img:file.png⟧ syntax")

reg_act(:delete_current_file, proc { bufs.delete_current_buffer() }, "Delete current file")


bindkey "C d d", [:delete_line, proc{buf.delete_line}, "Delete current line"]
bindkey "C enter || C return",  [:line_action,proc{buf.handle_line_action()}, "Line action"]
bindkey  "C p" , [:paste_after,proc{buf.paste(AFTER)},""] # TODO: implement as replace for visual mode
bindkey  "V d" , [:delete_selection,proc{buf.delete(SELECTION)},""]

#bindkey 'C z h', :history_switch_backwards
#bindkey 'C z l', :history_switch_forwards




#TODO: Change these evals into  proc{}'s
default_keys = {

  # File handling
  "C ctrl-s" => "buf.save",
  "C W" => "buf.save",

  # Buffer handling
  "C B" => "bufs.switch",
  "C tab" => "bufs.switch_to_last_buf",
  #    'C , s'=> 'gui_select_buffer',
  "C , r v b" => "buf.revert",
  "C , c b" => "bufs.close_current_buffer",
  #"C , b" => '$kbd.set_mode("S");gui_select_buffer',
  "C , n b" => "create_new_file()",
  "C , ." => "buf.backup()",
  # "C , , ." => "backup_all_buffers()",
  "VC , , s" => "search_actions()",


  # MOVING
  #    'VC h' => 'buf.move(BACKWARD_CHAR)',
  "VC l" => "buf.move(FORWARD_CHAR)",
  "VC j" => "buf.move(FORWARD_LINE)",
  "VC k" => "buf.move(BACKWARD_LINE)",

  "VC pagedown" => "page_down",
  "VC pageup" => "page_up",

  "VCI left" => "buf.move(BACKWARD_CHAR)",
  "VCI right" => "buf.move(FORWARD_CHAR)",
  "VCI down" => "buf.move(FORWARD_LINE)",
  "VCI up" => "buf.move(BACKWARD_LINE)",

  "VC w" => "buf.jump_word(FORWARD,WORD_START)",
  "VC b" => "buf.jump_word(BACKWARD,WORD_START)",
  "VC e" => "buf.jump_word(FORWARD,WORD_END)",
  #    'C '=> 'buf.jump_word(BACKWARD,END)',#TODO
  "VC f <char>" => "buf.jump_to_next_instance_of_char(<char>)",
  "VC F <char>" => "buf.jump_to_next_instance_of_char(<char>,BACKWARD)",
  "VC /[1-9]/" => "set_next_command_count(<char>)",
  #    'VC number=/[0-9]/+ g'=> 'jump_to_line(<number>)',
  #    'VC X=/[0-9]/+ * Y=/[0-9]/+ '=> 'x_times_y(<X>,<Y>)',
  "VC ^" => "buf.jump(BEGINNING_OF_LINE)",
  "VC G($next_command_count!=nil)" => "buf.jump_to_line()",
  "VC 0($next_command_count!=nil)" => "set_next_command_count(<char>)",
  "VC 0($next_command_count==nil)" => "buf.jump(BEGINNING_OF_LINE)",
  # 'C 0'=> 'buf.jump(BEGINNING_OF_LINE)',
  "VC g g" => "buf.jump(START_OF_BUFFER)",
  "VC g ;" => "buf.jump_to_last_edit",
  "VC G" => "buf.jump(END_OF_BUFFER)",
  #    'VC z z' => 'center_on_current_line',
  "VC *" => "buf.jump_to_next_instance_of_word",

  # MINIBUFFER bindings
  "VC /" => "invoke_search",
  # 'VC :' => 'invoke_command', #TODO
  "C , e" => "invoke_command", # Currently eval
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
  "C , c s" => "bufs.close_scrap_buffers",
  "C , d b" => "debug_print_buffer",
  "C , d c" => "debug_dump_clipboard",
  "C , d d" => "debug_dump_deltas",
  "VC O" => "buf.jump(END_OF_LINE)",
  "VC $" => "buf.jump(END_OF_LINE)",

  "C o" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");$kbd.set_mode(:insert)',
  "C X" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");',
  "C A" => "buf.jump(END_OF_LINE);$kbd.set_mode(:insert)",
  "C I" => "buf.jump(FIRST_NON_WHITESPACE);$kbd.set_mode(:insert)",
  "C a" => "buf.move(FORWARD_CHAR);$kbd.set_mode(:insert)",
  "C J" => "buf.join_lines()",
  "C u" => "buf.undo()",

  "C ^" => "buf.jump(BEGINNING_OF_LINE)",
  "C /[1-9]/" => "set_next_command_count(<char>)",

  # Command mode only:
  "C ctrl-r" => "buf.redo()", # TODO:???
  "C R" => "buf.redo()",
  "C v" => "buf.start_visual_mode",
  "C P" => "buf.paste(BEFORE)", # TODO: implement as replace for visual mode
  "C space <char>" => "buf.insert_txt(<char>)",
  "C y y" => "buf.copy_line",
  "C y O" => "buf.copy(:to_line_end)",
  "C y 0" => "buf.copy(:to_line_start)",
  "C y e" => "buf.copy(:to_word_end)", # TODO
  #### Deleting
  "C x" => "buf.delete(CURRENT_CHAR_FORWARD)",
  # 'C d k'=> 'delete_line(BACKWARD)', #TODO
  # 'C d j'=> 'delete_line(FORWARD)', #TODO
  # 'C d d'=> 'buf.delete_cur_line',
  "C d e" => "buf.delete2(:to_word_end)",
  "C d O" => "buf.delete2(:to_line_end)",
  "C d $" => "buf.delete2(:to_line_end)",
  #    'C d e'=> 'buf.delete_to_next_word_end',
  "C d <num> e" => "delete_next_word",
  "C r <char>" => "buf.replace_with_char(<char>)", # TODO
  "C , l b" => "load_buffer_list",
  "C , l l" => "save_buffer_list",
  "C , r <char>" => "set_register(<char>)", # TODO
  "C , p <char>" => "buf.paste(BEFORE,<char>)", # TODO

  "C ctrl-c" => "buf.comment_line()",
  "C ctrl-x" => "buf.comment_line(:uncomment)",

  # 'C 0($next_command_count==nil)'=> 'jump_to_beginning_of_line',

  # Visual mode only:
  "V esc" => "buf.end_visual_mode",
  "V ctrl!" => "buf.end_visual_mode",
  "V y" => "buf.copy_active_selection",
  "V g U" => "buf.transform_selection(:upcase)",
  "V g u" => "buf.transform_selection(:downcase)",
  "V g c" => "buf.transform_selection(:capitalize)",
  "V g s" => "buf.transform_selection(:swapcase)",
  "V g r" => "buf.transform_selection(:reverse)",

  "V x" => "buf.delete(SELECTION)",
  # "V ctrl-c" => "buf.comment_selection",
  "V ctrl-x" => "buf.comment_selection(:uncomment)",

  "CI ctrl-v" => "buf.paste(BEFORE)",
  "CI backspace" => "buf.delete(BACKWARD_CHAR)",

  # Marks
  "CV m <char>" => "buf.mark_current_position(<char>)",
  'CV \' <char>' => "buf.jump_to_mark(<char>)",
  # "CV ''" =>'jump_to_mark(NEXT_MARK)', #TODO

  "C i" => "$kbd.set_mode(:insert)",
  "C ctrl!" => "$kbd.set_mode(:insert)",

  # Macros
  # (experimental, may not work correctly)
  # "C q a" => '$macro.start_recording("a")',
  "VC q <char>" => '$macro.start_recording(<char>)',
  "VC q($macro.is_recording==true) " => "$macro.end_recording", # TODO
  # 'C q'=> '$macro.end_recording', #TODO
  "C q v" => "$macro.end_recording",
  # 'C v'=> '$macro.end_recording',
  # "C M" => '$macro.run_last_macro',
  "C @ <char>" => '$macro.run_macro(<char>)',
  "C , m S" => '$macro.save_macro("a")',
  "C , m s" => '$macro.save',
  "C , t r" => "run_tests()",

  "C ." => "repeat_last_action", # TODO
  "VC ;" => "repeat_last_find",
  "CV Q" => "_quit",
  "CV ctrl-q" => "_quit",
  "CV , R" => "restart_application",
  "I ctrl!" => "$kbd.set_mode(:command)",
  "C shift!" => "buf.save",
  "I <char>" => "buf.insert_txt(<char>)",
  "I esc" => "$kbd.set_mode(:command)",

  "I ctrl-d" => "buf.delete2(:to_word_end)",

  # INSERT MODE: Moving
  "I ctrl-a" => "buf.jump(BEGINNING_OF_LINE)",
  "I ctrl-b" => "buf.move(BACKWARD_CHAR)",
  "I ctrl-f" => "buf.move(FORWARD_CHAR)",
  "I ctrl-n" => "buf.move(FORWARD_LINE)",
  "I ctrl-p" => "buf.move(BACKWARD_LINE)",
  "I ctrl-e" => "buf.jump(END_OF_LINE)", # context: mode:I, buttons down: {C}
  "I alt-f" => "buf.jump_word(FORWARD,WORD_START)",
  "I alt-b" => "buf.jump_word(BACKWARD,WORD_START)",

  "I tab" => 'buf.insert_txt("  ")',
  "I space" => 'buf.insert_txt(" ")',
#  "I return" => 'buf.insert_new_line()',
}

default_keys.each { |key, value|
  bindkey(key, value)
}
