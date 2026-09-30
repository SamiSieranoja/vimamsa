class TestMacro < VmaTest
  LINE = "I am 1234 years and 56 days"
  EDITED = "I am 34 years and 56 days"

  # Buffer with the first +n_edited+ lines edited by the macro.
  def expected_buf(n_edited)
    ([EDITED] * n_edited + [LINE] * (5 - n_edited)).join("\n") + "\n"
  end

  # Fill the buffer with +n+ copies of +line+, cursor at the start.
  def set_lines(line, n)
    act "buf.insert_txt(#{([line] * n).join("\n").inspect})"
    act :jump_to_start_of_buffer
  end

  def recorded(slot)
    vma.macro.recorded_macros[slot]
  end

  # Record a macro that edits one line and moves to the next, then run it:
  #   w    -> start of "1234"            (col 5)
  #   x x  -> delete "12", leaving "34"  (col 5)
  #   b    -> start of "am"              (col 2)
  #   h    -> one char left              (col 1)
  #   j    -> next line, same column     (col 1)
  def test_run_recorded_macro
    set_lines(LINE, 5)
    act "buf.set_pos(2)"          # third character of the first line ("a")
    assert_pos 0, 2

    keys "q a"                    # start recording into slot "a"
    keys "w x x b h j"
    keys "q"                      # end recording
    assert_buf expected_buf(1)
    assert_pos 1, 1

    # Run the macro on lines 1..3; the last line must stay untouched.
    (1..3).each do |lpos|
      keys "l"                    # back to the third character
      assert_pos lpos, 2
      keys "@ a"
      assert_buf expected_buf(lpos + 1), "buffer mismatch after running macro on line #{lpos}"
      assert_pos lpos + 1, 1
    end
  end

  # Text typed in insert mode is part of the macro and is replayed.
  def test_macro_with_insert_mode_text
    set_lines("item1", 3)
    keys "q a A o k esc j q"
    assert_buf "item1ok\nitem1\nitem1\n"
    assert_mode :command

    keys "@ a"
    keys "@ a"
    assert_buf "item1ok\nitem1ok\nitem1ok\n"
    assert_mode :command
  end

  # A count before @ runs the macro that many times.
  def test_macro_with_count
    set_lines("abc", 5)
    keys "q a 0 x j q"
    assert_buf "bc\nabc\nabc\nabc\nabc\n"

    keys "3 @ a"
    assert_buf "bc\nbc\nbc\nbc\nabc\n"
    assert_pos 4, 0
  end

  # M runs the most recently recorded macro.
  def test_run_last_macro
    set_lines("abc", 3)
    keys "q b 0 x j q"
    keys "M"
    assert_buf "bc\nbc\nabc\n"
    assert_pos 2, 0
  end

  # Macros in different slots don't affect each other.
  def test_slots_are_independent
    set_lines("abcd", 4)
    keys "q a 0 x j q"            # delete the first char
    keys "q b 0 l x j q"          # delete the second char
    keys "@ a"
    keys "@ b"
    assert_buf "bcd\nacd\nbcd\nacd\n"
  end

  # Recording into a slot again replaces the old macro.
  def test_rerecording_replaces_macro
    set_lines("abcd", 4)
    keys "q a 0 x j q"            # delete the first char
    keys "q a 0 l x j q"          # now: delete the second char
    keys "@ a"
    assert_buf "bcd\nacd\nacd\nabcd\n"
  end

  # Running a slot with nothing recorded changes nothing.
  def test_run_empty_slot_is_noop
    vma.macro.recorded_macros.delete("z")
    set_lines("abc", 2)
    act "buf.set_pos(1)"
    keys "@ z"
    assert_buf "abc\nabc\n"
    assert_pos 0, 1
    assert_mode :command
  end

  # Every motion is recorded, so the replay ends where the recording did.
  # (Backward motions returned false from set_pos and were silently dropped.)
  def test_motions_replay_like_recording
    set_lines("ab cd ef", 3)
    act "buf.set_pos(12)"         # line 1, "cd"
    assert_pos 1, 3

    keys "q a 0 $ b e w h l j k q"
    assert_eq 9, recorded("a").size, "not every motion was recorded: #{recorded("a").inspect}"
    end_lpos, end_cpos = buf.lpos, buf.cpos

    act "buf.set_pos(12)"
    keys "@ a"
    assert_pos end_lpos, end_cpos
  end

  # @ is ignored while recording: nothing runs and nothing is recorded.
  def test_run_macro_while_recording_is_ignored
    set_lines("abc", 3)
    keys "q a 0 x j q"
    assert_buf "bc\nabc\nabc\n"

    keys "q b @ a j q"
    assert_buf "bc\nabc\nabc\n"
    assert_pos 2, 0
    assert_eq [:forward_line], recorded("b")
  end
end
