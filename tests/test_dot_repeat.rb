# "." repeats the last change (dot_repeat.rb, doc/vim_compatibility_plan.md
# step 4). The vim keymap has oracle tests against real vim in
# test_vim_bindings.rb.
class TestDotRepeat < VmaTest
  def setup_text(s, pos = 0)
    buf.set_content(s)
    buf.set_pos(pos)
    vma.kbd.set_mode(:command)
  end

  def test_repeat_delete
    setup_text("a b c d\n")
    keys("d w .")
    assert_buf "c d\n"
  end

  def test_repeat_change_with_typed_text
    setup_text("one two three\n")
    keys("c w f o o esc w .")
    assert_buf "foo foo three\n"
    assert_mode :command
  end

  def test_repeat_insert
    setup_text("ab\n")
    keys("i x y esc 0 .")
    assert_buf "xyxyab\n"
  end

  def test_count_replaces_the_changes_count
    setup_text("a b c d e\n")
    keys("d w 2 .")
    assert_buf "d e\n"
  end

  def test_repeat_is_one_undo_step
    setup_text("one two three\n")
    keys("c w f o o esc w .")
    keys("u")
    assert_buf "foo two three\n"
  end

  def test_motions_dont_replace_the_change
    setup_text("a b c d e\n")
    keys("d w w .")
    assert_buf "b d e\n"
  end

  def test_repeat_uses_the_same_register
    setup_text("1\n2\n3\n")
    keys('" a d d .')
    assert_buf "3\n"
    assert_eq "2\n", vma.registers["a"].text
  end

  def test_repeat_indent_and_case
    setup_text("a\n")
    keys("> > .")
    assert_buf "\t\ta\n"
    setup_text("foo bar\n")
    keys("g U w w .")
    assert_buf "FOO BAR\n"
  end

  def test_nothing_to_repeat
    vma.dot.instance_variable_set(:@last, nil)
    setup_text("abc\n")
    keys(".")
    assert_buf "abc\n"
  end

  # cnf.undo.insert_one_step: a pause while typing doesn't split the undo step
  def test_insert_session_undo_step
    saved = cnf.undo.insert_one_step?
    [[true, "x\n"], [false, "abx\n"]].each { |one_step, after_undo|
      cnf.undo.insert_one_step = one_step
      setup_text("x\n")
      keys("i a b")
      buf.instance_variable_set(:@last_delta_time, Time.now - 60) # a long pause
      keys("c d esc")
      assert_buf "abcdx\n"
      keys("u")
      assert_buf after_undo, "insert_one_step=#{one_step}"
    }
  ensure
    cnf.undo.insert_one_step = saved
  end
end
