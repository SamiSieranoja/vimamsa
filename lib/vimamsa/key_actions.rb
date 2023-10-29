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
  return true if $kbd.mode_root_state.to_s() == "C"
  return false
end

def is_visual_mode()
  return 1 if $kbd.mode_root_state.to_s() == "V"
  return 0
end

reg_act(:lsp_debug, proc { vma.buf.lsp_get_def }, "LSP get definition")
reg_act(:lsp_jump_to_definition, proc { vma.buf.lsp_jump_to_def }, "LSP jump to definition")

reg_act(:enable_debug, proc { $debug = true }, "Enable debug")
reg_act(:disable_debug, proc { $debug = false }, "Disable debug")

reg_act(:easy_jump, proc { EasyJump.start }, "Easy jump")
reg_act(:savedebug, "savedebug", "Save debug info", { :group => :debug })
reg_act(:open_file_dialog, "open_file_dialog", "Open file", { :group => :file })
reg_act(:create_new_file, "create_new_file", "Create new file", { :group => :file })
reg_act(:backup_all_buffers, proc { backup_all_buffers }, "Backup all buffers", { :group => :file })
reg_act(:e_move_forward_char, "e_move_forward_char", "", { :group => [:move, :basic] })
reg_act(:e_move_backward_char, "e_move_backward_char", "", { :group => [:move, :basic] })
reg_act(:history_switch_backwards, "history_switch_backwards", "", { :group => :file })
reg_act(:history_switch_forwards, "history_switch_forwards", "", { :group => :file })
reg_act(:center_on_current_line, "center_on_current_line", "", { :group => :view })
reg_act(:run_last_macro, proc { $macro.run_last_macro }, "Run last recorded or executed macro", { :group => :macro })
reg_act(:jump_to_next_edit, "jump_to_next_edit", "")
reg_act(:jump_to_last_edit, proc { buf.jump_to_last_edit }, "")
reg_act(:jump_to_random, proc { buf.jump_to_random_pos }, "")
reg_act(:insert_new_line, proc { buf.insert_new_line() }, "")
reg_act(:show_key_bindings, proc { show_key_bindings }, "Show key bindings")
reg_act(:put_file_path_to_clipboard, proc { buf.put_file_path_to_clipboard }, "Put file path of current file to clipboard")
reg_act(:put_file_ref_to_clipboard, proc { buf.put_file_ref_to_clipboard }, "Put file ref of current file to clipboard")

# reg_act(:encrypt_file, proc{buf.set_encrypted},"Set current file to encrypt on save")
reg_act(:encrypt_file, proc { encrypt_cur_buffer }, "Set current file to encrypt on save")
reg_act(:set_unencrypted, proc { buf.set_unencrypted }, "Set current file to save unencrypted")
reg_act(:set_executable, proc { buf.set_executable }, "Set current file permissions to executable")
reg_act(:close_all_buffers, proc { bufs.close_all_buffers() }, "Close all buffers")
reg_act(:close_current_buffer, proc { bufs.close_current_buffer(true) }, "Close current buffer")
reg_act(:comment_selection, proc { buf.comment_selection }, "")
reg_act(:delete_char_forward, proc { buf.delete(CURRENT_CHAR_FORWARD) }, "Delete char forward", { :group => [:edit, :basic] })
reg_act(:load_theme, proc { load_theme }, "Load theme")
reg_act(:gui_file_finder, proc { vma.FileFinder.start_gui }, "Fuzzy file finder")
reg_act(:gui_file_history_finder, proc { vma.FileHistory.start_gui }, "Fuzzy file history finder")
reg_act(:gui_search_replace, proc { gui_search_replace }, "Search and replace")
reg_act(:set_style_bold, proc { buf.style_transform(:bold) }, "Set text weight to bold")
reg_act(:set_style_link, proc { buf.style_transform(:link) }, "Set text as link")
reg_act(:V_join_lines, proc { vma.buf.convert_selected_text(:joinlines) }, "Join lines")
reg_act(:clear_formats, proc { buf.style_transform(:clear) }, "Clear style formats")
reg_act(:set_line_style_heading, proc { buf.set_line_style(:heading) }, "Set style of current line as heading")
reg_act(:set_line_style_h1, proc { buf.set_line_style(:h1) }, "Set cur line as Heading 1")
reg_act(:set_line_style_h2, proc { buf.set_line_style(:h2) }, "Set cur line as Heading 1")
reg_act(:set_line_style_h3, proc { buf.set_line_style(:h3) }, "Set cur line as Heading 1")
reg_act(:set_line_style_h4, proc { buf.set_line_style(:h4) }, "Set cur line as Heading 1")
reg_act(:set_line_style_bold, proc { buf.set_line_style(:bold) }, "Set style of current line as bold")
reg_act(:set_line_style_title, proc { buf.set_line_style(:title) }, "Set style of current line as title")
reg_act(:clear_line_styles, proc { buf.set_line_style(:clear) }, "Clear styles of current line")
reg_act(:gui_select_buffer, proc { $kbd.set_mode("S"); gui_select_buffer }, "Select buffer")
reg_act :open_file_dialog, "open_file_dialog", "Open file"
reg_act :minibuffer_end, proc { minibuffer_end }
reg_act(:invoke_replace, "invoke_replace", "")
reg_act(:diff_buffer, "diff_buffer", "")
# reg_act(:invoke_grep_search, proc{invoke_grep_search}, "")
reg_act(:invoke_grep_search, proc { gui_grep }, "Grep current buffer")
reg_act(:ack_search, proc { gui_ack }, "") #invoke_ack_search
reg_act :update_file_index, proc { FileFinder.update_index }, "Update file index"
reg_act :delete_to_word_end, proc { buf.delete2(:to_word_end) }, "Delete to file end", { :group => [:edit, :basic] }
reg_act :delete_to_next_word_start, proc { buf.delete2(:to_next_word) }, "Delete to start of next word", { :group => [:edit, :basic] }
reg_act :delete_to_line_start, proc { buf.delete2(:to_line_start) }, "Delete to line start", { :group => [:edit, :basic] }
reg_act :start_browse_mode, proc { $kbd.set_mode(:browse); $kbd.set_default_mode(:browse) }, "Start browse mode"
reg_act :exit_browse_mode, proc {
  bufs.add_current_buf_to_history(); $kbd.set_mode(:command); $kbd.set_default_mode(:command)
}, "Exit browse mode"

reg_act :page_down, proc { page_down }, "Page down", :group => [:move, :basic]
reg_act :page_up, proc { page_up }, "Page up", :group => [:move, :basic]
reg_act :jump_to_start_of_buffer, proc { buf.jump(START_OF_BUFFER) }, "Jump to start of buffer"
reg_act :jump_to_end_of_buffer, proc { buf.jump(END_OF_BUFFER) }, "Jump to end of buffer"
reg_act(:auto_indent_buffer, proc { buf.indent }, "Auto format buffer")
reg_act(:execute_current_line_in_terminal, proc { buf.execute_current_line_in_terminal }, "Execute current line in terminal")
reg_act(:execute_current_line_in_terminal_autoclose, proc { buf.execute_current_line_in_terminal(true) }, "Execute current line in terminal. Close after execution.")
reg_act(:show_images, proc { hpt_scan_images() }, "Show images inserted with ⟦img:file.png⟧ syntax")
reg_act(:delete_current_file, proc { bufs.delete_current_buffer() }, "Delete current file")


reg_act(:audio_stop, proc { Audio.stop }, "Stop audio playback")


act_list = {
  # File handling
  :buf_save => { :proc => proc { buf.save },
                 :desc => "Save buffer", :group => :file },

  :buf_save_as => { :proc => proc { buf.save_as },
                    :desc => "Save file as", :group => :file },
  :buf_new => { :proc => proc { create_new_file() }, :desc => "Create a new file", :group => :file },
  :buf_revert => { :proc => proc { buf.revert },
                   :desc => "Reload file from disk", :group => :file },
  :buf_backup => { :proc => proc { buf.backup() }, :desc => "Backup current file", :group => :file },

  :edit_redo => { :proc => proc { buf.redo },
                  :desc => "Redo edit", :group => :edit },

  :edit_undo => { :proc => proc { buf.undo },
                  :desc => "Undo edit", :group => :edit },

  :find_in_buffer => { :proc => proc { invoke_search },
                       :desc => "Find", :group => :edit },

  :selection_upcase => { :proc => proc { buf.transform_selection(:upcase) },
                         :desc => "Transform text: upcase", :group => :edit },

  :selection_downcase => { :proc => proc { buf.transform_selection(:downcase) },
                           :desc => "Transform text: downcase", :group => :edit },

  :selection_capitalize => { :proc => proc { buf.transform_selection(:capitalize) },
                             :desc => "Transform text: capitalize", :group => :edit },

  :selection_swapcase => { :proc => proc { buf.transform_selection(:swapcase) },
                           :desc => "Transform text: swapcase", :group => :edit },

  :selection_reverse => { :proc => proc { buf.transform_selection(:reverse) },
                          :desc => "Transform text: reverse", :group => :edit },

  :forward_line => { :proc => proc { buf.move(FORWARD_LINE) },
                     :desc => "Move one line forward", :group => [:move, :basic] },

  :backward_line => { :proc => proc { buf.move(BACKWARD_LINE) },
                      :desc => "Move one line backward", :group => [:move, :basic] },

  # { :proc => proc {  },
  # :desc => "", :group => : },

  :search_actions => { :proc => proc { search_actions },
                       :desc => "Search actions", :group => :search },

  :toggle_active_window => { :proc => proc { vma.gui.toggle_active_window },
                             :desc => "Toggle active window", :group => :search },

  :toggle_two_column => { :proc => proc { vma.gui.set_two_column },
                          :desc => "Set two column mode", :group => :search },

  :content_search => { :proc => proc { FileContentSearch.start_gui },
                       :desc => "Search content of files", :group => :search },

  :quit => { :proc => proc { _quit },
             :desc => "Quit", :group => :app },

}

for k, v in act_list
  reg_act(k, v[:proc], v[:desc])
end

act_list_todo = {

  # Buffer handling
  # : =>  {proc => proc {bufs.switch}, :desc => "", :group => :},
  :buf_switch_to_last => { :proc => proc { bufs.switch_to_last_buf },
                           :desc => "", :group => :file },
  #    'C , s'=> 'gui_select_buffer',
  :buf_revert => { :proc => proc { buf.revert },
                   :desc => "Reload/revert file from disk", :group => :file },
  :buf_close => { :proc => proc { bufs.close_current_buffer },
                  :desc => "Close current file", :group => :file },
  #"C , b" => '$kbd.set_mode("S");gui_select_buffer',

  # MOVING
  #    'VC h' => 'buf.move(BACKWARD_CHAR)',
  :m_forward_char => { :proc => proc { buf.move(FORWARD_CHAR) },
                       :desc => "Move cursor one char forward",
                       :group => :move },
  # "VC j" => "buf.move(FORWARD_LINE)",
  # "VC k" => "buf.move(BACKWARD_LINE)",

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
  "VC f space" => "buf.jump_to_next_instance_of_char(' ')",
  "VC F space" => "buf.jump_to_next_instance_of_char(' ',BACKWARD)",

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
  "C R" => "buf.redo()",
  "C v" => "buf.start_visual_mode",
  "C P" => "buf.paste(BEFORE)", # TODO: implement as replace for visual mode
  "C space <char>" => "buf.insert_txt(<char>)",
  "C space space" => "buf.insert_txt(' ')",
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
  "V y" => "buf.copy_active_selection(:foo)",
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
  "VC q <char>" => "$macro.start_recording(<char>)",
  "VC q($macro.is_recording==true) " => "$macro.end_recording", # TODO
  # 'C q'=> '$macro.end_recording', #TODO
  "C q v" => "$macro.end_recording",
  # 'C v'=> '$macro.end_recording',
  # "C M" => '$macro.run_last_macro',
  "C @ <char>" => "$macro.run_macro(<char>)",
  "C , m S" => '$macro.save_macro("a")',
  "C , m s" => "$macro.save",
  "C , t r" => "run_tests()",

  "C ." => "repeat_last_action", # TODO
  "VC ;" => "repeat_last_find",
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

  "I tab" => 'buf.insert_txt("	")',
  "I space" => 'buf.insert_txt(" ")',
#  "I return" => 'buf.insert_new_line()',
}

# default_keys.each { |key, value|
# bindkey(key, value)
# }
