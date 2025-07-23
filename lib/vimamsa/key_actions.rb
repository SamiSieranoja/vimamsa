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
  return true if vma.kbd.mode_root_state.to_s() == "C"
  return false
end

def is_visual_mode()
  return 1 if vma.kbd.mode_root_state.to_s() == "V"
  return 0
end

reg_act(:command_to_buf, proc { command_to_buf }, "Execute command, output to buffer")

reg_act(:lsp_debug, proc { vma.buf.lsp_get_def }, "LSP get definition")
reg_act(:lsp_jump_to_definition, proc { vma.buf.lsp_jump_to_def }, "LSP jump to definition")

reg_act(:eval_buf, proc { vma.buf.eval_whole_buf }, "Eval whole current buffer as ruby code (DANGEROUS)")

reg_act(:enable_debug, proc { cnf.debug = true }, "Enable debug")
reg_act(:disable_debug, proc { cnf.debug = false }, "Disable debug")

reg_act(:easy_jump, proc { EasyJump.start }, "Easy jump")
reg_act(:gui_ensure_cursor_visible, proc { vma.gui.view.ensure_cursor_visible }, "Scroll to current cursor position")
reg_act(:gui_refresh_cursor, proc { vma.buf.refresh_cursor }, "Refresh cursor")

reg_act(:savedebug, "savedebug", "Save debug info", { :group => :debug })
reg_act(:open_file_dialog, "open_file_dialog", "Open file", { :group => :file })
reg_act(:create_new_file, "create_new_file", "Create new file", { :group => :file })
reg_act(:backup_all_buffers, proc { backup_all_buffers }, "Backup all buffers", { :group => :file })
reg_act(:e_move_forward_char, "e_move_forward_char", "", { :group => [:move, :basic] })
reg_act(:e_move_backward_char, "e_move_backward_char", "", { :group => [:move, :basic] })
# reg_act(:history_switch_backwards, proc{bufs.history_switch_backwards}, "", { :group => :file })
reg_act(:history_switch_backwards, proc{bufs.history_switch(-1)}, "", { :group => :file })
reg_act(:history_switch_forwards, proc{bufs.history_switch(+1)}, "", { :group => :file })
reg_act(:center_on_current_line, "center_on_current_line", "", { :group => :view })
reg_act(:run_last_macro, proc { vma.macro.run_last_macro }, "Run last recorded or executed macro", { :group => :macro })
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
# reg_act(:close_all_buffers, proc { bufs.close_all_buffers() }, "Close all buffers")
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
reg_act(:gui_select_buffer, proc { vma.kbd.set_mode("S"); gui_select_buffer }, "Select buffer")
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

reg_act :start_browse_mode, proc {
  vma.kbd.set_mode(:browse)
  bufs.reset_navigation
}, "Start browse mode"
reg_act :kbd_dump_state, proc { vma.kbd.dump_state }, "Dump keyboard tree state"

reg_act :exit_browse_mode, proc {
  bufs.add_current_buf_to_history
  # Load previously saved buffer specific mode stack
  buf.restore_kbd_mode
}, "Exit browse mode"

# reg_act :page_down, proc { page_down }, "Page down", :group => [:move, :basic]
reg_act :page_down, proc { vma.gui.page_down }, "Page down", :group => [:move, :basic]

reg_act :page_up, proc { vma.gui.page_up }, "Page up", :group => [:move, :basic]
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

  :search_actions => { :proc => proc { vma.actions.gui_search },
                       :desc => "Search actions", :group => :search },

  :edit_customrb => { :proc => proc { jump_to_file("~/.config/vimamsa/custom.rb") },
                      :desc => "Customize (edit custom.rb)", :group => :search },

  :toggle_active_window => { :proc => proc { vma.gui.toggle_active_window },
                             :desc => "Switch active column in two column mode", :group => :search },

  :toggle_two_column => { :proc => proc { vma.gui.toggle_two_column },
                          :desc => "Toggle two column mode", :group => :search },

  :content_search => { :proc => proc { FileContentSearch.start_gui },
                       :desc => "Search content of files", :group => :search },

  :quit => { :proc => proc { _quit },
             :desc => "Quit", :group => :app },

  :run_tests => { :proc => proc { run_tests },
                  :desc => "Run tests" },

  :debug_buf_hex => { :proc => proc { puts "SHA256: " + (Digest::SHA2.hexdigest vma.buf.to_s) },
                      :desc => "Output SHA256 hex digest of curent buffer" },

  :start_autocomplete => { :proc => proc { vma.buf.view.start_autocomplete },
                           :desc => "Start autocomplete" },

  :show_autocomplete => { :proc => proc {
    # vma.buf.view.signal_emit("show-completion")
    # vma.buf.view.show_completion
    vma.buf.view.show_completions
  },
                          :desc => "Show autocomplete" },

}

for k, v in act_list
  reg_act(k, v[:proc], v[:desc])
end
