require "tempfile"

# Regression tests for jump_to_file / open_new_file.
#
# Bug: when the target file was not already open, open_new_file returned the
# buffer *id* (an Integer) instead of the Buffer object, so jump_to_file crashed
# with "undefined method `jump_to_line' for an instance of Integer". This is the
# path hit when jumping to source from a whole-repo git diff (diffview enter).
class TestJumpToFile < VmaTest

  def make_temp_file(contents)
    f = Tempfile.new(["jump_target", ".txt"])
    f.write(contents)
    f.flush
    f
  end

  # open_new_file must hand back a Buffer for a file that isn't open yet.
  def test_open_new_file_returns_buffer_when_not_open
    f = make_temp_file("line1\nline2\nline3\n")
    path = File.expand_path(f.path)
    b = open_new_file(path)
    assert b.is_a?(Buffer), "open_new_file must return a Buffer, got #{b.class}: #{b.inspect}"
    assert_eq path, b.fname
  ensure
    f.close
    f.unlink
  end

  # The end-to-end path that was crashing: jump to a line in a not-yet-open file.
  def test_jump_to_file_positions_cursor
    f = make_temp_file("line1\nline2\nline3\nline4\nline5\n")
    path = File.expand_path(f.path)
    jump_to_file(path, 3)               # 1-based line 3
    assert_eq path, vma.buf.fname
    assert_eq 2, vma.buf.lpos           # -> 0-based line 2
  ensure
    f.close
    f.unlink
  end
end
