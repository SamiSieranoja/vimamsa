class TestBasicEditing < VmaTest

  def test_insert_text
    act 'buf.insert_txt("hello")'
    assert_buf "hello\n"
  end

  def test_delete_char_forward
    act 'buf.insert_txt("abcde")'
    act :jump_to_start_of_buffer
    act :delete_char_forward
    act :delete_char_forward
    assert_buf "cde\n"
  end

  def test_delete_backward
    act 'buf.insert_txt("abcde")'
    act "buf.delete(BACKWARD_CHAR)"
    act "buf.delete(BACKWARD_CHAR)"
    assert_buf "abc\n"
  end

  def test_undo_redo
    act 'buf.insert_txt("hello")'
    assert_buf "hello\n"
    act :undo
    assert_buf "\n"
    act :redo
    assert_buf "hello\n"
  end

  def test_new_line
    act 'buf.insert_txt("first")'
    act 'buf.insert_txt("\n")'
    act 'buf.insert_txt("second")'
    assert_buf "first\nsecond\n"
  end

  def test_jump_start_end
    act 'buf.insert_txt("hello")'
    act :jump_to_start_of_buffer
    assert_pos 0, 0
    act :jump_to_end_of_buffer
    assert_pos 0, 5
  end

  def test_copy_paste
    #Note: Buffer contains a single "\n" by default
    act 'buf.insert_txt("hello\n")'
    act :jump_to_start_of_buffer
    act :copy_cur_line
    act :jump_to_end_of_buffer
    act :paste_after_cursor
    assert_buf "hello\n\nhello\n"
  end

  def test_delete_line
    act 'buf.insert_txt("first\n")'
    act 'buf.insert_txt("second")'
    act :jump_to_start_of_buffer
    act :delete_line
    assert_buf "second\n"
  end

end

class TestKeySequences < VmaTest

  def test_insert_mode_via_keys
    # 'i' enters insert mode in command mode
    keys "i"
    assert_mode :insert
    keys "esc"
    assert_mode :command
  end

  def test_type_and_escape
    keys "i"
    # Type individual characters
    "hello".each_char { |c| keys c }
    keys "esc"
    assert_buf "hello\n"
    assert_mode :command
  end

end
