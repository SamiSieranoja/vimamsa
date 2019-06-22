
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
reg_act(:jump_to_last_edit, proc{$buffer.jump_to_last_edit}, "")

reg_act(:put_file_path_to_clipboard, proc{$buffer.put_file_path_to_clipboard},"Put file path of current file to clipboard")
bindkey "C , , c b", :put_file_path_to_clipboard #TODO: better binding or remove?

# reg_act(:encrypt_file, proc{$buffer.set_encrypted},"Set current file to encrypt on save")
reg_act(:encrypt_file, proc{encrypt_cur_buffer},"Set current file to encrypt on save")
bindkey "C , , e", :encrypt_file #TODO: better binding

reg_act(:set_unencrypted, proc{$buffer.set_unencrypted},"Set current file to save unencrypted")
bindkey "C , ; u", :set_unencrypted #TODO: better binding


reg_act(:close_current_buffer, proc{$buffers.close_current_buffer(true)},"Close current buffer")
bindkey "C , c b", :close_current_buffer

reg_act(:comment_selection, proc{$buffer.comment_selection}, "")
bindkey "V ctrl-c", :comment_selection

reg_act(:delete_char_forward, proc{$buffer.delete(CURRENT_CHAR_FORWARD)}, "Delete char forward")
bindkey "C x", :delete_char_forward

reg_act(:load_theme, proc{load_theme}, "Load theme")
bindkey "C , , l t"  , :load_theme

reg_act(:gui_file_finder, proc{gui_file_finder}, "Fuzzy file finder")
bindkey "C , f"  , :gui_file_finder

reg_act(:gui_search_replace, proc{gui_search_replace}, "Search and replace")
bindkey "C , r r"  , :gui_search_replace
bindkey "V , r r"  , :gui_search_replace


reg_act(:gui_select_buffer, proc{$at.set_mode("S");gui_select_buffer}, "Select buffer")
bindkey "C , b", :gui_select_buffer

reg_act :open_file_dialog, "open_file_dialog", "Open file"
bindkey "C , f o"  , :open_file_dialog
bindkey "CI ctrl-o" , :open_file_dialog

reg_act :minibuffer_end, proc{minibuffer_end}
bindkey "M return", :minibuffer_end

reg_act(:invoke_replace, "invoke_replace", "")
reg_act(:diff_buffer, "diff_buffer", "")

# reg_act(:invoke_grep_search, proc{invoke_grep_search}, "")
reg_act(:invoke_grep_search, proc{gui_grep}, "Grep current buffer")

reg_act(:ack_search, proc{gui_ack}, "") #invoke_ack_search
bindkey "C , a", :ack_search

reg_act :update_file_index, proc { update_file_index }, "Update file index"

#    'VC z z' => 'center_on_current_line',

bindkey "C , , f", :file_finder
bindkey "VC h", :e_move_backward_char


bindkey "C , , ." , :backup_all_buffers

bindkey "C z ", "$at.set_mode(BROWSE)"
bindkey "B h", :history_switch_backwards
bindkey "B l", :history_switch_forwards
#bindkey 'B z', :center_on_current_line
bindkey "B z", "center_on_current_line();$at.set_mode(COMMAND)"
bindkey "B j", "$buffers.add_current_buf_to_history();$at.set_mode(COMMAND)"
bindkey "B esc", "$buffers.add_current_buf_to_history();$at.set_mode(COMMAND)"
bindkey "B return", "$buffers.add_current_buf_to_history();$at.set_mode(COMMAND)"
bindkey "B enter", "$buffers.add_current_buf_to_history();$at.set_mode(COMMAND)"
bindkey "B c", :close_current_buffer

bindkey "B ;", "$buffer.jump_to_last_edit"
bindkey "B q", :jump_to_last_edit
bindkey "B w", :jump_to_next_edit


reg_act(:reset_highlight, proc{$buffer.reset_highlight}, "")
bindkey "C , , h", "toggle_highlight"
bindkey "C , r h", :reset_highlight
bindkey "C , d", :diff_buffer
bindkey "C , g", :invoke_grep_search
#bindkey 'C , g', proc{invoke_grep_search}


reg_act(:auto_indent_buffer, proc{$buffer.indent}, "Auto format buffer")
bindkey "C , v", :auto_indent_buffer
bindkey "C , , d", :savedebug
bindkey "C , , u", :update_file_index

bindkey "C , s a", "$buffer.save_as()"

#bindkey 'C z h', :history_switch_backwards
#bindkey 'C z l', :history_switch_forwards
