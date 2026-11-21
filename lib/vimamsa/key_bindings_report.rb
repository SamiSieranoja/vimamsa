
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

# Categories of the key bindings page, in page order: [id, heading]
# (doc/key_bindings_report_plan.md). Modules and minor modes get their own
# "module:<name>" / "mode:<id>" categories after these.
KEY_CATEGORIES = [
  ["motion", "Moving the cursor"],
  ["search", "Searching and jumping"],
  ["insert", "Entering insert mode and typing"],
  ["edit", "Delete, change, copy, paste"],
  ["textobj", "Text objects"],
  ["case", "Case and text transforms"],
  ["visual", "Visual mode and selections"],
  ["undo", "Undo, redo, repeat"],
  ["marks", "Marks and bookmarks"],
  ["macro", "Macros"],
  ["file", "Files"],
  ["buffer", "Buffers and windows"],
  ["view", "Panels and view"],
  ["grep", "Search across files"],
  ["code", "Code (LSP, comments, run line)"],
  ["hpt", "Hyper plaintext"],
  ["app", "Application"],
  ["help", "Help"],
  ["custom", "Your bindings (custom.rb)"],
  ["debug", "Debug / experimental"],
  ["internal", "Internal (argument input)"],
]

# Action namespace => category. A longer prefix wins ("mode.visual").
ACTION_NS_CATEGORY = {
  "app" => "app", "mode" => "insert", "mode.visual" => "visual", "mode.cmdline" => "app",
  "mode.browse" => "buffer", "mode.passthrough" => "debug", "mode.minibuffer" => "debug",
  "help" => "help", "debug" => "debug", "move" => "motion", "jump" => "search",
  "search" => "search", "grep" => "grep", "ack" => "grep", "edit" => "edit",
  "edit.comment" => "code", "edit.indent" => "code", "undo" => "undo", "case" => "case",
  "sel" => "visual", "buf" => "buffer", "file" => "file", "panel" => "view", "view" => "view",
  "style" => "hpt", "macro" => "macro", "mark" => "marks", "lsp" => "code", "term" => "code",
  "custom" => "custom", "op" => "edit", "op.textobj" => "textobj", "sel.textobj" => "textobj", "kbd" => "internal", "kbd.count" => "undo",
  "mode.replace" => "edit", "mode.audio" => "app", "edit.insert" => "insert",
  "edit.tab" => "insert", "edit.untab" => "insert", "edit.complete" => "insert",
}

# Bindings in these major modes, when nothing else decides
KEY_MODE_CATEGORY = { "B" => "buffer", "X" => "edit", "R" => "internal" }

# Words of older section keywords (add_keys "vim motion", ...)
KEY_WORD_CATEGORY = {
  "motion" => "motion", "edit" => "edit", "visual" => "visual", "insert" => "insert",
  "replace" => "edit", "macros" => "macro", "text" => "textobj",
  "hyperplaintext" => "hpt", "experimental" => "debug",
}

# The category id of a binding record (KeyBindingTree#bindings), or nil.
# kbd: the tree it came from (for its actions and modes).
def key_binding_category(b, kbd = vma.kbd)
  mode = b[:mode]
  return "mode:#{mode}" if mode.match?(/\A\p{Ll}/) # minor mode
  a = b[:action]
  id = a.to_s
  if (a.class == String || a.class == Symbol) && id.match?(ACTION_ID_RE)
    named = [vma.actions, kbd.actions].compact.any? { |acts|
      x = acts[id]
      x && !x.opt&.[](:code)
    }
    if named
      segs = id.split(".")
      segs.size.downto(1) { |n|
        c = ACTION_NS_CATEGORY[segs[0, n].join(".")]
        return c if c
      }
      return "module:#{segs[0]}" if File.directory?(File.join(__dir__, "../../modules", segs[0]))
      return "mode:#{segs[0]}"
    end
  end
  kws = b[:keywords]
  kws.each { |k| return k.sub("cat:", "") if k.start_with?("cat:") }
  kws.each { |k| return k if k.start_with?("module:") }
  return "custom" if kws.include?("custom")
  return KEY_MODE_CATEGORY[mode] if KEY_MODE_CATEGORY[mode]
  kws.each { |k| return KEY_WORD_CATEGORY[k] if KEY_WORD_CATEGORY[k] }
  nil
end

def key_category_heading(cat)
  return "Uncategorized" if cat.nil?
  h = KEY_CATEGORIES.find { |id, _| id == cat }
  return h[1] if h
  return "Module: #{cat.sub("module:", "")}" if cat.start_with?("module:")
  return "Minor mode: #{cat.sub("mode:", "")}" if cat.start_with?("mode:")
  "Uncategorized"
end

# Bindings grouped by category, in page order: [[category, [records]], ...].
# Bindings with no category come last, under nil.
def key_bindings_by_category(kbd = vma.kbd)
  by = kbd.bindings.group_by { |b| key_binding_category(b, kbd) }
  order = KEY_CATEGORIES.map(&:first)
  rank = ->(c) {
    c.nil? ? [3, ""] : order.include?(c) ? [0, order.index(c)] : c.start_with?("module:") ? [1, c] : [2, c]
  }
  by.sort_by { |c, _| rank.(c) }
end

# Actions listed under Basics, in this order, with whatever keys the active
# keymap binds them to (they also appear in their own category)
BASIC_ACTIONS = %w[
  mode.insert mode.prev mode.visual
  move.word.next move.word.prev move.line.start move.line.end move.buf.start move.buf.end
  edit.delete.char edit.delete.line edit.line.copy edit.paste.after edit.paste.before
  sel.copy sel.cut undo.last undo.redo
  search.buf search.next search.actions
  file.open file.finder buf.save buf.manager buf.close
  mode.cmdline help.keys app.quit
]

KEY_MODE_NAMES = {
  "C" => "Command", "V" => "Visual", "I" => "Insert", "X" => "Replace",
  "B" => "Browse", "R" => "Read char", "M" => "Minibuffer",
}

# Binding conditions ("C G(rule)") as text; others are shown as they are
KEY_CONDITIONS = {
  "vma.buf.view.autocp_active" => "when the completion popup is open",
  "vma.kbd.next_command_count!=nil" => "with a count",
  "vma.kbd.next_command_count==nil" => "without a count",
  "vma.macro.is_recording==true" => "while recording a macro",
}

def key_condition_text(rule)
  KEY_CONDITIONS[rule] || "if #{rule}"
end

# Lines of one page section from binding records, kept in the given order:
# the same keys and description in several modes become one row, rows are
# grouped by their modes ("◼◼ Command, Visual" subheadings unless
# subheads: false; ordered by their first mode), rows of a group with the
# same description are merged ("up / k"), and keys and descriptions are
# aligned in columns.
def key_bindings_section(records, subheads: true)
  rank = KEY_MODE_NAMES.keys
  rows = {}
  records.each { |b|
    conds = []
    # A template expansion (C d w) is shown as its template (<op> <motion>)
    keys = b[:template] ? b[:template].split(" ", 2)[1].split : b[:keys]
    keys = keys.map { |k|
      m = /\A(.+)\((.*)\)\z/m.match(k)
      next k if m.nil?
      conds << key_condition_text(m[2])
      m[1]
    }.join(" ")
    r = (rows[[keys, b[:desc], conds]] ||= { keys: keys, desc: b[:desc], conds: conds, modes: [] })
    r[:modes] << b[:mode] if !r[:modes].include?(b[:mode])
  }
  groups = {}
  rows.each_value { |r|
    ms = r[:modes].sort_by { |m| rank.index(m) || rank.size }
    g = (groups[ms] ||= {})
    line = (g[[r[:desc], r[:conds]]] ||= { keys: [], desc: r[:desc], conds: r[:conds] })
    line[:keys] << r[:keys]
  }
  # by the first mode (Command groups, then Visual, Insert, ..., minor
  # modes), then by which group was defined first
  groups = groups.each_with_index.sort_by { |(ms, _), i| [rank.index(ms[0]) || rank.size, i] }.map(&:first).to_h
  lines = groups.values.flat_map(&:values)
  w = lines.map { |l| l[:keys].join(" / ").size }.select { |n| n <= 28 }.max.to_i
  out = []
  groups.each { |ms, g|
    out << "◼◼ " + ms.map { |m| KEY_MODE_NAMES[m] || m }.join(", ") if subheads
    g.each_value { |l|
      desc = l[:desc].to_s
      desc += " (#{l[:conds].join(", ")})" if l[:conds].any?
      out << "    " + l[:keys].join(" / ").ljust(w) + "  " + desc
    }
  }
  out
end

# The key bindings page as text
def key_bindings_page(kbd = vma.kbd, scheme: cnf.keybindings.scheme! || "vimlike")
  all = kbd.bindings
  s = +"❙Key bindings — scheme: #{scheme}❙\n\n"
  s << KEY_MODE_NAMES.map { |m, n| "[#{m}]=#{n}" }.first(5).join(" ") << "\n"
  s << "<key>! = press and release <key> alone, with no other key in between\n"
  s << "a / b = either of the keys\n"
  s << "===============================================\n"
  basic = BASIC_ACTIONS.flat_map { |id|
    all.select { |b| b[:action].to_s == id && %w[C V I].include?(b[:mode]) }
  }
  if basic.any?
    s << "◼ Basics\n" << key_bindings_section(basic).join("\n") << "\n\n"
  end
  # The key sets of the templates go after the text objects (or before the
  # uncategorized bindings, if there are no text objects)
  sets = key_bindings_sets_section(kbd)
  key_bindings_by_category(kbd).each { |cat, bs|
    if cat.nil? && sets.any?
      s << sets.join("\n") << "\n\n"
      sets = []
    end
    s << "◼ #{key_category_heading(cat)}\n"
    s << key_bindings_section(bs, subheads: !cat.to_s.start_with?("mode:")).join("\n") << "\n\n"
    if cat == "textobj" && sets.any?
      s << sets.join("\n") << "\n\n"
      sets = []
    end
  }
  s << sets.join("\n") << "\n\n" if sets.any?
  s << "===============================================\n"
end

# The key sets used by templates (<op>, <motion>, ...): each key and what it
# means, wrapped to lines of about 80 characters
def key_bindings_sets_section(kbd)
  return [] if kbd.key_sets.empty?
  out = ["◼ Operators, motions and text objects",
         "    A line like  <op> <motion>  works with every key below: d w, c 3 e, g U f x"]
  w = kbd.key_sets.keys.map { |n| n.size + 2 }.max
  order = [:op, :motion, :textobj]
  kbd.key_sets.sort_by { |name, _| order.index(name) || order.size }.each { |name, entries|
    items = entries.map { |k, v|
      d = key_set_value_desc(name, v.is_a?(Hash) ? v[:id] : v)
      d = d.gsub("<char>", v[:char] == " " ? "space" : v[:char]) if v.is_a?(Hash) && v[:char]
      "#{k} #{d}"
    }
    line = "    " + "<#{name}>".ljust(w) + "  "
    indent = " " * line.size
    cur = line
    items.each_with_index { |it, i|
      piece = (i == 0 ? "" : " · ") + it
      if cur.size + piece.size > 84 && cur != line
        out << cur.rstrip
        cur = indent + it
      else
        cur += piece
      end
    }
    out << cur
  }
  out << "    <same> = the last key of the operator again: d d, c c, > >, g U U (<count> lines)"
  out << "    text objects (<char>): w W s p \" ' ` ( ) b [ ] { } B < > t"
  out
end

def show_key_bindings()
  b = create_new_buffer(key_bindings_page, "key-bindings")
  gui_set_file_lang(b.id, "hyperplaintext")
end

# ── Vim keymap vs vimlike keymap ─────────────────────────────────────────────

# Build a separate KeyBindingTree from a keymap scheme file ("vim", "vimlike"),
# or several loaded in order (["vimlike", "notepad"]: notepad builds on vimlike)
# without changing the running editor. A scheme file binds into vma.kbd,
# registers actions in vma.actions, defines helper methods and sets the
# cnf.mode cursor colors; all of these are swapped out or restored here.
def load_scheme_kbd(scheme)
  files = Array(scheme).map { |x| File.join(__dir__, "key_bindings_#{x}.rb") }
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
    files.each { |f| load f }
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

# Compare each binding of the vim keymap with the vimlike keymap (tree
# `other`, default: a fresh vimlike tree with no module or custom.rb
# bindings). Returns rows {mode:, keys:, action:, status:, why:, other:}:
#   :shared   same keys, same action, bound by vimlike itself
#   :added    vimlike got it from the shared table (bind_vim_bindings)
#   :missing  vimlike has nothing there, so the binding could be added
#   :conflict vimlike uses the keys differently; why is one of
#     :same_keys   same keys bound to another action
#     :shorter     a shorter vimlike binding runs first (other = its keys)
#     :prefix      vimlike has longer bindings starting with these keys
#     :wildcard    a vimlike "<char>" binding takes the key
def vim_binding_conflicts(other = nil)
  other ||= load_scheme_kbd("vimlike")
  vim = load_scheme_kbd("vim")
  added = other.vim_added || []
  added = added.to_h { |x| [x, true] }
  vim.bindings.sort_by { |b| [b[:mode], b[:keys].join(" ")] }.map { |b|
    mode, keys, action = b[:mode], b[:keys], b[:action]
    code = kbd_action_code(action, vim.actions)
    code += "(#{b[:args].values.map { |x| x.is_a?(String) ? x.inspect : x }.join(", ")})" if b[:args]
    row = { mode: mode, keys: keys, action: code, template: b[:template] }
    next row.merge(status: :added) if added[[mode, keys]]
    if (why = VIM_KEYMAP_ONLY["#{mode} #{keys.join(" ")}"])
      next row.merge(status: :vim_only, why: why)
    end
    row.merge(vim_binding_status(other, mode, keys, action, vim.actions))
  }
end

# Rows of one status for the report: template expansions ("C <op> <motion>")
# become one row per template, with the number of expansions
def vim_conflict_rows_grouped(rows)
  out = []
  seen = {}
  rows.each { |r|
    if r[:template].nil?
      out << r
      next
    end
    if (g = seen[r[:template]])
      g[:n] += 1
      next
    end
    m, keys = r[:template].split(" ", 2)
    g = seen[r[:template]] = { mode: m, keys: keys.split, action: r[:action].sub(/\(.*\)\z/, ""), n: 1 }
    out << g
  }
  out.each { |g| g[:keys] = g[:keys] + ["(#{g[:n]} combinations)"] if g[:n] && g[:n] > 1 }
  out
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
  out << "| Added to vimlike from the shared table (`VIM_BINDINGS`, vim_core.rb) | #{by.fetch(:added, []).size} |\n"
  out << "| Missing from vimlike (no conflict, could be added) | #{by.fetch(:missing, []).size} |\n"
  out << "| vim keymap only (left out of vimlike on purpose) | #{by.fetch(:vim_only, []).size} |\n"
  out << "| Shared (same keys, same action) | #{by.fetch(:shared, []).size} |\n\n"

  out << "## Conflicts\n\n| Mode | Vim keys | Vim action | vimlike | Reason |\n|---|---|---|---|---|\n"
  by.fetch(:conflict, []).each { |r|
    ok, oa = r[:other]
    vl = ok == r[:keys] ? act.(oa) : "#{code.(ok.join(" "))} #{act.(oa)}"
    vl = code.(oa) if r[:why] == :prefix
    out << "| #{r[:mode]} | #{code.(r[:keys].join(" "))} | #{act.(r[:action])} | #{vl} | #{VIM_CONFLICT_WHY[r[:why]]} |\n"
  }
  out << "\n## Added to vimlike\n\nVim bindings that vimlike loads from the shared table because nothing of\n"
  out << "its own is in the way. A template (`<op> <motion>`, vim_operators.rb) is one row with\n"
  out << "the number of its combinations that vimlike got.\n\n| Mode | Vim keys | Vim action |\n|---|---|---|\n"
  vim_conflict_rows_grouped(by.fetch(:added, [])).each { |r|
    out << "| #{r[:mode]} | #{code.(r[:keys].join(" "))} | #{act.(r[:action])} |\n"
  }
  out << "\n## Missing from vimlike\n\n| Mode | Vim keys | Vim action |\n|---|---|---|\n"
  vim_conflict_rows_grouped(by.fetch(:missing, [])).each { |r|
    out << "| #{r[:mode]} | #{code.(r[:keys].join(" "))} | #{act.(r[:action])} |\n"
  }
  out << "\n## vim keymap only\n\nLeft out of vimlike on purpose (`VIM_KEYMAP_ONLY`, vim_core.rb).\n\n"
  out << "| Mode | Vim keys | Vim action | Why |\n|---|---|---|---|\n"
  by.fetch(:vim_only, []).each { |r|
    out << "| #{r[:mode]} | #{code.(r[:keys].join(" "))} | #{act.(r[:action])} | #{r[:why]} |\n"
  }
  out << "\n## Shared\n\n| Mode | Keys | Action |\n|---|---|---|\n"
  vim_conflict_rows_grouped(by.fetch(:shared, [])).each { |r|
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
