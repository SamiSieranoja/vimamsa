
module Vimamsa
# Editor-side reports of the key binding tree contents, shown as buffers.
# Kept out of key_binding_tree.rb so the tree stays free of editor/GUI calls.

def show_free_key_bindings()
  kbd_s = "❙Free key binding slots❙\n"
  kbd_s << "\n⦁[Mode] <prefix> : <free keys>⦁\n"
  kbd_s << "[B]=Browse, [C]=Command, [I]=Insert, [V]=Visual\n"
  kbd_s << "Free = not yet bound under that prefix\n"
  kbd_s << "===============================================\n"
  kbd_s << vma.kbd.get_free_bindings
  kbd_s << "\n"
  b = create_new_buffer(kbd_s, "free-key-bindings")
  gui_set_file_lang(b.id, "hyperplaintext")
end

def show_key_bindings()
  kbd_s = "❙Key bindings❙\n"
  kbd_s << "\n⦁[Mode] <keys> : <action>⦁\n"
  done = []

  kbd_s << "[B]=Browse, [C]=Command, [I]=Insert, [V]=Visual\n"
  kbd_s << "<key>!: Press <key> once, release before pressing any other keys\n"
  kbd_s << "===============================================\n"
  kbd_s << "◼ Basic\n"
  kbd_s << "◼◼ Command mode\n"

  x = vma.kbd.get_by_keywords(modes: ["C"], keywords: ["intro"])
  done.concat(x.lines); kbd_s << x

  kbd_s << "\n"
  kbd_s << "◼◼ Insert mode\n"
  x = vma.kbd.get_by_keywords(modes: ["I"], keywords: ["intro"])
  done.concat(x.lines); kbd_s << x
  kbd_s << "\n"
  kbd_s << "◼◼ Visual mode\n"
  x = vma.kbd.get_by_keywords(modes: ["V"], keywords: ["intro"])
  done.concat(x.lines); kbd_s << x
  kbd_s << "\n"

  kbd_s << "◼ Hyper Plaintext\n"
  x = vma.kbd.get_by_keywords(modes: ["C"], keywords: ["hyperplaintext"])
  x2 = vma.kbd.get_by_keywords(modes: ["V"], keywords: ["hyperplaintext"])
  done.concat(x.lines); kbd_s << x << "\n" << x2
  kbd_s << "\n"

  kbd_s << "◼ Core\n"
  x = vma.kbd.get_by_keywords(modes: [], keywords: ["core"])
  x << vma.kbd.get_by_keywords(modes: ["X"], keywords: ["intro"])

  done.concat(x.lines); kbd_s << x
  kbd_s << "\n"

  kbd_s << "◼ Debug / Experimental\n"
  x = vma.kbd.get_by_keywords(modes: [], keywords: ["experimental"])
  done.concat(x.lines); kbd_s << x
  kbd_s << "\n"

  kbd_s << "◼ Others\n"
  # x = vma.kbd.get_by_keywords(modes: [], keywords:["experimental"])
  # x = vma.kbd.to_s
  x = vma.kbd.get_by_keywords(modes: [], keywords: [])
  done << x.lines - done
  kbd_s << (x.lines - done).join
  kbd_s << "\n"

  kbd_s << "===============================================\n"
  b = create_new_buffer(kbd_s, "key-bindings")
  gui_set_file_lang(b.id, "hyperplaintext")
end
end # module Vimamsa
