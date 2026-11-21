# Structured binding records (KeyBindingTree#bindings) and the categories of
# the key bindings page (doc/key_bindings_report_plan.md steps 1-2).
class TestKeyCategories < VmaTest
  def find(kbd, mode, keys)
    kbd.bindings.find { |b| b[:mode] == mode && b[:keys].join(" ") == keys }
  end

  def test_binding_records
    b = find(vma.kbd, "C", "d i <char>")
    assert !b.nil?, "text object binding missing"
    assert b[:keywords].include?("text"), b.inspect
    u = find(vma.kbd, "C", "u")
    assert_eq "undo.last", u[:action]
    assert_eq "Undo the last action", u[:desc] # dotted ids show their description
    g = find(vma.kbd, "C", "G(vma.kbd.next_command_count!=nil)")
    assert !g.nil?, "condition missing from keys"
    # an action on a node that also has longer bindings below it
    assert !find(vma.kbd, "C", "z").nil?, "C z (browse mode) not listed"
  end

  # Every binding of every keymap has a category, so nothing lands in a
  # catch-all section. A new binding without one fails here: give it a named
  # action, or put it in an add_keys block tagged "cat:<id>".
  def test_every_binding_has_a_category
    [["vimlike"], ["vim"], ["vimlike", "notepad"]].each { |scheme|
      kbd = load_scheme_kbd(scheme)
      bad = kbd.bindings.select { |b| key_binding_category(b, kbd).nil? }
      assert bad.empty?, "#{scheme.join("+")}: no category for " +
                         bad.map { |b| "#{b[:mode]} #{b[:keys].join(" ")} => #{b[:action].inspect}" }.inspect
    }
  end

  # The running tree also has the bindings of modules, minor modes and
  # custom.rb (other tests leave ad-hoc bindings in it, so only those are checked)
  def test_live_bindings_have_known_categories
    ids = KEY_CATEGORIES.map(&:first)
    vma.kbd.bindings.each { |b|
      from_context = b[:mode].match?(/\A\p{Ll}/) || b[:keywords].any? { |k| k == "custom" || k.start_with?("module:") }
      next if !from_context
      c = key_binding_category(b)
      assert !c.nil?, "no category: #{b[:mode]} #{b[:keys].join(" ")} => #{b[:action].inspect}"
      assert ids.include?(c) || c.start_with?("module:", "mode:"), "unknown category #{c.inspect}"
    }
  end

  def test_categories_from_namespace_mode_and_context
    kbd = KeyBindingTree.new(actions: ActionList.new)
    kbd.add_mode("C", :command)
    kbd.add_minor_mode("fexp", :file_exp, :command)
    kbd.bindkey("C , Q 1", "move.word.next")
    kbd.bindkey("fexp , Q 2", "move.word.next")
    kbd.with_keywords(["module:foo"]) { kbd.bindkey("C , Q 3", "foo_bar()") }
    kbd.bindkey("C , Q 4", "foo_bar()", keywords: "cat:edit")
    kbd.bindkey("C , Q 5", "foo_bar()")
    cat = ->(k) { key_binding_category(find(kbd, k.split[0], k.split[1..].join(" ")), kbd) }
    assert_eq "motion", cat.("C , Q 1")
    assert_eq "mode:fexp", cat.("fexp , Q 2")
    assert_eq "module:foo", cat.("C , Q 3")
    assert_eq "edit", cat.("C , Q 4")
    assert_eq nil, cat.("C , Q 5")
    assert kbd.extra_keywords.empty?, "with_keywords leaked"
  end

  def test_page_sections
    show_key_bindings
    s = vma.buf.to_s
    begin
      heads = s.scan(/^◼ (.+)$/).flatten
      assert heads.include?("Moving the cursor") && heads.include?("Text objects"), heads.inspect
      assert heads.index("Moving the cursor") < heads.index("Text objects")
      assert !heads.include?("Others"), heads.inspect
      # bindings other tests left behind may be uncategorized: last, if at all
      assert !heads.include?("Uncategorized") || heads.last == "Uncategorized", heads.inspect
      assert s.include?("Undo the last action"), "descriptions missing"
    ensure
      vma.buffers.close_buffer(vma.buf.id)
    end
  end

  # Step 3: rows merged across modes and keys, grouped by modes, conditions
  # as text, definition order
  def test_section_layout
    kbd = KeyBindingTree.new(actions: ActionList.new)
    kbd.add_mode("C", :command)
    kbd.add_mode("V", :visual, :visual)
    kbd.bindkey("VC , Q 2", "move.word.next")
    kbd.bindkey("VC , Q 1", "move.word.next")
    kbd.bindkey("C , Q 3(vma.kbd.next_command_count!=nil)", "move.word.next")
    kbd.bindkey("C , Q 4(foo_bar)", "move.word.prev")
    w = ", Q 2 / , Q 1".size
    assert_eq ["◼◼ Command, Visual",
               "    , Q 2 / , Q 1  move.word.next",
               "◼◼ Command",
               "    #{", Q 3".ljust(w)}  move.word.next (with a count)",
               "    #{", Q 4".ljust(w)}  move.word.prev (if foo_bar)"],
              key_bindings_section(kbd.bindings)
  end

  def test_page_layout
    s = key_bindings_page(vma.kbd, scheme: "vimlike")
    assert s.start_with?("❙Key bindings — scheme: vimlike❙"), s[0, 80]
    heads = s.scan(/^◼ (.+)$/).flatten
    assert_eq "Basics", heads[0]
    basics = s[/^◼ Basics\n(.*?)\n\n/m, 1]
    assert basics.include?(vma.actions["undo.last"].method_name), basics
    assert s.include?("(with a count)"), "condition text missing"
    assert !s.include?("(vma.kbd.next_command_count"), "raw condition shown"
    motion = s[/^◼ Moving the cursor\n(.*?)\n\n/m, 1]
    e, b = %w[move.word.end move.word.prev].map { |id| motion.index(vma.actions[id].method_name) }
    assert e && b && e < b, "not in definition order:\n#{motion}"
    assert motion.include?("◼◼ Command, Visual"), motion
  end

  # doc/action_names_plan.md step 6: every binding of every keymap runs a
  # named action with a description, not Ruby code. A new Ruby-string
  # binding fails here: register an action (reg_act) and bind its id.
  # Readchar mode ("R <char>") is internal and not named.
  def test_every_binding_has_a_description
    [["vimlike"], ["vim"], ["vimlike", "notepad"]].each { |scheme|
      kbd = load_scheme_kbd(scheme)
      bad = kbd.bindings.reject { |b|
        next true if b[:mode] == "R"
        act = b[:action]
        next false if act.class == Proc
        r = [kbd.actions, vma.actions].map { |l| l[act] }.find { |x| x && !x.opt&.[](:code) }
        r && !r.method_name.to_s.strip.empty? && r.method_name.to_s != act.to_s
      }
      assert bad.empty?, "#{scheme.join("+")}: no description for " +
                         bad.map { |b| "#{b[:mode]} #{b[:keys].join(" ")} => #{b[:action].inspect}" }.inspect
    }
  end

  # A named action bound to a <char> key gets the typed character
  def test_char_argument
    buf.set_content("abc\n")
    buf.set_pos(0)
    keys("f c")       # jump.char.next
    assert_pos 0, 2
    keys("r x")       # edit.replace.char
    assert_buf "abx\n"
    keys("m q")       # mark.set
    keys("0")
    keys("' q")       # mark.jump
    assert_pos 0, 2
    keys("i z esc")   # edit.insert.char
    assert_buf "abzx\n"
  end

  # The character reaches the action also when a macro replays it
  def test_char_argument_in_macro
    buf.set_content("abc\n")
    buf.set_pos(0)
    keys("q w r y q") # macro.record w, edit.replace.char y, macro.record.stop
    assert_buf "ybc\n"
    keys("l @ w")     # macro.run w
    assert_buf "yyc\n"
  end
end
