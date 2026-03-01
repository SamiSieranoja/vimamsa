vma.kbd.add_mode("C", :command)
vma.kbd.add_mode("I", :insert, :insert)
vma.kbd.add_mode("V", :visual, :visual)
vma.kbd.add_mode("M", :minibuffer) #TODO: needed?
vma.kbd.add_mode("R", :readchar)
vma.kbd.add_minor_mode("audio", :audio, :command)
vma.kbd.add_minor_mode("macro", :macro, :command)
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

add_keys "intro", {
  "C y y" => :copy_cur_line,
  "C P" => :paste_before_cursor,
  "C p" => :paste_after_cursor,
  "C v" => :start_visual_mode,
  "C ctrl-r" => :redo,
  "C u" => :undo,
  "VC O" => :jump_end_of_line,
  # NOTE: "G(condition)" need to be defined before "G"
  "VC G(vma.kbd.next_command_count!=nil)" => "buf.jump_to_line()",
  "VC G" => :jump_end_of_buffer,
  "VC g ;" => :jump_last_edit,
  "VC g g" => :jump_start_of_buffer,
  "VC e" => :jump_next_word_end,
  "VC b" => :jump_prev_word_start,
  "VC w" => :jump_next_word_start,
  "V esc" => "buf.end_visual_mode",
  "V ctrl!" => "buf.end_visual_mode", 
  
  "C ctrl!" => :insert_mode,
  "C i" => :insert_mode,
  "I esc || I ctrl!" => :prev_mode,
  "IX alt-b" => :jump_prev_word_start,
  "IX alt-f" => :jump_next_word_start,
  "IX ctrl-e" => :jump_end_of_line,
  "IX ctrl-p" => :move_prev_line,
  "IX ctrl-n" => :move_next_line,
  "IX ctrl-b" => :move_backward_char,
  "IX ctrl-a" => :jump_beginning_of_line,
}

add_keys "intro delete", {
  "C x" => :delete_char_forward,
  "C d d" => [:delete_line, proc { buf.delete_line }, "Delete current line"]
}


add_keys "core", {

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

  #    'C '=> 'buf.jump_word(BACKWARD,END)',#TODO
  "VC f <char>" => "buf.jump_to_next_instance_of_char(<char>)",
  "VC F <char>" => "buf.jump_to_next_instance_of_char(<char>,BACKWARD)",
  "VC f space" => "buf.jump_to_next_instance_of_char(' ')",
  "VC F space" => "buf.jump_to_next_instance_of_char(' ',BACKWARD)",

  "VC /[1-9]/" => "vma.kbd.set_next_command_count(<char>)",
  #    'VC number=/[0-9]/+ g'=> 'jump_to_line(<number>)',
  #    'VC X=/[0-9]/+ * Y=/[0-9]/+ '=> 'x_times_y(<X>,<Y>)',
  "VC 0(vma.kbd.next_command_count!=nil)" => "set_next_command_count(<char>)",
  "VC 0(vma.kbd.next_command_count==nil)" => "buf.jump(BEGINNING_OF_LINE)",
  # 'C 0'=> 'buf.jump(BEGINNING_OF_LINE)',
  "VC ^" => "buf.jump(BEGINNING_OF_LINE)",
  #    'VC z z' => 'center_on_current_line',
  "VC *" => "buf.jump_to_next_instance_of_word",

  "C , e" => "invoke_command", # Currently eval

  "VC /" => :find_in_buffer,

  # READCHAR bindings

  "R <char>" => "readchar_new_char(<char>)",

  "C n" => "$search.jump_to_next()",
  "C N" => "$search.jump_to_previous()",

  "C C" => :content_search,

  "C , c s" => "bufs.close_scrap_buffers",

  "VC $" => "buf.jump(END_OF_LINE)",

  "C o" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");vma.kbd.set_mode(:insert)',
  "C X" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");',
  "C A" => "buf.jump(END_OF_LINE);vma.kbd.set_mode(:insert)",
  "C I" => "buf.jump(FIRST_NON_WHITESPACE);vma.kbd.set_mode(:insert)",
  "C a" => "buf.move(FORWARD_CHAR);vma.kbd.set_mode(:insert)",
  "C J" => "buf.join_lines()",

  "C ^" => "buf.jump(BEGINNING_OF_LINE)",
  # "C /[1-9]/" => "vma.kbd.set_next_command_count(<char>)",

  # Command mode only:
  "C space <char>" => "buf.insert_txt(<char>)",
  "C space space" => "buf.insert_txt(' ')",
  "C y O" => "buf.copy(:to_line_end)",
  "C y 0" => "buf.copy(:to_line_start)",
  "C y e" => "buf.copy(:to_word_end)", # TODO
  #### Deleting
  # "C x" => "buf.delete(CURRENT_CHAR_FORWARD)",
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
  "CI backspace" => :insert_backspace,

  # Marks
  "CV m <char>" => "buf.mark_current_position(<char>)",
  'CV \' <char>' => "buf.jump_to_mark(<char>)",
  # "CV ''" =>'jump_to_mark(NEXT_MARK)', #TODO

  # Switch to another mode
  "C R" => "vma.kbd.set_mode(:replace)",

  # Replace mode
  "X esc || X ctrl!" => "vma.kbd.to_previous_mode",
  "X <char>" => "buf.replace_with_char(<char>);buf.move(FORWARD_CHAR)",

  # Macros
  # (experimental, may not work correctly)
  # "C q a" => 'vma.macro.start_recording("a")',
  
  "macro q" => "vma.kbd.to_previous_mode; vma.macro.end_recording",
  # "macro q z" => "vma.kbd.to_previous_mode; vma.macro.end_recording",
  
  # "VC q(vma.macro.is_recording==true)" => "vma.macro.end_recording", # TODO: does not work
  # "VC o(vma.macro.is_recording==true)" => "vma.macro.end_recording", # TODO: does not work
  # "VC q q(vma.macro.is_recording==true)" => "vma.macro.end_recording",
  "VC q <char>" => "vma.kbd.set_mode(:macro);vma.macro.start_recording(<char>)",
  # 'C q'=> 'vma.macro.end_recording', #TODO
  
  # "C q v" => "vma.kbd.to_previous_mode; vma.macro.end_recording", #TODO
  
  # 'C v'=> 'vma.macro.end_recording',
  # "C M" => 'vma.macro.run_last_macro',
  "C @ <char>" => "vma.macro.run_macro(<char>)",
  "C , m S" => 'vma.macro.save_macro("a")',
  "C , m s" => "vma.macro.save",

  # "C ." => "repeat_last_action", # TODO
  "VC ;" => "repeat_last_find",
  # "CV Q" => :quit,
  "CV ctrl-q" => :quit,
  # "I ctrl!" => "vma.kbd.to_previous_mode",
  "C shift! s" => "buf.save",
  "I ctrl-s" => "buf.save",
  "I <char>" => "buf.insert_txt(<char>)",

  "I ctrl-d" => "buf.delete2(:to_word_end)",

  # Insert and Replace modes: Moving
  "IX ctrl-f" => "buf.move(FORWARD_CHAR)",

  "I ctrl-j" => "vma.buf.view.hide_completions",

  "I space" => 'buf.insert_txt(" ")',
#  "I return" => 'buf.insert_new_line()',

 "CI ctrl-o" => :open_file_dialog,
 "C , a" => :ack_search,
 "C d w" => :delete_to_next_word_start,

 "C d 0" => :delete_to_line_start,
 "C , , f" => :file_finder,
 "VC h" => :e_move_backward_char,
 "C , , ." => :backup_all_buffers,
 "C z " => :start_browse_mode,
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
 "C , v" => :auto_indent_buffer,
 "C , , u" => :update_file_index,
 "C , s a" => :buf_save_as,
 "VC , r r" => :gui_search_replace,
 "V , t b" => :set_style_bold,
 "V , t l" => :set_style_link,
 "V J" => :V_join_lines,
 "V , t c" => :clear_formats,
 "C , t h" => :set_line_style_heading,
 "C , t 1" => :set_line_style_h1,
 "C , t 2" => :set_line_style_h2,
 "C , t 3" => :set_line_style_h3,
 "C , t 4" => :set_line_style_h4,
 "C , t b" => :set_line_style_bold,
 "C , t t" => :set_line_style_title,
 "C , t c" => :clear_line_styles,
 "C , b" => :start_buf_manager,
 "C , w" => :toggle_active_window,
 "C , , w" => :toggle_two_column,

 "VC s" => :easy_jump,
 "I alt-s" => :easy_jump,
 "VC , m f" => [:find_macro_gui, proc { vma.macro.find_macro_gui }, "Find named macro"],
 "C , m n" => [:gui_name_macro, proc { vma.macro.gui_name_macro }, "Name last macro"],
 "C , j r" => :jump_to_random,
 "C , ; s k" => :show_key_bindings, #TODO: better binding,
 "C , , c b" => :put_file_path_to_clipboard, #TODO: better binding or remove?,
 "C , , e" => :encrypt_file, #TODO: better binding,
 "C , ; u" => :set_unencrypted, #TODO: better binding,
 "C , c b" => :close_current_buffer,
 "V ctrl-c" => :comment_selection,
 "C , f" => :gui_file_finder,
 "C , h" => :gui_file_history_finder,
 "C , z" => :gui_file_finder,

 "C enter || C return" => [:line_action, proc { buf.handle_line_action() }, "Line action"],
 "V d" => [:delete_selection, proc { buf.delete(SELECTION) }, ""],
 "V a d" => [:delete_append_selection, proc { buf.delete(SELECTION, :append) }, "Delete and append selection"]
}

bindkey ["VCB M", "B m"], :run_last_macro

add_keys "experimental", {
 "C ` k" => :lsp_debug,
 "C ` j" => :lsp_jump_to_definition,
 "C , u s" => :audio_stop,

  "C , t r" => "run_tests()",
  # "CV , R" => "restart_application", #TODO: does not work
  "I ctrl-h" => :show_autocomplete, #TODO: does not work
  "C , d m" => :kbd_dump_state,
  "C , ; ." => :increment_word,
  "C , d d" => "debug_dump_deltas",
  "C , d c" => "debug_dump_clipboard",
  "C , d b" => "debug_print_buffer",
  "C , D" => "debug_print_buffer",
  "C , d o" => "vma.gui.clear_overlay",
  # Debug
  "C , d r p" => 'require "pry"; binding.pry', #TODO
#bindkey 'C , g', proc{invoke_grep_search}
# bindkey "C , d", :diff_buffer
 "C , , d" => :savedebug,
 "C , m a" => "vma.kbd.set_mode(:audio)",
 "audio s" => :audio_stop,
}


bindkey "audio f || audio right", [:audio_forward, proc { Audio.seek_forward }, "Seek forward in audio stream"]
bindkey "audio left", [:audio_backward, proc { Audio.seek_forward(-5.0) }, "Seek backward in audio stream"]

bindkey "audio space", :audio_stop
bindkey "audio q || audio esc", "vma.kbd.to_previous_mode"


bindkey "C , i p", "generate_password_to_buf(15)"

# default_keys.each { |key, value|
  # bindkey(key, value)
# }
