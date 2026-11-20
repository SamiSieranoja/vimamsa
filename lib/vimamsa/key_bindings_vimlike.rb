
module Vimamsa
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

add_keys "intro cat:motion", {
  "VCX up" => "buf.move(BACKWARD_LINE)",
  "VCX down" => "buf.move(FORWARD_LINE)",
  "VCX right" => "buf.move(FORWARD_CHAR)",
  "VCX left" => "buf.move(BACKWARD_CHAR)",
  "VC l" => "move.char.next",
  "VC O" => "move.line.end",
  # NOTE: "G(condition)" need to be defined before "G"
  "VC G(vma.kbd.next_command_count!=nil)" => "buf.jump_to_line()",
  "VC G" => "move.buf.end",
  "VC g g" => "move.buf.start",
  "VC e" => "move.word.end",
  "VC b" => "move.word.prev",
  "VC w" => "move.word.next",
  "IX alt-b" => "move.word.prev",
  "IX alt-f" => "move.word.next",
  "IX ctrl-e" => "move.line.end",
  "IX ctrl-p" => "move.line.prev",
  "IX ctrl-n" => "move.line.next",
  "IX ctrl-b" => "move.char.prev",
  "IX ctrl-a" => "move.line.start",
}

add_keys "intro cat:search", {
  "VC , , s" => "search.actions",
  "VC g ;" => "jump.edit.prev",
  "C g f" => "jump.file",
  "I ctrl-l" => "search.buf",
  "I ctrl-g" => "search.next",
}

add_keys "intro cat:insert", {
  "C ctrl!" => "mode.insert",
  "C i" => "mode.insert",
  # Guarded esc must be defined before the unguarded one: on multiple
  # matches the first-registered state with an action wins
  # "I esc(vma.buf.view.autocp_active)" => "vma.buf.view.hide_completions",
  "I esc || I ctrl!" => "mode.prev",
}

add_keys "intro cat:edit", {
  "C y y" => "edit.line.copy",
  "C P" => "edit.paste.before",
  "C p" => "edit.paste.after",
  "CI ctrl-v" => "edit.paste.before",
  "CI backspace" => "edit.backspace",
}

add_keys "intro cat:visual", {
  "C v" => "mode.visual",
  "V esc" => "buf.end_visual_mode",
  "V ctrl!" => "buf.end_visual_mode",
  "V tab" => "buf.indent_selection",
  "V shift-tab" => "buf.unindent_selection",
  "I ctrl-c" => "sel.copy", #TODO: in control mode also?
  "CI ctrl-x" => "sel.cut",
  "I shift-up" => "sel.line.prev",
  "I shift-down" => "sel.line.next",
}

add_keys "intro cat:undo", {
  "C ctrl-r" => "undo.redo",
  "C u" => "undo.last",
  "CI ctrl-z" => "undo.last",
  "I ctrl-y" => "undo.redo",
}

add_keys "intro cat:marks", {
  "C , M" => "mark.add",
  "C , '" => "mark.list",
}

add_keys "intro cat:file", {
  "CI ctrl-o" => "file.open",
}

add_keys "intro cat:buffer", {
  "C , b" => "buf.manager",
  "C , n b" => "buf.new",
  "CI ctrl-w" => "buf.close",
}

add_keys "intro delete", {
  "C x" => "edit.delete.char",
  "C d d" => ["edit.delete.line", proc { buf.delete_line }, "Delete current line"]
}


add_keys "core cat:motion", {
  "VCI pagedown" => "move.page.next",
  "VCI pageup" => "move.page.prev",
  "I left" => "insert_move(BACKWARD_CHAR)",
  "I right" => "insert_move(FORWARD_CHAR)",
  "I down" => "insert_move(FORWARD_LINE)",
  "I up" => "insert_move(BACKWARD_LINE)",
  "I pagedown" => "insert_move(:pagedown)",
  "I pageup" => "insert_move(:pageup)",
  "VC /[1-9]/" => "vma.kbd.set_next_command_count(<char>)",
  #    'VC number=/[0-9]/+ g'=> 'jump_to_line(<number>)',
  #    'VC X=/[0-9]/+ * Y=/[0-9]/+ '=> 'x_times_y(<X>,<Y>)',
  "VC 0(vma.kbd.next_command_count!=nil)" => "vma.kbd.set_next_command_count(<char>)",
  "VC 0(vma.kbd.next_command_count==nil)" => "buf.jump(BEGINNING_OF_LINE)",
  # 'C 0'=> 'buf.jump(BEGINNING_OF_LINE)',
  "VC ^" => "buf.jump(BEGINNING_OF_LINE)",
  "VC $" => "buf.jump(END_OF_LINE)",
  "C ^" => "buf.jump(BEGINNING_OF_LINE)",
  "VC j" => "move.line.next",
  "VC k" => "move.line.prev",
  # Insert and Replace modes: Moving
  "IX ctrl-f" => "buf.move(FORWARD_CHAR)",
  "VC h" => "move.char.prev",
  "B s" => "move.page.prev",
  "B d" => "move.page.next",
  "B i" => "move.buf.start",
  "B o" => "move.buf.end",
  "C , j r" => "move.random",
}

add_keys "core cat:search", {
  #    'C '=> 'buf.jump_word(BACKWARD,END)',#TODO
  "VC f <char>" => "buf.jump_to_next_instance_of_char(<char>)",
  "VC F <char>" => "buf.jump_to_next_instance_of_char(<char>,BACKWARD)",
  "VC f space" => "buf.jump_to_next_instance_of_char(' ')",
  "VC F space" => "buf.jump_to_next_instance_of_char(' ',BACKWARD)",
  #    'VC z z' => 'center_on_current_line',
  "VC *" => "buf.jump_to_next_instance_of_word",
  "VC /" => "search.buf",
  "C n" => "search.next",
  "C N" => "$search.jump_to_previous()",
  # "C ." => "repeat_last_action", # TODO
  "VC ;" => "repeat_last_find",
  "B ;" => "jump.edit.prev",
  "B q" => "jump.edit.prev",
  "B w" => "jump.edit.next",
  "VC , r r" => "search.replace",
  "VC s" => "jump.easy",
  "I alt-s" => "jump.easy",
  "C enter || C return" => ["jump.line", proc { buf.handle_line_action() }, "Line action"],
}

add_keys "core cat:insert", {
  # "I down(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_next",
  "I tab(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_next",
  # "I up(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_previous",
  "I shift-tab(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_previous",
  "I shift!(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select",
  # Typing a character. Reached both from a key press and from an input method
  # commit (AltGr, dead keys, compose — those produce no key press at all, see
  # VSourceView#register_buffer_signals), so insertion lives here rather than in
  # the GUI layer.
  "I <char>" => "buf.insert_txt(<char>)",
  "I tab" => "buf.insert_tab",
  "I shift-tab" => "buf.unindent",
  "C o" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");vma.kbd.set_mode(:insert)',
  "C X" => 'buf.jump(END_OF_LINE);buf.insert_txt("\n");',
  "C A" => "buf.jump(END_OF_LINE);vma.kbd.set_mode(:insert)",
  "C I" => "buf.jump(FIRST_NON_WHITESPACE);vma.kbd.set_mode(:insert)",
  "C a" => "buf.move(FORWARD_CHAR);vma.kbd.set_mode(:insert)",
  # Command mode only:
  "C space <char>" => "buf.insert_txt(<char>)",
  "C space space" => "buf.insert_txt(' ')",
  "I <char>" => "buf.insert_txt(<char>)",
  "I ctrl-j" => "vma.buf.view.hide_completions",
  "I space" => 'buf.insert_txt(" ")',
}

add_keys "core cat:edit", {
  "I enter" => "edit.newline",
  "C J" => "buf.join_lines()",
  "C y O" => "buf.copy(:to_line_end)",
  "C y 0" => "buf.copy(:to_line_start)",
  "C y e" => "buf.copy(:to_word_end)", # TODO
  "C y ' <char>" => "buf.copy(:to_mark,<char>)",
  #### Deleting
  # "C x" => "buf.delete(CURRENT_CHAR_FORWARD)",
  # 'C d k'=> 'delete_line(BACKWARD)', #TODO
  # 'C d j'=> 'delete_line(FORWARD)', #TODO
  # 'C d d'=> 'buf.delete_cur_line',
  "C d e" => "buf.delete2(:to_word_end)",
  "C d O" => "buf.delete2(:to_line_end)",
  "C d $" => "buf.delete2(:to_line_end)",
  #    'C d e'=> 'buf.delete_to_next_word_end',
  "C d <num> e" => "buf.delete2(:to_word_end)", # d 3 e: repeated by the count
  "C d ' <char>" => "buf.delete2(:to_mark,<char>)",
  "C d f <char>" => "buf.delete2(:to_char,<char>)",
  "C d F <char>" => "buf.delete2(:to_char_backward,<char>)",
  "C d f space" => "buf.delete2(:to_char,' ')",
  "C d F space" => "buf.delete2(:to_char_backward,' ')",
  "C r <char>" => "buf.replace_with_char(<char>)", # TODO
  "C r space" => "buf.replace_with_char(' ')", # TODO
  "C , r <char>" => "vma.set_register(<char>)", # TODO
  "C , p <char>" => "buf.paste(BEFORE,<char>)", # TODO
  # Switch to another mode
  "C R" => "vma.kbd.set_mode(:replace)",
  # Replace mode
  "X esc || X ctrl!" => "vma.kbd.to_previous_mode",
  # "X p" => "edit.paste.over.after", #TODO
  "X ctrl-v" => "edit.paste.over.before",
  "X <char>" => "buf.replace_with_char(<char>);buf.move(FORWARD_CHAR)",
  "I ctrl-d" => "buf.delete2(:to_word_end)",
  "C d w" => "edit.delete.word.next",
  "C d 0" => "edit.delete.line.start",
  "C , ; a c" => "edit.complete.toggle",
}

add_keys "core cat:case", {
  "V g U" => "case.sel.upper",
  "V g u" => "case.sel.lower",
  "V g c" => "case.sel.capitalize",
  "V g s" => "case.sel.swap",
  "V U" => "case.sel.upper",
  "V u" => "case.sel.lower",
  "V ~" => "case.sel.swap",
  "C ~" => "case.char.toggle",
  "C g U w" => "case.word.upper",
  "C g u w" => "case.word.lower",
  "C g ~ w" => "case.word.swap",
  "C g U U" => "case.line.upper",
  "C g u u" => "case.line.lower",
  "C g ~ ~" => "case.line.swap",
}

add_keys "core cat:visual", {
  "V J" => "sel.join",
  "I shift-left" => "insert_select_move(BACKWARD_CHAR)",
  "I shift-right" => "insert_select_move(FORWARD_CHAR)",
  "I shift-down" => "insert_select_move(FORWARD_LINE)",
  "I shift-pagedown" => "insert_select_move(:pagedown)",
  "I shift-pageup" => "insert_select_move(:pageup)",
  "V y" => "buf.copy_active_selection()",
  "V a y" => "buf.copy_active_selection(:append)",
  "V g r" => "sel.reverse",
  "V g i" => "sel.unindent",
  "V g I" => "sel.unindent.common",
  "V g w" => "sel.convert.remove_extra_spaces",
  "C g w" => "sel.convert.remove_extra_spaces",
  "C g i" => "sel.unindent",
  "C g I" => "sel.unindent.common",
  "V x" => "buf.delete(SELECTION)",
  "V d" => ["sel.delete", proc { buf.delete(SELECTION) }, ""],
  "V a d" => ["sel.delete.append", proc { buf.delete(SELECTION, :append) }, "Delete and append selection"],
}

add_keys "core cat:marks", {
  # Marks
  "CV m <char>" => "buf.mark_current_position(<char>)",
  'CV \' <char>' => "buf.jump_to_mark(<char>)",
}

add_keys "core cat:macro", {
  "macro q" => "vma.kbd.to_previous_mode; vma.macro.end_recording",
  # "VC q(vma.macro.is_recording==true)" => "vma.macro.end_recording", # TODO: does not work
  # "VC o(vma.macro.is_recording==true)" => "vma.macro.end_recording", # TODO: does not work
  # "VC q q(vma.macro.is_recording==true)" => "vma.macro.end_recording",
  "VC q <char>" => "vma.kbd.set_mode(:macro);vma.macro.start_recording(<char>)",
  # 'C v'=> 'vma.macro.end_recording',
  # "C M" => 'vma.macro.run_last_macro',
  "C @ <char>" => "vma.macro.run_macro(<char>)",
  "C , m S" => 'vma.macro.save_macro("a")',
  "C , m s" => "vma.macro.save",
  "VC , m f" => ["macro.find", proc { vma.macro.find_macro_gui }, "Find named macro"],
  "C , m n" => ["macro.name", proc { vma.macro.gui_name_macro }, "Name last macro"],
}

add_keys "core cat:file", {
  "C , , f" => :file_finder,
  "C , , u" => "file.finder.reindex",
  "C , , c b" => "file.path.copy", #TODO: better binding or remove?,
  "C , f" => "file.finder",
  "C , h" => "file.history",
  "C , z" => "file.finder",
}

add_keys "core cat:buffer", {
  # File handling
  "C ctrl-s" => "buf.save",
  # Buffer handling
  # "C B" => "bufs.switch",
  "C tab" => "bufs.switch_to_last_buf",
  #    'C , s'=> 'gui_select_buffer',
  "C , r v b" => "buf.revert",
  "C , c b" => "bufs.close_current_buffer",
  "C , c s" => "bufs.close_scrap_buffers",
  "C , l b" => "load_buffer_list",
  "C , l l" => "save_buffer_list",
  # "I ctrl!" => "vma.kbd.to_previous_mode",
  "C shift! s" => "buf.save",
  "I ctrl-s" => "buf.save",
  "C , , ." => "buf.backup.all",
  "C z " => "mode.browse",
  "B h" => "buf.history.prev",
  "B l" => "buf.history.next",
  "B z" => "center_on_current_line();call_action('mode.browse.exit')",
  "B enter || B return || B esc || B j || B ctrl!" => "mode.browse.exit",
  "B r" => proc { vma.gui.page_down(multip: 0.25) },
  "B e" => proc { vma.gui.page_up(multip: 0.25) },
  "B c" => "buf.close",
  "C , s a" => "buf.save.as",
  "C , , e" => "buf.encrypt", #TODO: better binding,
  "C , ; u" => "buf.encrypt.off", #TODO: better binding,
  "C , c b" => "buf.close",
}

add_keys "core cat:view", {
  # prev/next file in file panel order (no-op while the panel is hidden)
  "C alt-h" => "panel.files.prev",
  "C alt-l" => "panel.files.next",
  # label the file panel rows, jump to a file by typing its label
  "C g s" => "panel.files.jump",
  "B p" => "panel.files.prev",
  "B n" => "panel.files.next",
  "C , w" => "view.columns.switch",
  "C , , w" => "view.columns.toggle",
}

add_keys "core cat:grep", {
  "C C" => "grep.files",
  "C , a" => "ack.search",
}

add_keys "core cat:code", {
  "C ctrl-c" => "buf.comment_line()",
  "C ctrl-x" => "buf.comment_line(:uncomment)",
  # "V ctrl-c" => "buf.comment_selection",
  "V ctrl-x" => "buf.comment_selection(:uncomment)",
  "C , v" => "edit.indent.buf",
  "V ctrl-c" => "edit.comment",
}

add_keys "core cat:app", {
  "C , e" => "mode.cmdline",
  "C :" => "mode.cmdline",
  # "CV Q" => "app.quit",
  "CV ctrl-q" => "app.quit",
  "C , R" => "app.restart",
}

add_keys "core cat:help", {
  "C , m h" => "help.messages",
  "C , ; s k" => "help.keys", #TODO: better binding,
}

add_keys "core cat:internal", {
  "R <char>" => "readchar_new_char(<char>)",
}

add_keys "hyperplaintext", {
  "V , t b" => "style.bold",
  "V , t l" => "style.link",
  "V , t i" => "style.italic",
  "V , t c" => "style.clear",
  "C , t h" => "style.line.heading",
  "C , t 1" => "style.line.h1",
  "C , t 2" => "style.line.h2",
  "C , t 3" => "style.line.h3",
  "C , t 4" => "style.line.h4",
  "C , t b" => "style.line.bold",
  "C , t t" => "style.line.title",
  "C , t i" => "style.line.italic",
  "C , t c" => "style.line.clear",
}

bindkey ["VCB M", "B m"], "macro.run.last"

add_keys "experimental", {
 "C ` k" => "lsp.debug",
 "C ` j" => "lsp.definition",
 "C ` r" => "lsp.restart",
 "C , u s" => "audio.stop",

  "C , t r" => "run_tests()",
  # "CV , R" => "restart_application", #TODO: does not work
  "I ctrl-h" => "edit.complete",
  "I ctrl-space" => "edit.complete",
  "C , d m" => "debug.kbd",
  "C , ; ." => "edit.word.increment",
  "C , d d" => "debug_dump_deltas",
  "C , d c" => "debug_dump_clipboard",
  "C , d b" => "debug_print_buffer",
  "C , D" => "debug_print_buffer",
  "C , d o" => "vma.gui.clear_overlay",
  # Debug
  "C , d r p" => 'require "pry"; binding.pry', #TODO
#bindkey 'C , g', proc{invoke_grep_search}
# bindkey "C , d", "buf.diff"
 "C , , d" => "debug.save",
 "C , m a" => "vma.kbd.set_mode(:audio)",
 "audio s" => "audio.stop",
}


bindkey "audio f || audio right", ["audio.forward", proc { Audio.seek_forward }, "Seek forward in audio stream"]
bindkey "audio left", ["audio.backward", proc { Audio.seek_forward(-5.0) }, "Seek backward in audio stream"]

bindkey "audio space", "audio.stop"
bindkey "audio q || audio esc", "vma.kbd.to_previous_mode"


bindkey "C , i p", "generate_password_to_buf(15)", keywords: "cat:edit"

# default_keys.each { |key, value|
  # bindkey(key, value)
# }

# Vim text objects (diw, ci", ya(, vip, ...), see text_objects.rb
bind_vim_text_objects

# Vim bindings from the shared table (vim_core.rb) that don't conflict with
# the bindings above; the rest are listed in doc/vimlike_vim_conflicts.md.
# Keep this last, so every vimlike binding counts as taken.
bind_vim_bindings(only_free: true)
end # module Vimamsa
