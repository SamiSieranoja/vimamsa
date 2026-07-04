# Notepad scheme: ordinary non-modal editing (gedit/notepad style).
# Inherits all modes, infrastructure and bindings from the vimlike scheme,
# then overrides so the editor stays permanently in insert mode.
# Selected via cnf.keybindings.scheme = "notepad" (applied on restart).
require "vimamsa/key_bindings_vimlike"

module Vimamsa
  vma.kbd.set_default_mode(:insert)
  vma.kbd.__set_mode(:insert)

  # esc never leaves insert mode: clear selection, dismiss autocomplete popup
  reg_act(:notepad_escape, proc {
    buf.end_selection
    v = vma.buf.view
    v.hide_completions if v.respond_to?(:hide_completions)
  }, "Clear selection and dismiss popups")

  # Replaces the "I esc" leaf of vimlike's "I esc || I ctrl!" => :prev_mode
  bindkey "I esc", :notepad_escape
  # In vimlike, releasing bare ctrl in insert mode returns to command mode.
  # Harmless here (mode stack is [:insert], to_previous_mode won't pop) but
  # remove it so ctrl-release doesn't dispatch a pointless action.
  unbindkey "I ctrl!"

  add_keys "notepad", {
    # Rebinds over conflicting vimlike insert-mode bindings
    # (bindkey on an existing chord overwrites the leaf)
    "I ctrl-f" => :find_in_buffer,      # was move FORWARD_CHAR
    "I ctrl-h" => :gui_search_replace,  # was autocp trigger (ctrl-space remains)
    "I ctrl-n" => :buf_new,             # was move_next_line
    "I ctrl-a" => :select_all,          # was jump_beginning_of_line
    "I ctrl-q" => :quit,
    "I ctrl-shift-z || I ctrl-shift-Z" => :redo, # shift+z may arrive uppercase
    "I delete" => :insert_delete,

    "I home" => "buf.end_selection; buf.jump(BEGINNING_OF_LINE)",
    "I end" => "buf.end_selection; buf.jump(END_OF_LINE)",
    "I shift-home" => "buf.continue_selection; buf.jump(BEGINNING_OF_LINE)",
    "I shift-end" => "buf.continue_selection; buf.jump(END_OF_LINE)",
    "I ctrl-home" => :jump_to_start_of_buffer,
    "I ctrl-end" => :jump_to_end_of_buffer,
  }
end # module Vimamsa
