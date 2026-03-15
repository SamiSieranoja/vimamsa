class TestUndo < VmaTest

  # ── Basic undo / redo ────────────────────────────────────────────────────

  def test_undo_restores_empty_buffer
    act 'buf.insert_txt("hello")'
    act :undo
    assert_buf "\n"
  end

  def test_undo_on_empty_buffer_is_noop
    act :undo
    assert_buf "\n"
  end

  def test_redo_after_undo
    act 'buf.insert_txt("hello")'
    act :undo
    act :redo
    assert_buf "hello\n"
  end

  def test_redo_on_empty_stack_is_noop
    act :undo
    act :redo
    assert_buf "\n"
  end

  def test_new_edit_clears_redo_stack
    act 'buf.insert_txt("hello")'
    act :undo
    assert_buf "\n"
    act 'buf.insert_txt("world")'
    # redo stack was cleared — redo should be a no-op
    act :redo
    assert_buf "world\n"
  end

  def test_undo_delete_char
    act 'buf.insert_txt("abcde")'
    act :jump_to_start_of_buffer
    vma.buf.new_undo_group
    act :delete_char_forward
    act :delete_char_forward
    vma.buf.new_undo_group
    assert_buf "cde\n"
    act :undo
    assert_buf "abcde\n"
  end

  def test_undo_delete_line
    act 'buf.insert_txt("first\n")'
    act 'buf.insert_txt("second")'
    vma.buf.new_undo_group
    act :jump_to_start_of_buffer
    act :delete_line
    vma.buf.new_undo_group
    assert_buf "second\n"
    act :undo
    assert_buf "first\nsecond\n"
  end

  def test_undo_redo_multiple_times
    act 'buf.insert_txt("first")'
    vma.buf.new_undo_group
    act 'buf.insert_txt(" second")'
    assert_buf "first second\n"

    act :undo
    assert_buf "first\n"
    act :redo
    assert_buf "first second\n"
    act :undo
    assert_buf "first\n"
    act :undo
    assert_buf "\n"
  end

  # ── Explicit group boundaries ─────────────────────────────────────────────

  def test_new_undo_group_creates_separate_steps
    act 'buf.insert_txt("aaa")'
    vma.buf.new_undo_group
    act 'buf.insert_txt("bbb")'
    vma.buf.new_undo_group
    act 'buf.insert_txt("ccc")'
    vma.buf.new_undo_group
    assert_buf "aaabbbccc\n"

    act :undo
    assert_buf "aaabbb\n"
    act :undo
    assert_buf "aaa\n"
    act :undo
    assert_buf "\n"
  end

  # ── Mode-change group boundaries ─────────────────────────────────────────

  def test_mode_change_creates_undo_group_boundary
    # Each insert-mode session should be a separate undo group
    keys "i h e l l o esc"
    keys "i space w o r l d esc"
    assert_buf "hello world\n"

    act :undo
    assert_buf "hello\n"  # second insert session (" world") undone
    act :undo
    assert_buf "\n"       # first insert session ("hello") undone
  end

  # ── Macro undo ────────────────────────────────────────────────────────────

  def test_macro_run_is_single_undo_group
    # An entire macro run should collapse into one undo step
    vma.macro.run_actions([
      'buf.insert_txt("line1\n")',
      'buf.insert_txt("line2\n")',
      'buf.insert_txt("line3")',
    ])
    drain_idle
    assert_buf "line1\nline2\nline3\n"

    act :undo
    assert_buf "\n"
  end

  def test_macro_multiple_runs_each_undoable_separately
    # Each run of the macro should be its own undo group
    vma.macro.run_actions(['buf.insert_txt("abc")'])
    drain_idle
    vma.macro.run_actions(['buf.insert_txt("def")'])
    drain_idle
    assert_buf "abcdef\n"

    act :undo
    assert_buf "abc\n"
    act :undo
    assert_buf "\n"
  end

  def test_macro_does_not_undo_pre_existing_content
    # Content that existed before the macro run should survive macro undo
    act 'buf.insert_txt("base")'
    vma.buf.new_undo_group
    vma.macro.run_actions(['buf.insert_txt(" appended")'])
    drain_idle
    assert_buf "base appended\n"

    act :undo
    assert_buf "base\n"
    act :undo
    assert_buf "\n"
  end

  def test_macro_record_and_run_then_undo
    # Record a macro via key sequence, run it, then undo each step
    keys "q a"              # start recording into slot "a"
    keys "i f o o esc"      # insert "foo", return to (macro) command mode
    keys "q"                # end recording
    drain_idle
    assert_buf "foo\n"      # recording-time insertion is in the buffer

    vma.macro.run_macro("a")
    drain_idle
    assert_buf "foofoo\n"

    act :undo               # undo the macro run
    assert_buf "foo\n"
    act :undo               # undo the recording-time insertion
    assert_buf "\n"
  end

  def test_macro_redo_after_undo
    vma.macro.run_actions(['buf.insert_txt("hello")'])
    drain_idle
    assert_buf "hello\n"

    act :undo
    assert_buf "\n"
    act :redo
    assert_buf "hello\n"
  end

  def test_macro_with_delete_is_single_undo_group
    act 'buf.insert_txt("hello world")'
    vma.buf.new_undo_group

    # Macro that jumps to start and deletes a word
    vma.macro.run_actions([
      'buf.jump(BEGINNING_OF_LINE)',
      'buf.delete2(:to_word_end)',
    ])
    drain_idle
    assert_buf " world\n"

    act :undo
    assert_buf "hello world\n"
  end

end
