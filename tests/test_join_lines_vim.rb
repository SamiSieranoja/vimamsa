# J in command mode compared with Vim's J. The expected results were taken
# from Vim 9 itself (vim -u NONE -N -Es, 'nojoinspaces' does not matter here:
# no line ends in . ! or ?):
#   - the next line's leading whitespace is removed
#   - one space goes between the lines, except when the next line is empty
#     (or only whitespace), the current line is empty or ends in whitespace,
#     or the next line starts with ")"
#   - the cursor goes to the join point: the inserted space, or (no space)
#     the last character of the current line / the first character joined
#   - J on the last line does nothing
#
# Each case: [text, keys, expected text, [line, col]] (line and col 0-based,
# as lpos / cpos). Vimamsa buffers always end in "\n".
class TestJoinLinesVim < VmaTest
  CASES = [
    # Repeated J over empty lines: the empty lines vanish without spaces
    ["a\n\n\nb\n",       "J",       "a\n\nb\n",   [0, 0]],
    ["a\n\n\nb\n",       "J J",     "a\nb\n",     [0, 0]],
    ["a\n\n\nb\n",       "J J J",   "a b\n",      [0, 1]],
    ["abc\n\n\ndef\n",   "J",       "abc\n\ndef\n", [0, 2]],
    ["abc\n\n\ndef\n",   "J J",     "abc\ndef\n", [0, 2]],
    ["abc\n\n\ndef\n",   "J J J",   "abc def\n",  [0, 3]],
    ["abc\n\n\ndef\n",   "J J J J", "abc def\n",  [0, 3]], # last line: no-op
    ["a\n\n\n",          "J J J",   "a\n",        [0, 0]],
    # Starting on an empty line
    ["\n\nb\nc\n",       "J",       "\nb\nc\n",   [0, 0]],
    ["\n\nb\nc\n",       "J J",     "b\nc\n",     [0, 0]],
    ["\n\nb\nc\n",       "J J J",   "b c\n",      [0, 1]],
    # A whitespace-only line counts as empty; indentation is removed
    ["a\n    \nb\n",     "J",       "a\nb\n",     [0, 0]],
    ["a\n    \nb\n",     "J J",     "a b\n",      [0, 1]],
    ["x\nabc\n\n  def\n", "j J J",  "x\nabc def\n", [1, 3]],
    # The single-join rules
    ["a\n   b\n",        "J",       "a b\n",      [0, 1]],
    ["a \nb\n",          "J",       "a b\n",      [0, 2]],
    ["a\n)b\n",          "J",       "a)b\n",      [0, 1]],
    ["one\ntwo\nthree\n", "J J",    "one two three\n", [0, 7]],
    ["last\n",           "J",       "last\n",     [0, 0]],
  ]

  CASES.each_with_index { |(text, ks, want, (l, c)), i|
    define_method("test_vim_J_#{i}") {
      vma.buf.set_content(text)
      vma.buf.set_pos(0)
      keys ks
      assert_buf want, "#{text.inspect} + #{ks}:\n  expected: #{want.inspect}\n  actual:   #{vma.buf.to_s.inspect}"
      assert_pos l, c, "#{text.inspect} + #{ks}: cursor expected at line #{l} col #{c}, " \
                       "got line #{vma.buf.lpos} col #{vma.buf.cpos}"
      assert_mode :command
    }
  }

  # One J is one undo step; . repeats it
  def test_undo_and_repeat
    vma.buf.set_content("abc\n   def\nghi\n")
    vma.buf.set_pos(0)
    keys "J"
    assert_buf "abc def\nghi\n"
    keys "u"
    assert_buf "abc\n   def\nghi\n"
    keys "J ."
    assert_buf "abc def ghi\n"
  end
end
