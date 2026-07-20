# Tests for vim-style marker folds ({{{ ... }}}) — see lib/vimamsa/fold.rb.
# Enter on a fold-start / placeholder line toggles the fold; the folded body is
# extracted from the buffer and re-inflated for any disk write.

class TestFold < VmaTest

  BLOCK = "{{{ Title\nline a\nline b\n}}}\n"
  COLLAPSED = "{{{ Title  ⟨4 lines⟩\n"

  # Seed the buffer with `text` and park the cursor on line 0, command mode.
  # The fresh test buffer is already "\n", so chomp `text`'s trailing newline to
  # avoid a doubled final blank line.
  def seed(text)
    act "buf.insert_txt(#{text.chomp.inspect})"
    act "buf.set_pos(0)"
  end

  def test_close_collapses_block
    seed(BLOCK)
    keys("enter")               # Enter on the {{{ line closes the fold
    assert_buf COLLAPSED
  end

  def test_open_restores_block_exactly
    seed(BLOCK)
    keys("enter")               # close
    assert_buf COLLAPSED
    keys("enter")               # Enter on the placeholder re-opens it
    assert_buf BLOCK            # byte-exact round-trip
  end

  # The core Approach-B correctness guarantee: while collapsed, the on-disk
  # serialisation must still be the fully expanded text.
  def test_content_for_disk_is_inflated_while_closed
    seed(BLOCK)
    keys("enter")
    assert_buf COLLAPSED
    assert_eq BLOCK, vma.buf.content_for_disk
  end

  # Folding must not clobber the clipboard (uses add_delta, not delete_range).
  def test_close_does_not_touch_clipboard
    seed(BLOCK)
    before = vma.clipboard.get()
    keys("enter")
    assert_eq before, vma.clipboard.get()
  end

  # A single undo reverses a close.
  def test_undo_reverses_close
    seed(BLOCK)
    keys("enter")
    assert_buf COLLAPSED
    act :undo
    assert_buf BLOCK
  end

  # Enter on an ordinary (non-fold) line does not consume the key as a fold
  # toggle — the buffer text is unchanged by the toggle path.
  def test_enter_on_plain_line_is_not_a_fold
    seed("hello\nworld\n")
    act "buf.set_pos(0)"        # line 0 = "hello", not a fold marker
    keys("enter")
    # fold_toggle_at returns false; buffer text is not collapsed.
    assert_eq false, vma.buf.fold_toggle_at(0)
    assert_buf "hello\nworld\n"
  end

  # A fold containing a nested fold collapses to one line and round-trips.
  def test_nested_fold_round_trip
    nested = "{{{ outer\na\n{{{ inner\nb\n}}}\nc\n}}}\n"
    seed(nested)
    keys("enter")               # close outer
    assert_eq "{{{ outer  ⟨7 lines⟩\n", vma.buf.to_s
    assert_eq nested, vma.buf.content_for_disk
    keys("enter")               # open outer
    assert_buf nested
  end
end
