class TestGrepApply < VmaTest
  def setup_grep
    @orig_experimental = cnf.experimental?
    cnf.experimental = true
    @orig = vma.buf
    act 'buf.insert_txt("foo one\nbar\nfoo two\n")'
    Grep.new.callback("foo")
    drain_idle
    assert_buf "1:foo one\n3:foo two\n"
    assert_mode :grep
  end

  def edit_first_match
    act 'buf.set_pos(2)'
    keys "i X esc"
    assert_buf "1:Xfoo one\n3:foo two\n"
  end

  def test_ctrl_s_applies_changes
    setup_grep
    edit_first_match
    keys "ctrl-s"
    assert_eq "Xfoo one\nbar\nfoo two\n\n", @orig.to_s
  ensure
    cnf.experimental = @orig_experimental
  end

  def test_ctrl_s_in_insert_mode_applies_changes
    setup_grep
    edit_first_match
    keys "i ctrl-s"
    assert_eq "Xfoo one\nbar\nfoo two\n\n", @orig.to_s
    keys "esc"
  ensure
    cnf.experimental = @orig_experimental
  end

  def test_shift_no_longer_applies_changes
    setup_grep
    edit_first_match
    keys "shift"
    assert_eq "foo one\nbar\nfoo two\n\n", @orig.to_s
  ensure
    cnf.experimental = @orig_experimental
  end
end
