class TestCommandLine < VmaTest
  def cl
    vma.gui.cmd_line
  end

  def last_message
    vma.gui.instance_variable_get(:@minibuf_messages).first.to_s
  end

  def test_ruby_eval_echoes_result
    cl.execute("21 * 2")
    drain_idle
    assert last_message.include?("=> 42"), "eval result echoed, got: #{last_message.inspect}"
  end

  def test_ruby_can_edit_buffer
    cl.execute("buf.insert_txt('hello')")
    drain_idle
    assert_buf "hello\n"
  end

  def test_config_change_via_ruby
    prev = cnf.tab.width!
    cl.execute("cnf.tab.width = 8")
    assert_eq 8, cnf.tab.width!, "config changed via command line"
  ensure
    cnf.tab.width = prev
  end

  def test_ruby_error_is_caught
    cl.execute("nonexistent_method_xyz_123")
    drain_idle
    assert last_message.include?("ERROR:"), "error shown, got: #{last_message.inspect}"
  end

  def test_ruby_syntax_error_is_caught
    cl.execute("def broken(")
    drain_idle
    assert last_message.include?("ERROR:"), "syntax error shown, got: #{last_message.inspect}"
  end

  def test_bare_number_jumps_to_line
    vma.buf.set_content("one\ntwo\nthree\nfour\nfive\n")
    drain_idle
    cl.execute("3")
    drain_idle
    assert_eq 2, vma.buf.lpos, "jumped to line 3 (lpos 2)"
  end

  def test_shell_command_output_to_buffer
    cl.execute("!echo vmatest_shell_output")
    found = false
    50.times do
      drain_idle
      if vma.buf.to_s.include?("vmatest_shell_output")
        found = true
        break
      end
      sleep 0.1
    end
    assert found, "shell output opened in a new buffer"
  end

  def test_history_records_commands
    cl.execute("1 + 1")
    cl.execute("2 + 2")
    assert_eq "2 + 2", cl.history.last, "newest command last in history"
    assert cl.history.include?("1 + 1"), "older command kept in history"
  end

  def test_open_and_close
    act :start_cmd_line
    stack = vma.gui.instance_variable_get(:@minibuf_stack)
    assert_eq "cmdline", stack.visible_child_name, "command line shown"
    cl.close
    drain_idle
    assert stack.visible_child_name != "cmdline", "command line hidden after close"
  end
end
