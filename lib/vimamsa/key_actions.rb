
module Vimamsa
def history_switch_backwards
  bufs.history_switch_backwards
end

def history_switch_forwards
  bufs.history_switch_forwards
end

def jump_to_next_edit
  buf.jump_to_next_edit
end


reg_act("debug.command", proc { command_to_buf }, "Execute command, output to buffer")

reg_act("lsp.debug", proc { vma.buf.lsp_get_def }, "LSP get definition")
reg_act("lsp.definition", proc { vma.buf.lsp_jump_to_def }, "LSP jump to definition")
reg_act("lsp.restart", proc { require "vimamsa/langservp"; lsp_restart },
        "LSP: restart the language server of the current file (e.g. after adding compile_flags.txt)")

reg_act("debug.eval.buf", proc { vma.buf.eval_whole_buf }, "Eval whole current buffer as ruby code (DANGEROUS)")

reg_act("app.settings", proc { show_settings_dialog }, "Show settings")
reg_act("view.colors.reload", proc { gui_reload_theme_and_colors }, "Reload theme color palettes + config and refresh the UI (no restart)")
reg_act("sel.cut", proc { buf.delete(SELECTION) }, "Cut selection to clipboard")

reg_act("edit.backspace", proc { buf.selection_active? ? buf.delete(SELECTION) : buf.delete(BACKWARD_CHAR) }, "Delete backwards")
reg_act("edit.delete.char_or_sel", proc { buf.selection_active? ? buf.delete(SELECTION) : buf.delete(CURRENT_CHAR_FORWARD) }, "Delete forward (selection-aware)")
reg_act("sel.all", proc { buf.select_all }, "Select all text")
reg_act("sel.line.prev", proc { insert_select_move(BACKWARD_LINE) }, "Select texte upwards")
reg_act("sel.line.next", proc { insert_select_move(FORWARD_LINE) }, "Select text downwards")

reg_act("sel.copy", proc { buf.copy_active_selection }, "Copy selection to clipboard")
reg_act("debug.on", proc { cnf.debug = true }, "Enable debug")
reg_act("debug.off", proc { cnf.debug = false }, "Disable debug")

reg_act("debug.eval.sel", proc { bindkey "V , e", "vma.buf.convert_selected_text(:eval)" }, "Enable key binding:\"[VISUAL] , e:\" Eval selected text")

reg_act("jump.easy", proc { EasyJump.start }, "Easy jump")
reg_act("view.cursor.show", proc { vma.gui.view.ensure_cursor_visible }, "Scroll to current cursor position")
reg_act("view.cursor.refresh", proc { vma.buf.refresh_cursor }, "Refresh cursor")

reg_act("debug.save", "savedebug", "Save debug info")
reg_act("file.open", "open_file_dialog", "Open file")
reg_act("buf.backup.all", proc { backup_all_buffers }, "Backup all buffers")
reg_act("move.char.next", proc { buf.move(FORWARD_CHAR) }, "Move forward one character")
reg_act("move.char.prev", proc { buf.move(BACKWARD_CHAR) }, "Move backward one character")
reg_act("move.line.next", proc { buf.move(FORWARD_LINE) }, "Move one line forward")
reg_act("move.line.prev", proc { buf.move(BACKWARD_LINE) }, "Move one line backward")
# reg_act("buf.history.prev", proc{bufs.history_switch_backwards}, "")
reg_act("buf.history.prev", proc { bufs.history_switch(-1) }, "Prev buffer")
reg_act("buf.history.next", proc { bufs.history_switch(+1) }, "Next buffer")
reg_act("debug.buf.access", proc { bufs.print_by_access_time }, "Print buffers by access time")
reg_act("view.center", "center_on_current_line", "Center the view on the cursor line")
reg_act("macro.run.last", proc { vma.macro.run_last_macro }, "Run last recorded or executed macro")
reg_act("jump.edit.next", "jump_to_next_edit", "Jump to next edit pos")
reg_act("jump.edit.prev", proc { buf.jump_to_last_edit }, "Jump to the last edit location")
reg_act("move.random", proc { buf.jump_to_random_pos }, "Jump to a random position")
reg_act("edit.newline", proc { buf.insert_new_line() }, "Insert new line")
reg_act("help.keys", proc { show_key_bindings }, "Show key bindings")
reg_act("help.keys.free", proc { show_free_key_bindings }, "Show available (unbound) key binding slots")
reg_act("help.vim_conflicts", proc { show_vim_binding_conflicts }, "Show which vim key bindings conflict with the vimlike keymap")
reg_act("file.path.copy", proc { buf.put_file_path_to_clipboard }, "Put file path of current file to clipboard")
reg_act("file.ref.copy", proc { buf.put_file_ref_to_clipboard }, "Put file ref of current file to clipboard")

# reg_act("buf.encrypt", proc{buf.set_encrypted},"Set current file to encrypt on save")
reg_act("buf.encrypt", proc { encrypt_cur_buffer }, "Set current file to encrypt on save")
reg_act("buf.encrypt.off", proc { buf.set_unencrypted }, "Set current file to save unencrypted")
reg_act("file.executable", proc { buf.set_executable }, "Set current file permissions to executable")
# reg_act("buf.close.all", proc { bufs.close_all_buffers() }, "Close all buffers")
reg_act("buf.close", proc { bufs.close_current_buffer(true) }, "Close current buffer")
reg_act("panel.files.toggle", proc { vma.gui.toggle_file_panel }, "Toggle file panel")
reg_act("panel.files.prev", proc { vma.gui.file_panel_select_adjacent(-1) }, "Switch to previous file in file panel order")
reg_act("panel.files.next", proc { vma.gui.file_panel_select_adjacent(1) }, "Switch to next file in file panel order")
reg_act("panel.files.jump", proc { vma.gui.file_panel_easy_jump }, "Easy jump: pick a file in the file panel by label")
reg_act("help.messages", proc { vma.gui.show_message_history }, "Show message history")
reg_act("mode.cmdline", proc { vma.gui.cmd_line.start }, "Open command line (:)")
reg_act("panel.funcs.toggle", proc { vma.gui.toggle_func_panel }, "Toggle LSP function panel")
reg_act("panel.funcs.refresh", proc { vma.gui.func_panel_refresh }, "Refresh LSP function panel")
reg_act("panel.keylog.toggle", proc { vma.gui.toggle_keylog_panel }, "Toggle key log panel")
reg_act("file.diff.repo", proc { git_diff_w }, "Show git diff -w for whole repository")
reg_act("lsp.functions", proc { lsp_print_functions }, "LSP print functions in current file")
reg_act("edit.comment", proc { buf.comment_selection }, "Comment selection")
reg_act("edit.delete.char", proc { buf.delete(CURRENT_CHAR_FORWARD) }, "Delete char forward")
reg_act("file.finder", proc { vma.FileFinder.start_gui }, "Fuzzy file finder")
reg_act("file.history", proc { vma.FileHistory.start_gui }, "Fuzzy file history finder")
reg_act("search.replace", proc { gui_search_replace }, "Search and replace")
reg_act("buf.language", proc { gui_select_buffer_language }, "Select syntax highlighting language for current buffer")
reg_act("search.next", proc { $search.jump_to_next() }, "Find next")

reg_act("style.bold", proc { buf.style_transform(:bold) }, "Set text weight to bold")
reg_act("style.link", proc { buf.style_transform(:link) }, "Set text as link")
reg_act("style.italic", proc { buf.style_transform(:italic) }, "Set text style to italic")
reg_act("sel.join", proc { vma.buf.convert_selected_text(:joinlines) }, "Join lines")
reg_act("sel.latex_itemize", proc { vma.buf.convert_selected_text(:latex_itemize) }, "Convert selection to LaTeX itemize list")
reg_act("style.clear", proc { buf.style_transform(:clear) }, "Clear style formats")
reg_act("style.line.heading", proc { buf.set_line_style(:heading) }, "Set style of current line as heading")
reg_act("style.line.h1", proc { buf.set_line_style(:h1) }, "Set cur line as Heading 1")
reg_act("style.line.h2", proc { buf.set_line_style(:h2) }, "Set cur line as Heading 1")
reg_act("style.line.h3", proc { buf.set_line_style(:h3) }, "Set cur line as Heading 1")
reg_act("style.line.h4", proc { buf.set_line_style(:h4) }, "Set cur line as Heading 1")
reg_act("style.line.bold", proc { buf.set_line_style(:bold) }, "Set style of current line as bold")
reg_act("style.line.title", proc { buf.set_line_style(:title) }, "Set style of current line as title")
reg_act("style.line.italic", proc { buf.set_line_style(:italic) }, "Set style of current line as italic")
reg_act("style.line.clear", proc { buf.set_line_style(:clear) }, "Clear styles of current line")
reg_act("buf.switcher", proc { vma.kbd.set_mode("S"); gui_select_buffer }, "Select buffer")
reg_act "mode.minibuffer.end", proc { minibuffer_end }
reg_act("search.replace.cmd", "invoke_replace", "Invoke replace")
reg_act("buf.diff", "diff_buffer", "")
reg_act("buf.diff.git", proc { git_diff_buffer }, "Show git diff of current file")
reg_act("diffview.source", proc { diff_buffer_jump_to_source }, "Jump to corresponding line in source from diff buffer")
reg_act("file.links", proc {
  links = buf.file_links
  if links.empty?
    message("No links to existing files")
  else
    # One absolute path per line: enter on a line opens the file
    create_new_buffer(links.join("\n") + "\n", "filelinks")
    message("#{links.size} file link(s)")
  end
}, "Extract links to existing files from current file into a new buffer")
reg_act("jump.file", proc {
  # Like vim gf, and the "Open file" items of the right-click menu
  fn = buf.file_path_at(buf.pos)
  if fn.nil?
    message("No file under cursor")
  elsif file_is_text_file(fn)
    open_new_file(fn)
  else
    open_with_default_program(fn)
  end
}, "Open file whose path is under the cursor")
reg_act "file.finder.reindex", proc { FileFinder.update_index }, "Update file index"
reg_act "edit.delete.word.end", proc { buf.delete2(:to_word_end) }, "Delete to the end of the word"
reg_act "edit.delete.word.next", proc { buf.delete2(:to_next_word) }, "Delete to start of next word"
reg_act "edit.delete.line.start", proc { buf.delete2(:to_line_start) }, "Delete to line start"

reg_act("ack.search", proc { gui_ack }, "Search file contents with ack (external program)")

reg_act("edit.line.copy", proc { buf.copy_line }, "Copy the current line")
reg_act("edit.paste.before", proc { buf.paste(BEFORE) }, "Paste text before the cursor")
reg_act("edit.paste.after", proc { buf.paste(AFTER) }, "Paste text after the cursor")
reg_act("edit.paste.over.after", proc { buf.paste_over(AFTER) }, "Paste over selection or after cursor")
reg_act("edit.paste.over.before", proc { buf.paste_over(BEFORE) }, "Paste over selection or before cursor")
reg_act("undo.redo", proc { buf.redo() }, "Redo the last undone action")
reg_act("undo.last", proc { buf.undo() }, "Undo the last action")
reg_act("move.line.end", proc { buf.jump(END_OF_LINE) }, "Move to the end of the current line")
reg_act("move.buf.end", proc { buf.jump(END_OF_BUFFER) }, "Move to the end of the buffer")
reg_act("move.buf.start", proc { buf.jump(START_OF_BUFFER) }, "Move to the start of the buffer")
reg_act("move.line.start", proc { buf.jump(BEGINNING_OF_LINE) }, "Move to the beginning of the current line")
reg_act("move.word.end", proc { buf.jump_word(FORWARD, WORD_END) }, "Jump to the end of the next word")
reg_act("move.word.prev", proc { buf.jump_word(BACKWARD, WORD_START) }, "Jump to the start of the previous word")
reg_act("move.word.next", proc { buf.jump_word(FORWARD, WORD_START) }, "Jump to the start of the next word")
reg_act("mode.insert", proc { vma.kbd.set_mode(:insert) }, "Switch to INSERT mode")
reg_act("mode.prev", proc { vma.kbd.to_previous_mode }, "Return to the previous mode")
reg_act("mode.visual", proc { buf.start_selection; vma.kbd.set_mode(:visual) }, "Enter VISUAL mode (for selections)")
reg_act("app.demo", proc { install_demo_files }, "Install and show Demo")
reg_act("help.demo", proc { DemoPlayer.toggle(:basic) }, "Play the basic editing demo (again: stop it)")
reg_act("help.demo.easyjump", proc { DemoPlayer.toggle(:easyjump) }, "Play the easy jump demo (again: stop it)")
reg_act("help.demo.files", proc { DemoPlayer.toggle(:files) }, "Play the file switching demo (again: stop it)")
reg_act("help.demo.pause", proc { DemoPlayer.pause_toggle }, "Pause or continue the demo")
reg_act("help.demo.faster", proc { DemoPlayer.faster }, "Play the demo faster")
reg_act("help.demo.slower", proc { DemoPlayer.slower }, "Play the demo slower")
reg_act("help.demo.stop", proc { DemoPlayer.stop }, "Stop the demo")
reg_act("help.intro", proc { show_help_page("intro") }, "Show the introduction page")
reg_act("help.vim_intro", proc { show_help_page("vim_intro") }, "Show the main differences from Vim")
reg_act("help.intro.startup.toggle", proc { toggle_intro_on_startup }, "Show the introduction page at start, or not")
reg_act("app.customrb.reload", proc { reload_customrb }, "Reload custom.rb")

reg_act("edit.complete.toggle", proc {
  cnf.autocomplete.enabled = !(cnf.autocomplete.enabled? != false)
  vma.buf&.view&.hide_completions unless cnf.autocomplete.enabled?
  message("Autocomplete: #{cnf.autocomplete.enabled? ? "ON" : "OFF"}")
}, "Toggle autocomplete on/off")

reg_act("app.restart", proc { restart_editor }, "Restart: quit, reload config and reopen files")

reg_act "mode.browse", proc {
  vma.kbd.set_mode(:browse)
  bufs.reset_navigation
}, "Start browse mode"
reg_act "debug.kbd", proc { vma.kbd.dump_state; pp ["vma.buf.mode_stack", vma.buf.mode_stack] }, "Dump keyboard tree state"
reg_act "mode.passthrough.toggle", proc {
  vma.gui.instance_variable_set(:@kbd_passthrough, !vma.gui.instance_variable_get(:@kbd_passthrough))
  state = vma.gui.instance_variable_get(:@kbd_passthrough) ? "ON" : "OFF"
  message("Keyboard passthrough: #{state}")
}, "Toggle keyboard event passthrough (allow other widgets to receive key events)"

reg_act "mode.browse.exit", proc {
  bufs.add_current_buf_to_history
  # Load previously saved buffer specific mode stack
  buf.restore_kbd_mode
}, "Exit browse mode"

# reg_act "move.page.next", proc { page_down }, "Page down"
reg_act "move.page.next", proc { vma.gui.page_down }, "Page down"

reg_act "move.page.prev", proc { vma.gui.page_up }, "Page up"
reg_act("edit.indent.buf", proc { buf.auto_format }, "Auto format buffer")
reg_act("term.line", proc { buf.execute_current_line_in_terminal }, "Execute current line in terminal")
reg_act("term.line.autoclose", proc { buf.execute_current_line_in_terminal(true) }, "Execute current line in terminal. Close after execution.")
reg_act("style.images", proc { hpt_scan_images() }, "Show images inserted with ⟦img:file.png⟧ syntax")
reg_act("file.delete", proc { bufs.delete_current_buffer() }, "Delete current file")

reg_act("audio.stop", proc { Audio.stop }, "Stop audio playback")

act_list = {
  # File handling
  "buf.save" => { :proc => proc { buf.save },
                 :desc => "Save buffer" },

  "buf.save.as" => { :proc => proc { buf.save_as },
                    :desc => "Save file as" },
  "buf.new" => { :proc => proc { create_new_file() }, :desc => "Create a new file" },
  "buf.revert" => { :proc => proc { buf.revert },
                   :desc => "Reload file from disk" },
  "buf.backup" => { :proc => proc { buf.backup() }, :desc => "Backup current file" },

  "search.buf" => { :proc => proc { invoke_search },
                       :desc => "Find" },

  "case.sel.upper" => { :proc => proc { buf.transform_selection(:upcase) },
                         :desc => "Transform text: upcase" },

  "case.sel.lower" => { :proc => proc { buf.transform_selection(:downcase) },
                           :desc => "Transform text: downcase" },

  "case.sel.capitalize" => { :proc => proc { buf.transform_selection(:capitalize) },
                             :desc => "Transform text: capitalize" },

  "case.sel.swap" => { :proc => proc { buf.transform_selection(:swapcase) },
                           :desc => "Transform text: swapcase" },

  "sel.reverse" => { :proc => proc { buf.transform_selection(:reverse) },
                          :desc => "Transform text: reverse" },

  "sel.unindent" => { :proc => proc { buf.remove_indent_selection },
                                :desc => "Remove indentation from selected lines (or current line)" },

  "sel.unindent.common" => { :proc => proc { buf.remove_common_indent_selection },
                                       :desc => "Remove indentation common to all selected lines (keeps relative indent)" },

  "case.word.upper" => { :proc => proc { buf.transform_range(:to_next_word, :upcase) },
                    :desc => "Upcase to start of next word (vim gUw)" },

  "case.word.lower" => { :proc => proc { buf.transform_range(:to_next_word, :downcase) },
                      :desc => "Downcase to start of next word (vim guw)" },

  "case.word.swap" => { :proc => proc { buf.transform_range(:to_next_word, :swapcase) },
                      :desc => "Swap case to start of next word (vim g~w)" },

  "case.line.upper" => { :proc => proc { buf.transform_range(:line, :upcase) },
                    :desc => "Upcase current line (vim gUU)" },

  "case.line.lower" => { :proc => proc { buf.transform_range(:line, :downcase) },
                      :desc => "Downcase current line (vim guu)" },

  "case.line.swap" => { :proc => proc { buf.transform_range(:line, :swapcase) },
                      :desc => "Swap case of current line (vim g~~)" },

  "case.char.toggle" => { :proc => proc {
    b = buf
    c = b.current_char
    if !c.nil? and c != "\n"
      b.replace_with_char(c.swapcase) # does not advance the cursor
      b.move(FORWARD_CHAR)            # vim ~ advances, even on non-letters
    end
  }, :desc => "Toggle case of char and advance (vim ~)" },

  "edit.word.increment" => { :proc => proc { buf.increment_current_word },
                       :desc => "Increment word" },

  # { :proc => proc {  },
  # :desc => "" },

  "search.actions" => { :proc => proc { vma.actions.gui_search },
                       :desc => "Search actions" },

  "app.customrb.edit" => { :proc => proc { jump_to_file("~/.config/vimamsa/custom.rb") },
                      :desc => "Customize (edit custom.rb)" },

  "view.columns.switch" => { :proc => proc { vma.gui.toggle_active_window },
                             :desc => "Switch active column in two column mode" },

  "view.columns.toggle" => { :proc => proc { vma.gui.toggle_two_column },
                          :desc => "Toggle two column mode" },

  "grep.files" => { :proc => proc { FileContentSearch.start_gui },
                       :desc => "Search content of files" },

  "app.quit" => { :proc => proc { _quit },
             :desc => "Quit" },

  "debug.tests" => { :proc => proc { run_tests },
                  :desc => "Run tests" },

  "debug.buf.sha256" => { :proc => proc { puts "SHA256: " + (Digest::SHA2.hexdigest vma.buf.to_s) },
                      :desc => "Output SHA256 hex digest of curent buffer" },

  "edit.complete" => { :proc => proc { vma.buf.view.autocp_manual_trigger },
                              :desc => "Trigger autocomplete" },

}

for k, v in act_list
  reg_act(k, v[:proc], v[:desc])
end

# ── Actions that were Ruby-code bindings (doc/action_names_plan.md step 6) ──
# An action bound to a "<char>" key gets the typed character as its argument
# (KeyBindingTree runs it as a.<id>!('<char>')).

reg_act("move.line.goto", proc { buf.jump_to_line() }, "Go to line <count>")
reg_act("move.line.first_char", proc { buf.jump(FIRST_NON_WHITESPACE) }, "Move to the first non-blank character of the line")
reg_act("move.page.next.quarter", proc { vma.gui.page_down(multip: 0.25) }, "Scroll down a quarter page")
reg_act("move.page.prev.quarter", proc { vma.gui.page_up(multip: 0.25) }, "Scroll up a quarter page")
reg_act("move.page.next.cursor", proc { buf.move(:forward_page) }, "Move the cursor to the bottom of the view and scroll")
reg_act("move.page.prev.cursor", proc { buf.move(:backward_page) }, "Move the cursor to the top of the view and scroll")
# Insert mode: a plain arrow key ends a shift-arrow selection
reg_act("move.char.next.unselect", proc { insert_move(FORWARD_CHAR) }, "Move forward one character, ending the selection")
reg_act("move.char.prev.unselect", proc { insert_move(BACKWARD_CHAR) }, "Move backward one character, ending the selection")
reg_act("move.line.next.unselect", proc { insert_move(FORWARD_LINE) }, "Move one line forward, ending the selection")
reg_act("move.line.prev.unselect", proc { insert_move(BACKWARD_LINE) }, "Move one line backward, ending the selection")
reg_act("move.page.next.unselect", proc { insert_move(:pagedown) }, "Page down, ending the selection")
reg_act("move.page.prev.unselect", proc { insert_move(:pageup) }, "Page up, ending the selection")
reg_act("move.line.start.unselect", proc { buf.end_selection; buf.jump(BEGINNING_OF_LINE) }, "Move to the beginning of the line, ending the selection")
reg_act("move.line.end.unselect", proc { buf.end_selection; buf.jump(END_OF_LINE) }, "Move to the end of the line, ending the selection")

reg_act("kbd.count.digit", proc { |c| vma.kbd.set_next_command_count(c) }, "Type a digit of the repeat count")

reg_act("jump.char.next", proc { |c| buf.jump_to_next_instance_of_char(c) }, "Jump to the next <char>")
reg_act("jump.char.prev", proc { |c| buf.jump_to_next_instance_of_char(c, BACKWARD) }, "Jump to the previous <char>")
reg_act("jump.space.next", proc { buf.jump_to_next_instance_of_char(" ") }, "Jump to the next space")
reg_act("jump.space.prev", proc { buf.jump_to_next_instance_of_char(" ", BACKWARD) }, "Jump to the previous space")
reg_act("jump.char.repeat", proc { repeat_last_find }, "Repeat the last character jump (f, F)")
reg_act("search.prev", proc { $search.jump_to_previous() }, "Find previous")
reg_act("search.word.next", proc { buf.jump_to_next_instance_of_word }, "Find the next occurrence of the word under the cursor")

reg_act("mode.insert.after", proc { buf.move(FORWARD_CHAR); vma.kbd.set_mode(:insert) }, "Switch to INSERT mode after the cursor")
reg_act("mode.insert.line.start", proc { buf.jump(FIRST_NON_WHITESPACE); vma.kbd.set_mode(:insert) }, "Switch to INSERT mode at the first non-blank character of the line")
reg_act("mode.insert.line.end", proc { buf.jump(END_OF_LINE); vma.kbd.set_mode(:insert) }, "Switch to INSERT mode at the end of the line")
reg_act("mode.insert.line.below", proc { buf.jump(END_OF_LINE); buf.insert_txt("\n"); vma.kbd.set_mode(:insert) }, "Open a new line below and switch to INSERT mode")
reg_act("mode.replace", proc { vma.kbd.set_mode(:replace) }, "Switch to REPLACE mode")
reg_act("mode.visual.exit", proc { buf.end_visual_mode }, "Leave VISUAL mode")
reg_act("mode.audio", proc { vma.kbd.set_mode(:audio) }, "Switch to audio playback mode")
reg_act("mode.browse.center", proc { center_on_current_line(); call_action("mode.browse.exit") }, "Center on the cursor line and leave browse mode")

reg_act("edit.insert.char", proc { |c| buf.insert_txt(c) }, "Insert <char>")
reg_act("edit.insert.space", proc { buf.insert_txt(" ") }, "Insert a space")
reg_act("edit.insert.password", proc { generate_password_to_buf(15) }, "Insert a random 15-character password")
reg_act("edit.tab", proc { buf.insert_tab }, "Insert a tab or spaces (indents the selection in VISUAL mode)")
reg_act("edit.untab", proc { buf.unindent }, "Unindent the current line one level")
reg_act("edit.line.below", proc { buf.jump(END_OF_LINE); buf.insert_txt("\n") }, "Insert an empty line below")
reg_act("edit.line.join", proc { buf.join_lines() }, "Join the next line to the current line")
reg_act("edit.copy.line.end", proc { buf.copy(:to_line_end) }, "Copy to the end of the line")
reg_act("edit.copy.line.start", proc { buf.copy(:to_line_start) }, "Copy to the start of the line")
reg_act("edit.copy.word.end", proc { buf.copy(:to_word_end) }, "Copy to the end of the word")
reg_act("edit.copy.word.next", proc { buf.copy(:to_next_word) }, "Copy to the start of the next word")
reg_act("edit.copy.mark", proc { |c| buf.copy(:to_mark, c) }, "Copy to mark <char>")
reg_act("edit.delete.mark", proc { |c| buf.delete2(:to_mark, c) }, "Delete to mark <char>")
reg_act("edit.delete.find.next", proc { |c| buf.delete2(:to_char, c) }, "Delete up to the next <char>")
reg_act("edit.delete.find.prev", proc { |c| buf.delete2(:to_char_backward, c) }, "Delete back to the previous <char>")
reg_act("edit.delete.space.next", proc { buf.delete2(:to_char, " ") }, "Delete up to the next space")
reg_act("edit.delete.space.prev", proc { buf.delete2(:to_char_backward, " ") }, "Delete back to the previous space")
reg_act("edit.replace.char", proc { |c| buf.replace_with_char(c) }, "Replace the character under the cursor with <char>")
reg_act("edit.replace.space", proc { buf.replace_with_char(" ") }, "Replace the character under the cursor with a space")
reg_act("edit.replace.char.next", proc { |c| buf.replace_with_char(c); buf.move(FORWARD_CHAR) }, "Replace the character under the cursor with <char> and move forward")
reg_act("edit.register", proc { |c| vma.set_register(c) }, "Use register <char> for the next copy, delete or paste")
reg_act("edit.paste.register", proc { |c| buf.paste(BEFORE, c) }, "Paste from register <char> before the cursor")
reg_act("edit.insert.register", proc { |c| buf.insert_register(c) }, "Insert the text of register <char>")
reg_act("edit.register.list", proc { show_registers }, "Show the registers")
reg_act("edit.comment.line", proc { buf.comment_line() }, "Comment the current line")
reg_act("edit.comment.line.off", proc { buf.comment_line(:uncomment) }, "Uncomment the current line")
reg_act("edit.comment.off", proc { buf.comment_selection(:uncomment) }, "Uncomment the selection")
reg_act("edit.complete.next", proc { vma.buf.view.autocp_select_next }, "Select the next completion")
reg_act("edit.complete.prev", proc { vma.buf.view.autocp_select_previous }, "Select the previous completion")
reg_act("edit.complete.accept", proc { vma.buf.view.autocp_select }, "Insert the selected completion")
reg_act("edit.complete.hide", proc { vma.buf.view.hide_completions }, "Hide the completion popup")

reg_act("sel.char.next", proc { insert_select_move(FORWARD_CHAR) }, "Extend the selection one character forward")
reg_act("sel.char.prev", proc { insert_select_move(BACKWARD_CHAR) }, "Extend the selection one character backward")
reg_act("sel.page.next", proc { insert_select_move(:pagedown) }, "Extend the selection a page down")
reg_act("sel.page.prev", proc { insert_select_move(:pageup) }, "Extend the selection a page up")
reg_act("sel.line.start", proc { buf.continue_selection; buf.jump(BEGINNING_OF_LINE) }, "Extend the selection to the beginning of the line")
reg_act("sel.line.end", proc { buf.continue_selection; buf.jump(END_OF_LINE) }, "Extend the selection to the end of the line")
reg_act("sel.delete", proc { buf.delete(SELECTION) }, "Delete the selection")
reg_act("sel.delete.append", proc { buf.delete(SELECTION, :append) }, "Delete the selection and append it to the clipboard")
reg_act("sel.copy.append", proc { buf.copy_active_selection(:append) }, "Append the selection to the clipboard")
reg_act("sel.indent.more", proc { buf.indent_selection }, "Indent the selected lines one level")
reg_act("sel.indent.less", proc { buf.unindent_selection }, "Unindent the selected lines one level")

reg_act("mark.set", proc { |c| buf.mark_current_position(c) }, "Set mark <char> at the cursor")
reg_act("mark.jump", proc { |c| buf.jump_to_mark(c) }, "Jump to mark <char>")

reg_act("macro.record", proc { |c| vma.kbd.set_mode(:macro); vma.macro.start_recording(c) }, "Record a macro into register <char>")
reg_act("macro.record.stop", proc { vma.kbd.to_previous_mode; vma.macro.end_recording }, "Stop recording the macro")
reg_act("macro.run", proc { |c| vma.macro.run_macro(c) }, "Run macro <char>")
reg_act("macro.save", proc { vma.macro.save }, "Save the recorded and named macros")
reg_act("macro.save.a", proc { vma.macro.save_macro("a") }, "Save macro a as a Ruby file")

reg_act("buf.switch.last", proc { bufs.switch_to_last_buf }, "Switch to the last used buffer")
reg_act("buf.close.scrap", proc { bufs.close_scrap_buffers }, "Close all buffers that have no file")
reg_act("buf.list.save", proc { save_buffer_list }, "Save the list of open buffers")
reg_act("buf.list.load", proc { load_buffer_list }, "Open the saved list of buffers")

reg_act("debug.deltas", proc { debug_dump_deltas }, "Print the change deltas of the buffer")
reg_act("debug.clipboard", proc { debug_dump_clipboard }, "Print the clipboard contents")
reg_act("debug.buf.print", proc { debug_print_buffer }, "Print the buffer object and its text")
reg_act("debug.overlay.clear", proc { vma.gui.clear_overlay }, "Clear the drawing overlay")
reg_act("debug.pry", proc { require "pry"; binding.pry }, "Open a pry console in the terminal")

def gui_select_buffer_language
  lm = GtkSource::LanguageManager.new
  lm.set_search_path(lm.search_path << ppath("lang/"))
  all_lang_ids = lm.language_ids.sort
  @_lang_select_list = all_lang_ids

  update_callback = proc do |search_str|
    filtered = search_str.empty? ? all_lang_ids : all_lang_ids.select { |id| id.include?(search_str.downcase) }
    @_lang_select_list = filtered
    filtered.map { |id| [id] }
  end

  select_callback = proc do |_str, idx|
    gui_select_window_close(0)
    vma.buf.set_language(@_lang_select_list[idx])
  end

  opt = {
    :title => "Select language",
    :columns => [{ :title => "Language", :id => 0 }],
  }

  gui_select_update_window(all_lang_ids.map { |id| [id] }, [], select_callback, update_callback, opt)
end

end # module Vimamsa
