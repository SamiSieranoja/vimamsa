module Vimamsa
# Shared Vim bindings, used by both keymaps (doc/vim_compatibility_plan.md):
#   vim keymap:     bind_vim_bindings            binds the whole table
#   vimlike keymap: bind_vim_bindings(only_free: true) after its own
#                   bindings: binds only entries that don't conflict with
#                   them (vim_binding_status == :missing), so vimlike's own
#                   bindings always win.
# What was added, and every conflict, is listed in the generated
# doc/vimlike_vim_conflicts.md.

# ── composite actions for vim commands not covered by a single action ────────
#TODO: file should be renamed to sort close to  key_actions.rb


def reg_vim_actions
  # get_range(:to_line_end) inverts on an empty line / cursor-on-newline and
  # would delete the previous newline (buffer.rb get_range) => guard.
  reg_act("edit.delete.eol", proc {
    b = buf
    b.delete2(:to_line_end) if b.pos < b.line_ends[b.lpos]
  }, "Delete to end of line (vim D)")

  reg_act("edit.change.eol", proc {
    b = buf
    b.delete2(:to_line_end) if b.pos < b.line_ends[b.lpos]
    vma.kbd.set_mode(:insert)
  }, "Change to end of line (vim C / c$)")

  reg_act("edit.change.line", proc {
    b = buf
    b.jump(BEGINNING_OF_LINE)
    b.delete2(:to_line_end) if b.pos < b.line_ends[b.lpos]
    vma.kbd.set_mode(:insert)
  }, "Change whole line, keep newline (vim cc/S)")

  reg_act("edit.change.word", proc {
    buf.delete2(:to_word_end) # vim cw ~= ce semantics; close enough
    vma.kbd.set_mode(:insert)
  }, "Change word (vim cw/ce)")

  reg_act("edit.change.char", proc {
    buf.delete(CURRENT_CHAR_FORWARD) if buf.current_char != "\n"
    vma.kbd.set_mode(:insert)
  }, "Substitute char (vim s)")

  reg_act("edit.delete.char.inline", proc {
    buf.delete(CURRENT_CHAR_FORWARD) if buf.current_char != "\n"
  }, "Delete char under cursor; no-op on empty line (vim x)")

  reg_act("edit.delete.char.prev", proc {
    buf.delete(BACKWARD_CHAR) if buf.cpos > 0
  }, "Delete char before cursor; no-op at col 0 (vim X)")

  reg_act("edit.line.above", proc {
    b = buf
    b.jump(BEGINNING_OF_LINE)
    # insert_txt_at neither auto-indents nor moves the cursor: @pos ends up on
    # the inserted "\n" = the new empty line, matching vim O.
    b.insert_txt_at("\n", b.pos)
    b.set_pos(b.pos) # refresh view + lpos/cpos
    vma.kbd.set_mode(:insert)
  }, "Open line above (vim O)")

  reg_act("sel.change", proc {
    buf.delete(SELECTION) # ends visual mode itself
    vma.kbd.set_mode(:insert)
  }, "Delete selection and enter insert mode (vim visual c/s)")

  # APPROXIMATION: set_last_command is currently only fed by f/F finds, so this
  # repeats the last find, not the last change like vim's ".".
  reg_act("undo.repeat", proc { repeat_last_action() },
          "Repeat last recorded command (approximation of vim .)")
end

# ── the table: section => { keys => action } ─────────────────────────────────
# Same binding syntax as add_keys. Only Vim behavior goes here; the vim
# keymap's own deviations (C tab, C enter, browse mode, ...) stay in
# key_bindings_vim.rb.

VIM_BINDINGS = {
  "vim motion" => {
    "VCX up" => "move.line.prev",
    "VCX down" => "move.line.next",
    "VCX right" => "move.char.next",
    "VCX left" => "move.char.prev",
    "VC h" => "move.char.prev",
    "VC l" => "move.char.next",
    "VC j" => "move.line.next",
    "VC k" => "move.line.prev",
    "C space" => "move.char.next",
    "C backspace" => "move.char.prev",

    "VC e" => "move.word.end",
    "VC b" => "move.word.prev",
    "VC w" => "move.word.next",

    # NOTE: "G(condition)" must be defined before "G"
    "VC G(vma.kbd.next_command_count!=nil)" => "move.line.goto",
    "VC G" => "move.buf.end",
    "VC g g" => "move.buf.start",
    "VC g ;" => "jump.edit.prev",

    # Counts; "0" is BOL only when no count is pending
    "VC /[1-9]/" => "kbd.count.digit",
    "VC 0(vma.kbd.next_command_count!=nil)" => "kbd.count.digit",
    "VC 0(vma.kbd.next_command_count==nil)" => "move.line.start",
    "VC ^" => "move.line.first_char",
    "VC $" => "move.line.end",

    "VC f <char>" => "jump.char.next",
    "VC F <char>" => "jump.char.prev",
    "VC f space" => "jump.space.next",
    "VC F space" => "jump.space.prev",
    "VC ;" => "jump.char.repeat",

    "VC *" => "search.word.next",
    "VC /" => "search.buf",
    "C :" => "mode.cmdline",
    "C n" => "search.next",
    "C N" => "search.prev",

    "VCI pagedown" => "move.page.next",
    "VCI pageup" => "move.page.prev",
    "C ctrl-f" => "move.page.next",
    "C ctrl-b" => "move.page.prev",
    "C ctrl-d" => "move.page.next.cursor",  # approx: full page, vim: half
    "C ctrl-u" => "move.page.prev.cursor", # approx: full page, vim: half
    "C ctrl-o" => "jump.edit.prev",         # approx of vim jumplist back
    "C z z" => "view.center",
  },

  "vim marks cat:marks" => {
    "CV m <char>" => "mark.set",
    'CV \' <char>' => "mark.jump",
    "C ` <char>" => "mark.jump",
  },

  # Enter insert mode
  "vim edit cat:insert" => {
    "C i" => "mode.insert",
    "C a" => "mode.insert.after",
    "C A" => "mode.insert.line.end",
    "C I" => "mode.insert.line.start",
    "C o" => "mode.insert.line.below",
    "C O" => "edit.line.above",
  },

#TODO: should replace all eval actions like "buf.move ... with actual registered actions.
  "vim edit" => {
    # Delete
    "C x" => "edit.delete.char.inline",
    "C X" => "edit.delete.char.prev",
    "C d d" => ["edit.delete.line", proc { buf.delete_line }, "Delete current line"],
    "C d e" => "edit.delete.word.end",
    "C d w" => "edit.delete.word.next",
    "C d $" => "edit.delete.eol",
    "C d 0" => "edit.delete.line.start",
    "C d ' <char>" => "edit.delete.mark",
    "C d f <char>" => "edit.delete.find.next",
    "C d F <char>" => "edit.delete.find.prev",
    "C d f space" => "edit.delete.space.next",
    "C d F space" => "edit.delete.space.prev",
    "C D" => "edit.delete.eol",

    # Change / substitute
    "C c c" => "edit.change.line",
    "C c w" => "edit.change.word",
    "C c e" => "edit.change.word",
    "C c $" => "edit.change.eol",
    "C C" => "edit.change.eol",
    "C S" => "edit.change.line",
    "C s" => "edit.change.char",

    # Yank / paste
    "C y y" => "edit.line.copy",
    "C Y" => "edit.line.copy",
    "C y w" => "edit.copy.word.next",
    "C y e" => "edit.copy.word.end",
    "C y $" => "edit.copy.line.end",
    "C y 0" => "edit.copy.line.start",
    "C y ' <char>" => "edit.copy.mark",
    "C p" => "edit.paste.after",
    "C P" => "edit.paste.before",

    # Misc edits
    "C r <char>" => "edit.replace.char",
    "C r space" => "edit.replace.space",
    "C J" => "edit.line.join",
    "C ~" => "case.char.toggle",
    "C g U w" => "case.word.upper",
    "C g u w" => "case.word.lower",
    "C g ~ w" => "case.word.swap",
    "C g U U" => "case.line.upper",
    "C g u u" => "case.line.lower",
    "C g ~ ~" => "case.line.swap",
    "C ctrl-a" => "edit.word.increment", # vim ctrl-a: increment number
    "C ." => "undo.repeat",

    # Undo / redo
    "C u" => "undo.last",
    "C ctrl-r" => "undo.redo",
  },

  "vim visual" => {
    "C v" => "mode.visual",
    "V esc" => "mode.visual.exit",
    "V ctrl-c" => "mode.visual.exit",
    "V y" => "sel.copy",
    "V d" => "sel.delete",
    "V x" => "sel.cut",
    "V s" => "sel.change",
    "V c" => "sel.change",
    "V J" => "sel.join",
    "V u" => "case.sel.lower",
    "V U" => "case.sel.upper",
    "V ~" => "case.sel.swap",
    "V g U" => "case.sel.upper",
    "V g u" => "case.sel.lower",
    "V >" => "sel.indent.more",
    "V <" => "sel.indent.less",
  },

  "vim insert" => {
    "I esc" => "mode.prev",
    "I ctrl-c" => "mode.prev", # vim: ctrl-c leaves insert mode
    "I <char>" => "edit.insert.char",
    "I space" => "edit.insert.space",
    "I enter" => "edit.newline",
    "I backspace" => "edit.backspace",
    "I ctrl-h" => "edit.backspace",          # vim i_ctrl-h = backspace
    "I ctrl-j" => "edit.newline",    # vim i_ctrl-j = new line

    # Completion (vim i_ctrl-n / i_ctrl-p; popup guards first)
    "I tab(vma.buf.view.autocp_active)" => "edit.complete.next",
    "I shift-tab(vma.buf.view.autocp_active)" => "edit.complete.prev",
    "I shift!(vma.buf.view.autocp_active)" => "edit.complete.accept",
    "I ctrl-n" => "edit.complete",
    "I ctrl-p" => "edit.complete",
    "I ctrl-space" => "edit.complete",

    "I tab" => "edit.tab",
    "I shift-tab" => "edit.untab",

    "I shift-up" => "sel.line.prev",
    "I shift-down" => "sel.line.next",
    "I shift-left" => "sel.char.prev",
    "I shift-right" => "sel.char.next",
    "I shift-pagedown" => "sel.page.next",
    "I shift-pageup" => "sel.page.prev",

    "I left" => "move.char.prev.unselect",
    "I right" => "move.char.next.unselect",
    "I down" => "move.line.next.unselect",
    "I up" => "move.line.prev.unselect",
    "I pagedown" => "move.page.next.unselect",
    "I pageup" => "move.page.prev.unselect",
  },

  # vim R
  "vim replace" => {
    "C R" => "mode.replace",
    "X esc" => "mode.prev",
    "X <char>" => "edit.replace.char.next",
  },

  "vim macros" => {
    # q<char> records, q stops, @<char> runs, @@ repeats
    "VC q <char>" => "macro.record",
    "macro q" => "macro.record.stop",
    "C @ @" => "macro.run.last",
    "C @ <char>" => "macro.run",

    # READCHAR mode (argument input for f/F, r, m, ', q, @)
    "R <char>" => "readchar_new_char(<char>)",
  },
}

# Bind VIM_BINDINGS into vma.kbd. With only_free, an entry is bound only if
# vma.kbd has nothing in its way (see vim_binding_status), and binding it
# doesn't change which keys the menus show for an action vimlike already
# binds. Records what was bound as [mode, keys] in vma.kbd.vim_added.
def bind_vim_bindings(only_free: false)
  reg_vim_actions
  kbd = vma.kbd
  added = []
  VIM_BINDINGS.each { |section, h|
    h.each { |key, action|
      if !only_free
        bindkey(key, action, keywords: section)
        next
      end
      act = action.class == Array ? action[0] : action
      key.split("||").each { |k|
        mstr, keydef = k.strip.split(/\s+/, 2)
        modes = mstr.match?(/\A\p{Lu}+\z/) ? mstr.chars : [mstr]
        modes.each { |m|
          keys = keydef.split
          next if vim_binding_status(kbd, m, keys, act)[:status] != :missing
          had = kbd.act_bindings.key?(m) && kbd.act_bindings[m].key?(act)
          prev = had ? kbd.act_bindings[m][act] : nil
          bindkey("#{m} #{keydef}", action, keywords: section)
          kbd.act_bindings[m][act] = prev if had
          added << [m, keys]
        }
      }
    }
  }
  kbd.vim_added = added
  added
end
end # module Vimamsa
