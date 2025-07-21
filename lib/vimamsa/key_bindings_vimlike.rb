vma.kbd.add_mode("C", :command)
vma.kbd.add_mode("I", :insert, :insert)
vma.kbd.add_mode("V", :visual, :visual)
vma.kbd.add_mode("M", :minibuffer) #TODO: needed?
vma.kbd.add_mode("R", :readchar)
vma.kbd.add_minor_mode("audio", :audio, :command)
vma.kbd.add_mode("B", :browse, :browse, scope: :editor)
vma.kbd.add_mode("X", :replace, :replace, name: "Replace")
vma.kbd.set_default_mode(:command)
vma.kbd.__set_mode(:command) #TODO:needed?
# cnf.mode.command.cursor.background = "#fc6f03"
cnf.mode.command.cursor.background = "#05c5a0"
cnf.mode.default.cursor.background = "#03fcca"
# cnf.mode.visual.cursor.background = "#10bd8e"
# cnf.mode.visual.cursor.background = "#e95420"
# cnf.mode.visual.cursor.background = "#cb3804"
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

bindkey ["VCB M", "B m"], :run_last_macro

bindkey "VC s", :easy_jump
bindkey "I alt-s", :easy_jump
bindkey "VC , m f", [:find_macro_gui, proc { vma.macro.find_macro_gui }, "Find named macro"]
bindkey "C , m n", [:gui_name_macro, proc { vma.macro.gui_name_macro }, "Name last macro"]
bindkey "C , j r", :jump_to_random
bindkey "C , ; s k", :show_key_bindings #TODO: better binding
bindkey "C , , c b", :put_file_path_to_clipboard #TODO: better binding or remove?
bindkey "C , , e", :encrypt_file #TODO: better binding
bindkey "C , ; u", :set_unencrypted #TODO: better binding
bindkey "C , c b", :close_current_buffer
bindkey "V ctrl-c", :comment_selection
bindkey "C x", :delete_char_forward
bindkey "C , , l t", :load_theme
bindkey "C , f", :gui_file_finder
bindkey "C , h", :gui_file_history_finder
bindkey "C , z", :gui_file_finder

bindkey "C ` k", :lsp_debug
bindkey "C ` j", :lsp_jump_to_definition

bindkey "C , r r", :gui_search_replace
bindkey "V , r r", :gui_search_replace
bindkey "V , t b", :set_style_bold
bindkey "V , t l", :set_style_link
bindkey "V J", :V_join_lines
bindkey "V , t c", :clear_formats
bindkey "C , t h", :set_line_style_heading
bindkey "C , t 1", :set_line_style_h1
bindkey "C , t 2", :set_line_style_h2
bindkey "C , t 3", :set_line_style_h3
bindkey "C , t 4", :set_line_style_h4
bindkey "C , t b", :set_line_style_bold
bindkey "C , t t", :set_line_style_title
bindkey "C , t c", :clear_line_styles
bindkey "C , b", :start_buf_manager
bindkey "C , w", :toggle_active_window
bindkey "C , , w", :toggle_two_column

bindkey "C , u s", :audio_stop
bindkey "C , m a", "vma.kbd.set_mode(:audio)"
bindkey "audio s", :audio_stop
bindkey "audio f || audio right", [:audio_forward, proc { Audio.seek_forward }, "Seek forward in audio stream"]
bindkey "audio left", [:audio_backward, proc { Audio.seek_forward(-5.0) }, "Seek backward in audio stream"]

bindkey "audio space", :audio_stop
bindkey "audio q || audio esc", "vma.kbd.to_previous_mode"

# bindkey "C , f o", :open_file_dialog
bindkey "CI ctrl-o", :open_file_dialog
# bindkey "M enter", :minibuffer_end
bindkey "C , a", :ack_search
bindkey "C d w", :delete_to_next_word_start

bindkey "C d 0", :delete_to_line_start
bindkey "C , , f", :file_finder
bindkey "VC h", :e_move_backward_char
bindkey "C , , .", :backup_all_buffers
bindkey "C z ", :start_browse_mode
bindkey "B h", :history_switch_backwards
bindkey "B l", :history_switch_forwards
bindkey "B z", "center_on_current_line();call_action(:exit_browse_mode)"
bindkey "B enter || B return || B esc || B j || B ctrl!", :exit_browse_mode
bindkey "B s", :page_up
bindkey "B d", :page_down
bindkey "B r", proc { vma.gui.page_down(multip: 0.25) }
bindkey "B e", proc { vma.gui.page_up(multip: 0.25) }

bindkey "B i", :jump_to_start_of_buffer
bindkey "B o", :jump_to_end_of_buffer
bindkey "B c", :close_current_buffer
bindkey "B ;", "buf.jump_to_last_edit"
bindkey "B q", :jump_to_last_edit
bindkey "B w", :jump_to_next_edit
# bindkey "C , d", :diff_buffer
#bindkey 'C , g', proc{invoke_grep_search}
bindkey "C , v", :auto_indent_buffer
bindkey "C , , d", :savedebug
bindkey "C , , u", :update_file_index
bindkey "C , s a", :buf_save_as
bindkey "C d d", [:delete_line, proc { buf.delete_line }, "Delete current line"]
bindkey "C enter || C return", [:line_action, proc { buf.handle_line_action() }, "Line action"]
bindkey "C p", [:paste_after, proc { buf.paste(AFTER) }, ""] # TODO: implement as replace for visual mode
bindkey "V d", [:delete_selection, proc { buf.delete(SELECTION) }, ""]
bindkey "V a d", [:delete_append_selection, proc { buf.delete(SELECTION, :append) }, "Delete and append selection"]


default_keys = {

  # File handling
  "C ctrl-s" => :buf_save,

  # Buffer handling
  # "C B" => "bufs.switch",
  "C tab" => "bufs.switch_to_last_buf",
  #    'C , s'=> 'gui_select_buffer',
  "C , r v b" => :buf_revert,
  "C , c b" => "bufs.close_current_buffer",
  "C , n b" => :buf_new,
  # "C , , ." => "backup_all_buffers()",
  "VC , , s" => :search_actions,

  # MOVING
  #    'VC h' => 'buf.move(BACKWARD_CHAR)',
  "VC l" => "buf.move(FORWARD_CHAR)",
  # "VC j" => "buf.move(FORWARD_LINE)",
  # "VC k" => "buf.move(BACKWARD_LINE)",

  "VCI pagedown" => :page_down,
  "VCI pageup" => :page_up,

  "I down(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_next",
  "I tab(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_next",
  "I up(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_previous",
  "I shift-tab(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_previous",
  "I enter(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select",

  "I tab" => "buf.insert_tab",
  "I shift-tab" => "buf.unindent",

  "I enter" => :insert_new_line,

  "I shift-down" => "insert_select_move(BACKWARD_CHAR)",
  "I shift-right" => "insert_select_move(FORWARD_CHAR)",
  "I shift-down" => "insert_select_move(FORWARD_LINE)",
  "I shift-up" => "insert_select_move(BACKWARD_LINE)",
  "I shift-pagedown" => "insert_select_move(:pagedown)",
  "I shift-pageup" => "insert_select_move(:pageup)",

  "I left" => "insert_move(BACKWARD_CHAR)",
  "I right" => "insert_move(FORWARD_CHAR)",
  "I down" => "insert_move(FORWARD_LINE)",
  "I up" => "insert_move(BACKWARD_LINE)",
  "I pagedown" => "insert_move(:pagedown)",
  "I pageup" => "insert_move(:pageup)",

  #TODO:
  "I @shift-click" => "insert_mode_shift_click(charpos)",

  "VCX left" => "buf.move(BACKWARD_CHAR)",
  "VCX right" => "buf.move(FORWARD_CHAR)",
  "VCX down" => "buf.move(FORWARD_LINE)",
  "VCX up" => "buf.move(BACKWARD_LINE)",

  "VC w" => "buf.jump_word(FORWARD,WORD_START)",
  "VC b" => "buf.jump_word(BACKWARD,WORD_START)",
  "VC e" => "buf.jump_word(FORWARD,WORD_END)",
  #    'C '=> 'buf.jump_word(BACKWARD,END)',#TODO
  "VC f <char>" => "buf.jump_to_next_instance_of_char(<char>)",
  "VC F <char>" => "buf.jump_to_next_instance_of_char(<char>,BACKWARD)",
  "VC f space" => "buf.jump_to_next_instance_of_char(' ')",
  "VC F space" => "buf.jump_to_next_instance_of_char(' ',BACKWARD)",

  "VC /[1-9]/" => "vma.kbd.set_next_command_count(<char>)",
  #    'VC number=/[0-9]/+ g'=> 'jump_to_line(<number>)',
  #    'VC X=/[0-9]/+ * Y=/[0-9]/+ '=> 'x_times_y(<X>,<Y>)',
  "VC G(vma.kbd.next_command_count!=nil)" => "buf.jump_to_line()",
  "VC 0(vma.kbd.next_command_count!=nil)" => "set_next_command_count(<char>)",
  "VC 0(vma.kbd.next_command_count==nil)" => "buf.jump(BEGINNING_OF_LINE)",
  # 'C 0'=> 'buf.jump(BEGINNING_OF_LINE)',
  "VC g g" => "buf.jump(START_OF_BUFFER)",
  "VC g ;" => "buf.jump_to_last_edit",
  "VC ^" => "buf.jump(BEGINNING_OF_LINE)",
  "VC G" => "buf.jump(END_OF_BUFFER)",
  #    'VC z z' => 'center_on_current_line',
  "VC *" => "buf.jump_to_next_instance_of_word",

  "C , e" => "invoke_command", # Currently eval

  "VC /" => :find_in_buffer,

  # READCHAR bindings

  "R <char>" => "readchar_new_char(<char>)",

  "C n" => "$search.jump_to_next()",
  "C N" => "$search.jump_to_previous()",

  "C C" => :content_search,

  # Debug
  "C , d r p" => "start_ripl",
  "C , d o" => "vma.gui.clear_overlay",
  "C , D" => "debug_print_buffer",
  "C , c s" => "bufs.close_scrap_buffers",
  "C , d b" => "debug_print_buffer",
  "C , d c" => "debug_dump_clipboard",
  "C , d d" => "debug_dump_deltas",
  "C , d m" => :kbd_dump_state,

  "VC O" => "buf.jump(END_OF_LINE)",
  "VC $" => "buf.jump(END_OF_LINE)",

  "C o" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");vma.kbd.set_mode(:insert)',
  "C X" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");',
  "C A" => "buf.jump(END_OF_LINE);vma.kbd.set_mode(:insert)",
  "C I" => "buf.jump(FIRST_NON_WHITESPACE);vma.kbd.set_mode(:insert)",
  "C a" => "buf.move(FORWARD_CHAR);vma.kbd.set_mode(:insert)",
  "C J" => "buf.join_lines()",
  "C u" => "buf.undo()",

  "C ^" => "buf.jump(BEGINNING_OF_LINE)",
  # "C /[1-9]/" => "vma.kbd.set_next_command_count(<char>)",

  # Command mode only:
  "C ctrl-r" => "buf.redo()", # TODO:???
  "C v" => "buf.start_selection;vma.kbd.set_mode(:visual)",
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
  "C d ' <char>" => "buf.delete2(:to_mark,<char>)",
  "C r <char>" => "buf.replace_with_char(<char>)", # TODO
  "C r space" => "buf.replace_with_char(' ')", # TODO
  "C , l b" => "load_buffer_list",
  "C , l l" => "save_buffer_list",
  "C , r <char>" => "vma.set_register(<char>)", # TODO
  "C , p <char>" => "buf.paste(BEFORE,<char>)", # TODO

  "C ctrl-c" => "buf.comment_line()",
  "C ctrl-x" => "buf.comment_line(:uncomment)",

  # 'C 0($next_command_count==nil)'=> 'jump_to_beginning_of_line',

  # Visual mode only:
  "V esc" => "buf.end_visual_mode",
  "V ctrl!" => "buf.end_visual_mode",
  "V y" => "buf.copy_active_selection()",
  "V a y" => "buf.copy_active_selection(:append)",
  "V g U" => :selection_upcase,
  "V g u" => :selection_downcase,
  "V g c" => :selection_capitalize,
  "V g s" => :selection_swapcase,
  "V g r" => :selection_reverse,

  "VC j" => :forward_line,
  "VC k" => :backward_line,

  "V x" => "buf.delete(SELECTION)",
  # "V ctrl-c" => "buf.comment_selection",
  "V ctrl-x" => "buf.comment_selection(:uncomment)",

  "CI ctrl-v" => "buf.paste(BEFORE)",
  "CI backspace" => "buf.delete(BACKWARD_CHAR)",

  # Marks
  "CV m <char>" => "buf.mark_current_position(<char>)",
  'CV \' <char>' => "buf.jump_to_mark(<char>)",
  # "CV ''" =>'jump_to_mark(NEXT_MARK)', #TODO

  # Switch to another mode
  "C i" => "vma.kbd.set_mode(:insert)",
  "C R" => "vma.kbd.set_mode(:replace)",
  "C ctrl!" => "vma.kbd.set_mode(:insert)",

  # Replace mode
  "X esc || X ctrl!" => "vma.kbd.to_previous_mode",
  "X <char>" => "buf.replace_with_char(<char>);buf.move(FORWARD_CHAR)",

  # Macros
  # (experimental, may not work correctly)
  # "C q a" => 'vma.macro.start_recording("a")',
  "VC q <char>" => "vma.macro.start_recording(<char>)",
  "VC q(vma.macro.is_recording==true) " => "$macro.end_recording", # TODO
  # 'C q'=> 'vma.macro.end_recording', #TODO
  "C q v" => "vma.macro.end_recording",
  # 'C v'=> 'vma.macro.end_recording',
  # "C M" => 'vma.macro.run_last_macro',
  "C @ <char>" => "vma.macro.run_macro(<char>)",
  "C , m S" => 'vma.macro.save_macro("a")',
  "C , m s" => "vma.macro.save",
  "C , t r" => "run_tests()",

  # "C ." => "repeat_last_action", # TODO
  "VC ;" => "repeat_last_find",
  # "CV Q" => :quit,
  "CV ctrl-q" => :quit,
  "CV , R" => "restart_application",
  # "I ctrl!" => "vma.kbd.to_previous_mode",
  "C shift! s" => "buf.save",
  "I ctrl-s" => "buf.save",
  "I <char>" => "buf.insert_txt(<char>)",
  "I esc || I ctrl!" => "vma.kbd.to_previous_mode",

  "I ctrl-d" => "buf.delete2(:to_word_end)",

  # Insert and Replace modes: Moving
  "IX ctrl-a" => "buf.jump(BEGINNING_OF_LINE)",
  "IX ctrl-b" => "buf.move(BACKWARD_CHAR)",
  "IX ctrl-f" => "buf.move(FORWARD_CHAR)",
  "IX ctrl-n" => "buf.move(FORWARD_LINE)",
  "IX ctrl-p" => "buf.move(BACKWARD_LINE)",
  "IX ctrl-e" => "buf.jump(END_OF_LINE)", # context: mode:I, buttons down: {C}
  "IX alt-f" => "buf.jump_word(FORWARD,WORD_START)",
  "IX alt-b" => "buf.jump_word(BACKWARD,WORD_START)",

  "I ctrl-h" => :show_autocomplete,
  "I ctrl-j" => "vma.buf.view.hide_completions",

  "I space" => 'buf.insert_txt(" ")',
#  "I return" => 'buf.insert_new_line()',
}

bindkey "C , i p", "generate_password_to_buf(15)"

default_keys.each { |key, value|
  bindkey(key, value)
}
