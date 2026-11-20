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
    act "move.buf.start"
    act "edit.line.copy"
    act "move.buf.end"
    act "edit.paste.after"
    assert_buf "hello\n\nhello\n"
  end

  def test_copy_line_paste_before
    act 'buf.insert_txt("hello\n")'
    act 'buf.insert_txt("world")'
    act "move.buf.start"
    act "edit.line.copy"
    act "buf.move(FORWARD_LINE)"
    act "edit.paste.before"
    assert_buf "hello\nhello\nworld\n"
  end

  def test_copy_paste_twice
    act 'buf.insert_txt("abc")'
    act "move.buf.start"
    act "edit.line.copy"
    act "move.buf.end"
    act "edit.paste.after"
    act "edit.paste.after"
    assert_buf "abc\nabc\nabc\n"
  end

  def test_cut_selection_paste
    act 'buf.insert_txt("hello world")'
    act "move.buf.start"
    # Select "hello" (5 chars)
    act "buf.start_selection"
    4.times { act "buf.move(FORWARD_CHAR)" }
    act :cut_selection
    assert_buf " world\n"
    act "buf.jump(END_OF_LINE)"
    act "edit.paste.after"
    assert_buf " worldhello\n"
  end

  def test_copy_selection_paste
    act 'buf.insert_txt("foo bar")'
    act "move.buf.start"
    act "buf.start_selection"
    2.times { act "buf.move(FORWARD_CHAR)" }
    act :copy_selection
    # Original buffer unchanged
    assert_buf "foo bar\n"
    act "buf.jump(END_OF_LINE)"
    act "edit.paste.after"
    assert_buf "foo barfoo\n"
  end

  def test_clipboard_set_get
    vma.clipboard.set("testvalue")
    assert_eq "testvalue", vma.clipboard.get
  end

  def test_copy_line_updates_clipboard
    act 'buf.insert_txt("myline")'
    act "move.buf.start"
    act "edit.line.copy"
    assert_eq "myline\n", vma.clipboard.get
  end

  def test_cut_selection_updates_clipboard
    act 'buf.insert_txt("hello")'
    act "move.buf.start"
    act "buf.start_selection"
    2.times { act "buf.move(FORWARD_CHAR)" }
    act :cut_selection
    assert_eq "hel", vma.clipboard.get
  end

  def test_paste_multiline
    act 'buf.insert_txt("line1\nline2\nline3")'
    act "move.buf.start"
    act "edit.line.copy"
    act "move.buf.end"
    act "edit.paste.after"
    assert_buf "line1\nline2\nline3\nline1\n"
  end

  # --- Async paste position capture ------------------------------------------
  # paste_start reads the clipboard asynchronously; its callback (paste_finish)
  # may run after the cursor has moved.  These tests drive paste_finish directly
  # with the position/state captured at request time (ipos/paste_lines) while
  # the live cursor sits elsewhere, simulating that race.  The paste must land
  # where it was initiated, not at the moved cursor.

  def test_async_paste_inserts_at_captured_position
    act 'buf.insert_txt("line one\nline two\n")'
    act "move.buf.start"
    ipos = buf.pos                 # where the user pressed paste
    vma.clipboard << "X"
    act "move.buf.end"     # cursor moves away during the async read
    buf.paste_finish("X", AFTER, nil, ipos: ipos)
    assert_buf "lXine one\nline two\n\n"
  end

  def test_async_paste_line_mode_uses_captured_state
    act 'buf.insert_txt("AAA\nBBB\nCCC\n")'
    act "move.buf.start"
    act "edit.line.copy"             # clipboard = "AAA\n", @paste_lines = true
    ipos = buf.pos
    act "move.buf.end"     # cursor moves to the last line
    buf.paste_finish("AAA\n", AFTER, nil, ipos: ipos, paste_lines: true)
    assert_buf "AAA\nAAA\nBBB\nCCC\n\n"
  end

  # Without a captured position (synchronous/macro path) the live cursor is
  # used, preserving prior behavior.
  def test_paste_finish_without_capture_uses_live_cursor
    act 'buf.insert_txt("line one\nline two\n")'
    act "move.buf.start"
    vma.clipboard << "X"
    buf.paste_finish("X", AFTER, nil)
    assert_buf "lXine one\nline two\n\n"
  end

  # --- Copy to mark (y'a) ----------------------------------------------------
  # copy(:to_mark) yanks the same range delete2(:to_mark) removes: from the end
  # of the current line to the mark position.
  def test_copy_to_mark
    act 'buf.insert_txt("AAA\nBBB\nCCC\n")'
    act "buf.set_pos(8)"                     # start of "CCC"
    act "buf.mark_current_position('a')"
    act "move.buf.start"             # cursor back on line 0
    act "buf.copy(:to_mark, 'a')"
    assert_eq "\nBBB\nC", vma.clipboard.get
    assert_buf "AAA\nBBB\nCCC\n\n"           # buffer unchanged by a copy
  end

  def test_copy_to_undefined_mark_is_noop
    act 'buf.insert_txt("hello")'
    vma.clipboard.set("PREVIOUS")
    act "buf.copy(:to_mark, 'z')"            # mark 'z' was never set
    assert_eq "PREVIOUS", vma.clipboard.get  # clipboard untouched
    assert_buf "hello\n"
  end

end
