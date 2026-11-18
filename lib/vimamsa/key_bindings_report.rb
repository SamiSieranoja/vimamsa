
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

# ── Vim keymap vs vimlike keymap ─────────────────────────────────────────────

# Build a separate KeyBindingTree from a keymap scheme file ("vim", "vimlike")
# without changing the running editor. A scheme file binds into vma.kbd,
# registers actions in vma.actions, defines helper methods and sets the
# cnf.mode cursor colors; all of these are swapped out or restored here.
def load_scheme_kbd(scheme)
  file = File.join(__dir__, "key_bindings_#{scheme}.rb")
  ed = vma
  saved_kbd, saved_actions = ed.kbd, ed.actions
  names = Vimamsa.instance_methods(false) + Vimamsa.private_instance_methods(false)
  saved_methods = names.to_h { |n| [n, Vimamsa.instance_method(n)] }
  color_modes = %w[command default visual replace browse insert inactive]
  saved_colors = color_modes.to_h { |m| [m, cnf.mode.send(m).cursor.background!] }
  acts = ActionList.new
  kbd = KeyBindingTree.new(actions: acts)
  kbd.error_handler = proc { |_msg| }
  begin
    ed.kbd = kbd
    ed.instance_variable_set(:@actions, acts)
    load file
  ensure
    ed.kbd = saved_kbd
    ed.instance_variable_set(:@actions, saved_actions)
    saved_methods.each { |n, um|
      Vimamsa.send(:define_method, n, um) if Vimamsa.instance_method(n) != um
    }
    saved_colors.each { |m, v| cnf.mode.send(m).cursor.background = v }
  end
  kbd
end

# Every binding of a tree as [mode, keys, action]; keys is an Array of key
# names, with "(eval_rule)" appended where the binding has one.
def kbd_leaf_bindings(kbd)
  out = []
  stack = kbd.root.children.map { |m| [m, m.key_name, []] }
  while (x = stack.pop)
    st, mode, path = x
    st.children.each { |c|
      p = path + [c.eval_rule.empty? ? c.key_name : "#{c.key_name}(#{c.eval_rule})"]
      out << [mode, p, c.action] if !c.action.nil?
      stack << [c, mode, p] if c.children.any?
    }
  end
  out.sort_by { |m, k, _a| [m, k.join(" ")] }
end

# Compare each binding of the vim keymap with the vimlike keymap (tree
# `other`, default: a fresh vimlike tree with no module or custom.rb
# bindings). Returns rows {mode:, keys:, action:, status:, why:, other:}:
#   :shared   same keys, same action
#   :missing  vimlike has nothing there, so the binding could be added
#   :conflict vimlike uses the keys differently; why is one of
#     :same_keys   same keys bound to another action
#     :shorter     a shorter vimlike binding runs first (other = its keys)
#     :prefix      vimlike has longer bindings starting with these keys
#     :wildcard    a vimlike "<char>" binding takes the key
def vim_binding_conflicts(other = nil)
  other ||= load_scheme_kbd("vimlike")
  vim = load_scheme_kbd("vim")
  kbd_leaf_bindings(vim).map { |mode, keys, action|
    row = { mode: mode, keys: keys, action: kbd_action_code(action, vim.actions) }
    row.merge(vim_binding_status(other, mode, keys, action, vim.actions))
  }
end

# What an action runs, as text, so bindings can be compared and listed:
# the code of a String action or the body of a one-line proc. A registered
# action whose code isn't one line is ":name"; an unnamed multi-line proc is
# its first source line. "vma.buf" counts as "buf".
def kbd_action_code(action, acts = nil)
  a = action
  if a.class == Symbol
    reg = acts&.[](a) || vma.actions[a]
    return ":#{a}" if reg.nil? || reg.method.class != Proc
    return ":#{a}" if kbd_proc_code(reg.method).nil?
    a = reg.method
  end
  code = a.class == Proc ? (kbd_proc_code(a) || kbd_proc_first_line(a)) : a.to_s
  code.gsub(/\bvma\.buf\b/, "buf").gsub(/\s+/, " ").strip
end

def kbd_proc_source(pr)
  file, line = pr.source_location
  @kbd_src_lines ||= {}
  lines = (@kbd_src_lines[file] ||= (File.readlines(file) rescue []))
  lines[line - 1].to_s
end

# Body of a proc written on one line, or nil
def kbd_proc_code(pr)
  m = kbd_proc_source(pr).match(/proc\s*\{\s*(.*?)\s*\}/)
  m && m[1]
end

def kbd_proc_first_line(pr)
  "proc: " + kbd_proc_source(pr).strip.sub(/\A"[^"]*"\s*=>\s*/, "")
end

def vim_binding_status(kbd, mode, keys, action, vim_acts = nil)
  node = kbd.root.children.find { |m| m.key_name == mode }
  return { status: :missing } if node.nil?
  path = []
  keys.each_with_index { |k, i|
    m = /\A(.+)\((.*)\)\z/.match(k)
    name, rule = m ? [m[1], m[2]] : [k, ""]
    child = node.children.find { |c| c.key_name == name && c.eval_rule == rule }
    if child.nil?
      wc = node.children.find { |c| c.key_name == "<char>" }
      if wc && name.size == 1
        return { status: :conflict, why: :wildcard, other: [path + ["<char>"], kbd_action_code(wc.action, kbd.actions)] }
      end
      return { status: :missing }
    end
    path << k
    last = i == keys.size - 1
    if !last && !child.action.nil? && child.children.empty?
      return { status: :conflict, why: :shorter, other: [path, kbd_action_code(child.action, kbd.actions)] }
    end
    node = child
  }
  if node.children.any?
    n = 0
    stack = [node]
    while (s = stack.pop)
      s.children.each { |c| n += 1 if !c.action.nil?; stack << c }
    end
    return { status: :conflict, why: :prefix, other: [keys, "#{n} longer binding#{n == 1 ? "" : "s"}"] }
  end
  oc = kbd_action_code(node.action, kbd.actions)
  return { status: :shared } if oc == kbd_action_code(action, vim_acts)
  { status: :conflict, why: :same_keys, other: [keys, oc] }
end

VIM_CONFLICT_WHY = {
  same_keys: "same keys, other action",
  shorter: "a shorter vimlike binding runs first",
  prefix: "vimlike uses these keys as a prefix",
  wildcard: "a vimlike <char> binding takes the key",
}

# Markdown report of vim_binding_conflicts, written to
# doc/vimlike_vim_conflicts.md (tests/test_vim_conflicts.rb keeps it current).
def vim_binding_conflicts_report(rows = vim_binding_conflicts)
  code = ->(s) {
    s = s.to_s
    s = s[0, 57] + "..." if s.size > 60
    s = s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("|", "&#124;")
    "<code>#{s}</code>"
  }
  act = code
  by = rows.group_by { |r| r[:status] }
  out = +"# Vim keymap vs vimlike keymap\n\n"
  out << "Generated by `vim_binding_conflicts_report` (lib/vimamsa/key_bindings_report.rb)\n"
  out << "from `key_bindings_vim.rb` and `key_bindings_vimlike.rb`. Don't edit by hand:\n"
  out << "run `VMA_UPDATE_DOC=1 ruby exe/run_tests.rb --headless vim_conflicts`.\n\n"
  out << "Bindings that modules and `custom.rb` add at startup are not included.\n\n"
  out << "| | Count |\n|---|---|\n"
  out << "| Conflicts (the vim binding can't be used in vimlike) | #{by.fetch(:conflict, []).size} |\n"
  out << "| Missing from vimlike (no conflict, could be added) | #{by.fetch(:missing, []).size} |\n"
  out << "| Shared (same keys, same action) | #{by.fetch(:shared, []).size} |\n\n"

  out << "## Conflicts\n\n| Mode | Vim keys | Vim action | vimlike | Reason |\n|---|---|---|---|---|\n"
  by.fetch(:conflict, []).each { |r|
    ok, oa = r[:other]
    vl = ok == r[:keys] ? act.(oa) : "#{code.(ok.join(" "))} #{act.(oa)}"
    vl = code.(oa) if r[:why] == :prefix
    out << "| #{r[:mode]} | #{code.(r[:keys].join(" "))} | #{act.(r[:action])} | #{vl} | #{VIM_CONFLICT_WHY[r[:why]]} |\n"
  }
  out << "\n## Missing from vimlike\n\n| Mode | Vim keys | Vim action |\n|---|---|---|\n"
  by.fetch(:missing, []).each { |r|
    out << "| #{r[:mode]} | #{code.(r[:keys].join(" "))} | #{act.(r[:action])} |\n"
  }
  out << "\n## Shared\n\n| Mode | Keys | Action |\n|---|---|---|\n"
  by.fetch(:shared, []).each { |r|
    out << "| #{r[:mode]} | #{code.(r[:keys].join(" "))} | #{act.(r[:action])} |\n"
  }
  out
end

# Show the report for the running editor: compared with the live key
# bindings when the vimlike keymap is in use, so custom.rb is included.
def show_vim_binding_conflicts
  live = (cnf.keybindings.scheme! || "vimlike") == "vimlike"
  b = create_new_buffer(vim_binding_conflicts_report(vim_binding_conflicts(live ? vma.kbd : nil)), "vim-binding-conflicts")
  gui_set_file_lang(b.id, "markdown")
end
end # module Vimamsa
