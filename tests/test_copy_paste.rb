class TestCopyPaste < VmaTest

  def test_copy_line_paste_after
    act 'buf.insert_txt("hello\n")'
    act "buf.jump(START_OF_BUFFER)"
    act :copy_cur_line
    act "buf.jump(END_OF_BUFFER)"
    act :paste_after_cursor
    assert_buf "hello\n\nhello\n"
  end

  def test_copy_line_paste_before
    act 'buf.insert_txt("hello\n")'
    act 'buf.insert_txt("world")'
    act "buf.jump(START_OF_BUFFER)"
    act :copy_cur_line
    act "buf.move(FORWARD_LINE)"
    act :paste_before_cursor
    assert_buf "hello\nhello\nworld\n"
  end

  def test_copy_paste_twice
    act 'buf.insert_txt("abc")'
    act "buf.jump(START_OF_BUFFER)"
    act :copy_cur_line
    act "buf.jump(END_OF_BUFFER)"
    act :paste_after_cursor
    act :paste_after_cursor
    assert_buf "abc\nabc\nabc\n"
  end

  def test_cut_selection_paste
    act 'buf.insert_txt("hello world")'
    act "buf.jump(START_OF_BUFFER)"
    # Select "hello" (5 chars)
    act "buf.start_selection"
    5.times { act "buf.move(FORWARD_CHAR)" }
    act :cut_selection
    assert_buf " world\n"
    act "buf.jump(END_OF_LINE)"
    act :paste_after_cursor
    assert_buf " worldhello\n"
  end

  def test_copy_selection_paste
    act 'buf.insert_txt("foo bar")'
    act "buf.jump(START_OF_BUFFER)"
    act "buf.start_selection"
    3.times { act "buf.move(FORWARD_CHAR)" }
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
    act "buf.jump(START_OF_BUFFER)"
    act :copy_cur_line
    assert_eq "myline\n", vma.clipboard.get
  end

  def test_cut_selection_updates_clipboard
    act 'buf.insert_txt("hello")'
    act "buf.jump(START_OF_BUFFER)"
    act "buf.start_selection"
    3.times { act "buf.move(FORWARD_CHAR)" }
    act :cut_selection
    assert_eq "hel", vma.clipboard.get
  end

  def test_paste_multiline
    act 'buf.insert_txt("line1\nline2\nline3")'
    act "buf.jump(START_OF_BUFFER)"
    act :copy_cur_line
    act "buf.jump(END_OF_BUFFER)"
    act :paste_after_cursor
    assert_buf "line1\nline2\nline3\n\nline1\n"
  end

end
