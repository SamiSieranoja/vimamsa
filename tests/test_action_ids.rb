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
    m = { "x" => [:test_ids_old, "test_ids_old", "buf.move(FORWARD_CHAR)"], "y" => ["move.word.next"] }
    assert vma.macro.convert_action_aliases(m)
    assert_eq ["test.ids.run", "test.ids.run", "buf.move(FORWARD_CHAR)"], m["x"]
    assert_eq ["move.word.next"], m["y"]
    assert !vma.macro.convert_action_aliases(m), "second pass changed something"
    # A macro still holding an old id runs
    vma.macro.run_actions([:test_ids_old, "test.ids.run"])
    assert_eq 2, @n
  ensure
    cleanup
  end

  # Step 2: duplicates merged into one action each; the old ids are aliases
  def test_duplicates_merged
    { "undo.last" => [:undo, :edit_undo], "undo.redo" => [:redo, :edit_redo],
      "jump.edit.prev" => [:jump_last_edit, :jump_to_last_edit],
      "move.char.prev" => [:move_backward_char, :e_move_backward_char],
      "move.line.next" => [:move_next_line, :forward_line],
      "move.line.prev" => [:move_prev_line, :backward_line],
      "grep.buf" => [:grep_buffer, :invoke_grep_search] }.each { |id, olds|
      assert vma.actions.ids.include?(id), "#{id} not registered"
      olds.each { |o|
        assert !vma.actions.ids.include?(o), "#{o} still registered on its own"
        assert vma.actions[o].equal?(vma.actions[id]), "#{o} doesn't resolve to #{id}"
      }
    }
    buf.set_content("ab\n")
    buf.set_pos(0)
    keys("x")         # vimlike x: delete char
    act(:edit_undo)   # old menu id still works
    assert_buf "ab\n"
  end

  # Ids registered only by another keymap, an optional module or a minor mode
  # set up on first use; not loaded in the test setup
  OPTIONAL_IDS = /\A(mode\.notepad|dictation|tts|ollama|terminal|calculator|color_highlight|fexp|bmgr|bmark|diffview)\./

  NAMESPACES = %w[app mode move jump search grep ack edit undo case sel buf file
                  panel view style macro mark lsp term help debug custom kbd op]

  # Registered actions other than Ruby-code bindings and the user's custom.rb
  # (eval'd, so its procs come from "(eval)")
  def own_actions
    vma.actions.ids.map { |k| [k, vma.actions[k]] }.reject { |_k, a|
      a.opt&.[](:code) || (a.method.respond_to?(:source_location) && a.method.source_location.to_a[0].to_s.start_with?("(eval"))
    }
  end

  def test_ids_are_dotted_with_known_namespace
    known = NAMESPACES + Dir[File.expand_path("../modules/*", __dir__)].map { |d| File.basename(d) } +
            vma.kbd.root.children.map(&:key_name) +
            %w[diffview] # minor mode created on first use
    bad = own_actions.map(&:first).reject { |k|
      k.class == String && k.match?(ACTION_ID_RE) && known.include?(k.split(".")[0])
    }
    assert bad.empty?, "ids not of the form <namespace>.x.y: #{bad.inspect}"
  end

  # Catches duplicates like undo / edit_undo
  def test_no_duplicate_actions
    by = own_actions.group_by { |_k, a|
      m = a.method
      [m.respond_to?(:source_location) ? m.source_location : m.inspect, a.method_name]
    }
    dups = by.values.select { |v| v.size > 1 }.map { |v| v.map(&:first) }
    assert dups.empty?, "same code and description: #{dups.inspect}"
  end

  # ── Step 4: using the hierarchy ──

  def test_path_replaces_group
    assert_eq ["move", "word", "next"], vma.actions["move.word.next"].path
    grouped = own_actions.select { |_k, a| a.opt&.key?(:group) }.map(&:first)
    assert grouped.empty?, ":group still set on #{grouped.inspect}"
  end

  def test_complete
    ns = vma.actions.complete("")
    assert ns.include?("move.") && ns.include?("buf."), ns.inspect
    m = vma.actions.complete("move.")
    assert m.include?("move.word.") && m.include?("move.random"), m.inspect
    assert m.all? { |c| c.start_with?("move.") }
    b = vma.actions.complete("buf.")
    assert b.include?("buf.save") && b.include?("buf.save."), "action and parent: #{b.inspect}"
  end

  def test_search_actions_namespace_filter
    rows = vma.actions.search_actions_update_callback("move.")
    assert rows.size > 5, rows.inspect
    assert rows.all? { |_key, str| str.start_with?("move.") }, rows.inspect
    assert rows.any? { |_key, str| str.start_with?("move.word.next  ") }, "no description shown"
    rows = vma.actions.search_actions_update_callback("move.wordnext")
    assert rows.all? { |_key, str| str.start_with?("move.") }, rows.inspect
    assert rows[0][1].start_with?("move.word.next"), rows.inspect
  end

  def test_search_actions_finds_old_id
    rows = vma.actions.search_actions_update_callback("close_current_buffer")
    assert rows[0][1].start_with?("buf.close"), rows.inspect
  end

  def test_cmdline_tab_completion
    cl = vma.gui.cmd_line
    e = cl.entry
    { "a.mov" => "a.move.", "a.move.wo" => "a.move.word.", "x = a.buf.sav" => "x = a.buf.save",
      "a.buf.save" => "a.buf.save", "foo.mov" => "foo.mov" }.each { |typed, want|
      e.text = typed
      e.set_position(-1)
      cl.complete_action_id
      assert_eq want, e.text
    }
    e.text = "a.mo"
    e.set_position(-1)
    assert_eq ["mode.", "move."], cl.complete_action_id
    e.text = ""
  end

  def test_every_alias_points_to_an_action
    bad = ACTION_ALIASES.reject { |_old, n| vma.actions.include?(n) || n.match?(OPTIONAL_IDS) }
    assert bad.empty?, "aliases to unregistered actions: #{bad.inspect}"
  end
end
