
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


reg_act(:file_finder, 'gui_file_finder', 'Fuzzy file finder')
reg_act(:open_file_dialog, 'open_file_dialog', 'Open file')
reg_act(:create_new_file, 'create_new_file', 'Create new file')
reg_act(:backup_all_buffers, 'backup_all_buffers', 'Backup all buffers')
reg_act(:invoke_ack_search, 'invoke_ack_search', 'Invoke ack search')
reg_act(:e_move_forward_char, 'e_move_forward_char', '')
reg_act(:e_move_backward_char, 'e_move_backward_char', '')
reg_act(:history_switch_backwards, 'history_switch_backwards', '')
reg_act(:history_switch_forwards, 'history_switch_forwards', '')

bindkey 'C , , f', :file_finder
bindkey 'VC h', :e_move_backward_char

bindkey 'C z ', '$at.set_mode(BROWSE)'
bindkey 'B h', :history_switch_backwards
bindkey 'B l', :history_switch_forwards
bindkey 'B j', '$at.set_mode(COMMAND)'
bindkey 'B esc', '$at.set_mode(COMMAND)'
bindkey 'B return', '$at.set_mode(COMMAND)'
bindkey 'B enter', '$at.set_mode(COMMAND)'

#bindkey 'C z h', :history_switch_backwards
#bindkey 'C z l', :history_switch_forwards



