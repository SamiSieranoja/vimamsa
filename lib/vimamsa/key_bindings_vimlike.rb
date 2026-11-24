
module Vimamsa
vma.kbd.add_mode("C", :command)
vma.kbd.add_mode("I", :insert, :insert)
vma.kbd.add_mode("V", :visual, :visual)
vma.kbd.add_mode("M", :minibuffer) #TODO: needed?
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
  "VCX up" => "move.line.prev",
  "VCX down" => "move.line.next",
  "VCX right" => "move.char.next",
  "VCX left" => "move.char.prev",
  "VC l" => "move.char.next",
  "VC O" => "move.line.end",
  # NOTE: "G(condition)" need to be defined before "G"
  "VC G(vma.kbd.next_command_count!=nil)" => "move.line.goto",
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
  "V esc" => "mode.visual.exit",
  "V ctrl!" => "mode.visual.exit",
  "V tab" => "sel.indent.more",
  "V shift-tab" => "sel.indent.less",
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
  "I left" => "move.char.prev.unselect",
  "I right" => "move.char.next.unselect",
  "I down" => "move.line.next.unselect",
  "I up" => "move.line.prev.unselect",
  "I pagedown" => "move.page.next.unselect",
  "I pageup" => "move.page.prev.unselect",
  "VC /[1-9]/" => "kbd.count.digit",
  #    'VC number=/[0-9]/+ g'=> 'jump_to_line(<number>)',
  #    'VC X=/[0-9]/+ * Y=/[0-9]/+ '=> 'x_times_y(<X>,<Y>)',
  "VC 0(vma.kbd.next_command_count!=nil)" => "kbd.count.digit",
  "VC 0(vma.kbd.next_command_count==nil)" => "move.line.start",
  # 'C 0'=> 'buf.jump(BEGINNING_OF_LINE)',
  "VC ^" => "move.line.start",
  "VC $" => "move.line.end",
  "C ^" => "move.line.start",
  "VC j" => "move.line.next",
  "VC k" => "move.line.prev",
  # Insert and Replace modes: Moving
  "IX ctrl-f" => "move.char.next",
  "VC h" => "move.char.prev",
  "B s" => "move.page.prev",
  "B d" => "move.page.next",
  "B i" => "move.buf.start",
  "B o" => "move.buf.end",
  "C , j r" => "move.random",
}

add_keys "core cat:search", {
  "VC f <char>" => "jump.char.next",
  "VC F <char>" => "jump.char.prev",
  "VC f space" => "jump.space.next",
  "VC F space" => "jump.space.prev",
  #    'VC z z' => 'center_on_current_line',
  "VC *" => "search.word.next",
  "VC /" => "search.buf",
  "C n" => "search.next",
  "C N" => "search.prev",
  "VC ;" => "jump.char.repeat",
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
  "I tab(vma.buf.view.autocp_active)" => "edit.complete.next",
  # "I up(vma.buf.view.autocp_active)" => "vma.buf.view.autocp_select_previous",
  "I shift-tab(vma.buf.view.autocp_active)" => "edit.complete.prev",
  "I shift!(vma.buf.view.autocp_active)" => "edit.complete.accept",
  # Typing a character. Reached both from a key press and from an input method
  # commit (AltGr, dead keys, compose — those produce no key press at all, see
  # VSourceView#register_buffer_signals), so insertion lives here rather than in
  # the GUI layer.
  "I <char>" => "edit.insert.char",
  "I tab" => "edit.tab",
  "I shift-tab" => "edit.untab",
  "C o" => "mode.insert.line.below",
  "C X" => "edit.line.below",
  "C A" => "mode.insert.line.end",
  "C I" => "mode.insert.line.start",
  "C a" => "mode.insert.after",
  # Command mode only:
  "C space <char>" => "edit.insert.char",
  "C space space" => "edit.insert.space",
  "I ctrl-j" => "edit.complete.hide",
  "I space" => "edit.insert.space",
}

add_keys "core cat:edit", {
  "I enter" => "edit.newline",
  "C J" => "edit.line.join",
  "C y O" => "edit.copy.line.end",
  "C y 0" => "edit.copy.line.start",
  "C y e" => "edit.copy.word.end",
  "C y ' <char>" => "edit.copy.mark",
  #### Deleting
  # "C x" => "buf.delete(CURRENT_CHAR_FORWARD)",
  # 'C d d'=> 'buf.delete_cur_line',
  "C d e" => "edit.delete.word.end",
  "C d O" => "edit.delete.eol",
  "C d $" => "edit.delete.eol",
  #    'C d e'=> 'buf.delete_to_next_word_end',
  "C d <num> e" => "edit.delete.word.end", # d 3 e: repeated by the count
  "C d ' <char>" => "edit.delete.mark",
  "C d f <char>" => "edit.delete.find.next",
  "C d F <char>" => "edit.delete.find.prev",
  "C d f space" => "edit.delete.space.next",
  "C d F space" => "edit.delete.space.prev",
  "C r <char>" => "edit.replace.char",
  "C r space" => "edit.replace.space",
  "C , r <char>" => "edit.register",
  "C , p <char>" => "edit.paste.register",
  # Switch to another mode
  "C R" => "mode.replace",
  # Replace mode
  "X esc || X ctrl!" => "mode.prev",
  "X ctrl-v" => "edit.paste.over.before",
  "X <char>" => "edit.replace.char.next",
  "I ctrl-d" => "edit.delete.word.end",
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
  "V , J <char>" => "sel.join.char",
  "I shift-left" => "sel.char.prev",
  "I shift-right" => "sel.char.next",
  "I shift-down" => "sel.line.next",
  "I shift-pagedown" => "sel.page.next",
  "I shift-pageup" => "sel.page.prev",
  "V y" => "sel.copy",
  "V a y" => "sel.copy.append",
  "V g r" => "sel.reverse",
  "V g i" => "sel.unindent",
  "V g I" => "sel.unindent.common",
  "V g w" => "sel.convert.remove_extra_spaces",
  "C g w" => "sel.convert.remove_extra_spaces",
  "C g i" => "sel.unindent",
  "C g I" => "sel.unindent.common",
  "V x" => "sel.cut",
  "V d" => "sel.delete",
  "V a d" => "sel.delete.append",
}

add_keys "core cat:marks", {
  # Marks
  "CV m <char>" => "mark.set",
  'CV \' <char>' => "mark.jump",
}

add_keys "core cat:macro", {
  "macro q" => "macro.record.stop",
  # "VC q q(vma.macro.is_recording==true)" => "vma.macro.end_recording",
  "VC q <char>" => "macro.record",
  # 'C v'=> 'vma.macro.end_recording',
  # "C M" => 'vma.macro.run_last_macro',
  "C @ <char>" => "macro.run",
  "C , m S" => "macro.save.a",
  "C , m s" => "macro.save",
  "VC , m f" => ["macro.find", proc { vma.macro.find_macro_gui }, "Find named macro"],
  "C , m n" => ["macro.name", proc { vma.macro.gui_name_macro }, "Name last macro"],
}

add_keys "core cat:file", {
  "C , , f" => "file.finder",
  "C , , u" => "file.finder.reindex",
  "C , y p" => "file.path.copy",
  "C , f" => "file.finder",
  "C , h" => "file.history",
  "C , z" => "file.finder",
}

add_keys "core cat:buffer", {
  # File handling
  "C ctrl-s" => "buf.save",
  # Buffer handling
  # "C B" => "bufs.switch",
  "C tab" => "buf.switch.last",
  #    'C , s'=> 'gui_select_buffer',
  "C , r v b" => "buf.revert",
  "C , c s" => "buf.close.scrap",
  "C , l b" => "buf.list.load",
  "C , l l" => "buf.list.save",
  # "I ctrl!" => "vma.kbd.to_previous_mode",
  "C shift! s" => "buf.save",
  "I ctrl-s" => "buf.save",
  "C , , ." => "buf.backup.all",
  "C z " => "mode.browse",
  "B h" => "buf.history.prev",
  "B l" => "buf.history.next",
  "B z" => "mode.browse.center",
  "B enter || B return || B esc || B j || B ctrl!" => "mode.browse.exit",
  "B r" => "move.page.next.quarter",
  "B e" => "move.page.prev.quarter",
  "B c" => "buf.close",
  "C , s a" => "buf.save.as",
  "C , , e" => "buf.encrypt",
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
  # "C C" => "grep.files",
  "C , a" => "ack.search",
}

add_keys "core cat:code", {
  "C ctrl-c" => "edit.comment.line",
  "C ctrl-x" => "edit.comment.line.off",
  # "V ctrl-c" => "buf.comment_selection",
  "V ctrl-x" => "edit.comment.off",
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
  "C , ; s k" => "help.keys",
}

add_keys "core cat:internal", {
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

  "C , t r" => "debug.tests",
  "I ctrl-h" => "edit.complete",
  "I ctrl-space" => "edit.complete",
  "C , d m" => "debug.kbd",
  "C , ; ." => "edit.word.increment",
  "C , d d" => "debug.deltas",
  "C , d c" => "debug.clipboard",
  "C , d b" => "debug.buf.print",
  "C , D" => "debug.buf.print",
  "C , d o" => "debug.overlay.clear",
  # Debug
  "C , d r p" => "debug.pry",
#bindkey 'C , g', proc{invoke_grep_search}
# bindkey "C , d", "buf.diff"
 "C , , d" => "debug.save",
}


bindkey "C , i p", "edit.insert.password", keywords: "cat:edit"

# default_keys.each { |key, value|
  # bindkey(key, value)
# }

# vimlike's own motion O (end of line) also works after the Vim operators
# (c O, g U O, > O, ...; vim_operators.rb)
vma.kbd.key_set_add(:motion, "O" => :line_end)

# Vim bindings from the shared table (key_bindings_vim_core.rb) that don't conflict with
# the bindings above; the rest are listed in doc/vimlike_vim_conflicts.md.
# Keep this last, so every vimlike binding counts as taken.
bind_vim_bindings(only_free: true)
end # module Vimamsa
