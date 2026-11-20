# Dotted action ids, the a.… reference and old-id aliases
# (doc/action_names_plan.md, step 1).
class TestActionIds < VmaTest
  KEYS = %w[1 2 3 4 5].map { |n| "C , Q Q #{n}" }

  def setup_counter
    @n = 0
    reg_act("test.ids.run", proc { @n += 1 }, "Test action")
  end

  def cleanup
    KEYS.each { |k| unbindkey(k) rescue nil }
    unreg_act("test.ids.run")
    ACTION_ALIASES.delete(:test_ids_old)
  end

  def test_string_id_registers_and_runs
    setup_counter
    assert vma.actions.include?("test.ids.run")
    assert vma.actions.include?(a.test.ids.run), "a.… reference not resolved"
    act("test.ids.run")
    a.test.ids.run!
    assert_eq 2, @n
  ensure
    cleanup
  end

  def test_bindkey_accepts_string_and_reference
    setup_counter
    bindkey KEYS[0], "test.ids.run"
    bindkey KEYS[1], a.test.ids.run
    keys(", Q Q 1")
    keys(", Q Q 2")
    assert_eq 2, @n
    assert_eq ", Q Q 2", vma.kbd.act_bindings["C"]["test.ids.run"]
  ensure
    cleanup
  end

  def test_old_id_alias
    setup_counter
    ACTION_ALIASES[:test_ids_old] = "test.ids.run"
    assert vma.actions.include?(:test_ids_old)
    bindkey KEYS[2], :test_ids_old
    keys(", Q Q 3")
    act(:test_ids_old)
    act("test_ids_old") # as a macro stored in JSON has it
    assert_eq 3, @n
    # the binding is stored under the new id
    assert_eq ", Q Q 3", vma.kbd.act_bindings["C"]["test.ids.run"]
  ensure
    cleanup
  end

  def test_unknown_reference_is_an_error_with_suggestion
    setup_counter
    msgs = []
    old = vma.kbd.error_handler
    vma.kbd.error_handler = proc { |m| msgs << m }
    begin
      bindkey KEYS[3], a.test.ids.rnu
    ensure
      vma.kbd.error_handler = old
    end
    assert msgs.any? { |m| m.include?("test.ids.rnu") && m.include?("did you mean test.ids.run") }, msgs.inspect
    assert !vma.kbd.act_bindings["C"].key?("test.ids.rnu"), "typo was bound"
    err = (a.test.ids.rnu! rescue $!)
    assert err.message.include?("did you mean test.ids.run"), err.message
  ensure
    cleanup
  end

  # BasicObject proxy: names Object defines are path segments too
  def test_reference_paths
    assert_eq "move.line.end", a.move.line.end.to_s
    assert_eq "app.class.send.display", a.app.class.send.display.to_s
    assert_eq "a.buf.save.as", a.buf.save.as.inspect
    assert_eq "x buf.save", "x #{a.buf.save}"
  end

  # A registered id wins over running the string as Ruby; other strings,
  # including bound Ruby code, still run as Ruby
  def test_registered_id_wins_over_ruby
    got = nil
    reg_act("buf.lines", proc { got = :action }, "Test")
    exec_action("buf.lines")
    assert_eq :action, got
    unreg_act("buf.lines")
    assert_eq vma.buf.lines, exec_action("buf.lines")

    bindkey KEYS[4], "vma.buf.set_content('ruby ran')"
    keys(", Q Q 5")
    assert vma.buf.to_s.start_with?("ruby ran"), vma.buf.to_s.inspect
  ensure
    unreg_act("buf.lines")
    cleanup
  end

  def test_command_line_runs_reference
    setup_counter
    eval("a.test.ids.run!", TOPLEVEL_BINDING)
    assert_eq 1, @n
  ensure
    cleanup
  end

  def test_macros_convert_old_ids
    setup_counter
    ACTION_ALIASES[:test_ids_old] = "test.ids.run"
    m = { "x" => [:test_ids_old, "test_ids_old", "buf.move(FORWARD_CHAR)"], "y" => [:paste_after_cursor] }
    assert vma.macro.convert_action_aliases(m)
    assert_eq ["test.ids.run", "test.ids.run", "buf.move(FORWARD_CHAR)"], m["x"]
    assert_eq [:paste_after_cursor], m["y"]
    assert !vma.macro.convert_action_aliases(m), "second pass changed something"
    # A macro still holding an old id runs
    vma.macro.run_actions([:test_ids_old, "test.ids.run"])
    assert_eq 2, @n
  ensure
    cleanup
  end

  def test_every_alias_points_to_an_action
    bad = ACTION_ALIASES.reject { |_old, n| vma.actions.include?(n) }
    assert bad.empty?, "aliases to unregistered actions: #{bad.inspect}"
  end
end
