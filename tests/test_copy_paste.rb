class TestCopyPaste < VmaTest

  # On Wayland, read_text_async reads from whatever process currently owns the
  # system clipboard.  GTK processes Wayland events during drain_idle and may
  # transfer clipboard ownership to another app between our set_system_clipboard
  # call and the async read callback, returning stale external content.
  #
  # Tests only need to verify in-editor copy/paste logic, not cross-app
  # clipboard round-trips, so we force the synchronous internal-clipboard path
  # (the same one used during macro playback) for all paste actions.
  PASTE_ACTIONS = %i[paste_after_cursor paste_before_cursor
                     paste_over_after paste_over_before].freeze

  def act(action)
    if PASTE_ACTIONS.include?(action)
      vma.macro.instance_variable_set(:@running_macro, true)
      exec_action(action)
      vma.macro.instance_variable_set(:@running_macro, false)
      drain_idle
    else
      super
    end
  end

  def test_copy_line_paste_after
    act 'buf.insert_txt("hello\n")'
    act :jump_to_start_of_buffer
    act :copy_cur_line
    act :jump_to_end_of_buffer
    act :paste_after_cursor
    assert_buf "hello\n\nhello\n"
  end

  def test_copy_line_paste_before
    act 'buf.insert_txt("hello\n")'
    act 'buf.insert_txt("world")'
    act :jump_to_start_of_buffer
    act :copy_cur_line
    act "buf.move(FORWARD_LINE)"
    act :paste_before_cursor
    assert_buf "hello\nhello\nworld\n"
  end

  def test_copy_paste_twice
    act 'buf.insert_txt("abc")'
    act :jump_to_start_of_buffer
    act :copy_cur_line
    act :jump_to_end_of_buffer
    act :paste_after_cursor
    act :paste_after_cursor
    assert_buf "abc\nabc\nabc\n"
  end

  def test_cut_selection_paste
    act 'buf.insert_txt("hello world")'
    act :jump_to_start_of_buffer
    # Select "hello" (5 chars)
    act "buf.start_selection"
    4.times { act "buf.move(FORWARD_CHAR)" }
    act :cut_selection
    assert_buf " world\n"
    act "buf.jump(END_OF_LINE)"
    act :paste_after_cursor
    assert_buf " worldhello\n"
  end

  def test_copy_selection_paste
    act 'buf.insert_txt("foo bar")'
    act :jump_to_start_of_buffer
    act "buf.start_selection"
    2.times { act "buf.move(FORWARD_CHAR)" }
    act :copy_selection
    # Original buffer unchanged
    assert_buf "foo bar\n"
    act "buf.jump(END_OF_LINE)"
    act :paste_after_cursor
    assert_buf "foo barfoo\n"
  end

  def test_clipboard_set_get
    vma.clipboard.set("testvalue")
    assert_eq "testvalue", vma.clipboard.get
  end

  def test_copy_line_updates_clipboard
    act 'buf.insert_txt("myline")'
    act :jump_to_start_of_buffer
    act :copy_cur_line
    assert_eq "myline\n", vma.clipboard.get
  end

  def test_cut_selection_updates_clipboard
    act 'buf.insert_txt("hello")'
    act :jump_to_start_of_buffer
    act "buf.start_selection"
    2.times { act "buf.move(FORWARD_CHAR)" }
    act :cut_selection
    assert_eq "hel", vma.clipboard.get
  end

  def test_paste_multiline
    act 'buf.insert_txt("line1\nline2\nline3")'
    act :jump_to_start_of_buffer
    act :copy_cur_line
    act :jump_to_end_of_buffer
    act :paste_after_cursor
    assert_buf "line1\nline2\nline3\nline1\n"
  end

end
