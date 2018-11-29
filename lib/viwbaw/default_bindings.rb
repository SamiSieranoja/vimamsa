
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

def jump_to_last_edit
    $buffer.jump_to_last_edit
end




reg_act(:file_finder, 'gui_file_finder', 'Fuzzy file finder')
reg_act(:open_file_dialog, 'open_file_dialog', 'Open file')
reg_act(:create_new_file, 'create_new_file', 'Create new file')
reg_act(:backup_all_buffers, 'backup_all_buffers', 'Backup all buffers')
reg_act(:invoke_ack_search, 'invoke_ack_search', 'Invoke ack search')
reg_act(:e_move_forward_char, 'e_move_forward_char', '')
reg_act(:e_move_backward_char, 'e_move_backward_char', '')
reg_act(:history_switch_backwards, 'history_switch_backwards', '')
reg_act(:history_switch_forwards, 'history_switch_forwards', '')
reg_act(:center_on_current_line, 'center_on_current_line', '')

reg_act(:jump_to_next_edit, 'jump_to_next_edit', '')
reg_act(:jump_to_last_edit, 'jump_to_last_edit', '')


#    'VC z z' => 'center_on_current_line',

bindkey 'C , , f', :file_finder
bindkey 'VC h', :e_move_backward_char

bindkey 'C z ', '$at.set_mode(BROWSE)'
bindkey 'B h', :history_switch_backwards
bindkey 'B l', :history_switch_forwards
#bindkey 'B z', :center_on_current_line
bindkey 'B z', 'center_on_current_line();$at.set_mode(COMMAND)'
bindkey 'B j', '$at.set_mode(COMMAND)'
bindkey 'B esc', '$at.set_mode(COMMAND)'
bindkey 'B return', '$at.set_mode(COMMAND)'
bindkey 'B enter', '$at.set_mode(COMMAND)'
bindkey 'B ;', '$buffer.jump_to_last_edit'
bindkey 'B q', :jump_to_last_edit 
bindkey 'B w', :jump_to_next_edit 

bindkey 'C , , h', 'toggle_highlight'


#bindkey 'C z h', :history_switch_backwards
#bindkey 'C z l', :history_switch_forwards
