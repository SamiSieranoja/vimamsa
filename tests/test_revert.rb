require "tempfile"

# Reloading a file that was changed by an external program (buf.revert) must
# keep the cursor, the view and the edit positions on the same text.
class TestRevert < VmaTest

  def open_temp(contents)
    @tmp = Tempfile.new(["revert_test", ".txt"])
    @tmp.write(contents)
    @tmp.flush
    open_new_file(File.expand_path(@tmp.path))
    drain_idle
  end

  def write_external(contents)
    File.write(@tmp.path, contents)
  end

  def revert
    act "buf.revert"
    drain_idle
  end

  def teardown_tmp
    return if @tmp.nil?
    @tmp.close
    @tmp.unlink
    @tmp = nil
  end

  def edit_pos_history
    vma.buf.instance_variable_get(:@edit_pos_history)
  end

  def test_cursor_follows_lines_inserted_above
    open_temp("aaa\nbbb\nccc\n")
    act "buf.set_line_and_column_pos(2, 1)"
    write_external("new1\nnew2\naaa\nbbb\nccc\n")
    revert
    assert_buf "new1\nnew2\naaa\nbbb\nccc\n"
    assert_pos(4, 1)
  ensure
    teardown_tmp
  end

  def test_cursor_follows_edit_on_same_line
    open_temp("foo bar baz\n")
    act "buf.set_pos(8)" # on "baz"
    write_external("foo XXXXX bar baz\n")
    revert
    assert_pos(0, 14)
    assert_eq "baz", vma.buf.to_s[vma.buf.pos, 3]
  ensure
    teardown_tmp
  end

  def test_cursor_on_deleted_line
    open_temp("aaa\nbbb\nccc\n")
    act "buf.set_line_and_column_pos(1, 2)"
    write_external("aaa\nccc\n")
    revert
    assert_buf "aaa\nccc\n"
    assert_pos(1, 0)
  ensure
    teardown_tmp
  end

  def test_edit_positions_kept_and_shifted
    open_temp("aaa\nbbb\nccc\n")
    act "buf.set_line_and_column_pos(2, 0)"
    keys("i x esc")
    act "buf.save"
    drain_idle
    hist = edit_pos_history.dup
    assert_eq [8], hist
    write_external("top\n" + File.read(@tmp.path) + "end\n")
    revert
    # Shifted by the inserted line, and the external edits are not recorded
    assert_eq [12], edit_pos_history
    assert !vma.buf.unsaved_changes?, "buffer should match disk after reload"
  ensure
    teardown_tmp
  end

  def test_reload_is_one_undo_step
    open_temp("aaa\nbbb\n")
    write_external("x\naaa\ny\nbbb\nz\n")
    revert
    assert_buf "x\naaa\ny\nbbb\nz\n"
    act "buf.undo"
    assert_buf "aaa\nbbb\n"
  ensure
    teardown_tmp
  end

  def test_view_top_line_kept
    lines = (0...300).map { |i| "line #{i}\n" }
    open_temp(lines.join)
    view = vma.buf.view
    act "buf.set_line_and_column_pos(103, 0)"
    view.scroll_to_top_pos(vma.buf.to_s.index("line 100\n"))
    drain_idle
    top = view.top_visible_pos
    skip("view has no layout (headless?)") if top.nil? || vma.buf.to_s[top, 9] != "line 100\n"
    nvis = view.visible_line_count
    skip("window too small to show the cursor below the top line") if nvis.nil? || nvis < 10
    write_external((0...10).map { |i| "added #{i}\n" }.join + lines.join)
    revert
    top = view.top_visible_pos
    assert_eq "line 100\n", vma.buf.to_s[top, 9]
    assert_pos(113, 0)
  ensure
    teardown_tmp
  end

  # Folded buffers can't be diffed against disk; the cursor is kept by line.
  def test_folded_buffer_keeps_line
    open_temp("a\nb\nc\n{{{\nx\n}}}\n")
    act "buf.set_line_and_column_pos(2, 0)"
    write_external("a\nb\nc\n{{{\nx\ny\n}}}\nd\n")
    revert
    assert_eq "a\nb\nc\n{{{\nx\ny\n}}}\nd\n", vma.buf.content_for_disk
    assert_pos(2, 0)
  ensure
    teardown_tmp
  end
end
