# Dragging selected text with the mouse moves it (cnf.mouse.drag_selection).
# The gestures are driven by emitting the controllers' signals directly.
class TestDragSelection < VmaTest
  TEXT = "alpha beta gamma\nsecond line\n"

  def setup_sel(from, len)
    b = vma.buf
    b.set_content(TEXT)
    drain_idle
    b.set_pos(from)
    keys("v")
    b.set_pos(from + len - 1)
    drain_idle
    b
  end

  # Widget coords of the middle of the char at offset
  def xy(pos)
    v = vma.buf.view
    x, y = v.pos_to_coord(pos)
    [x + 2, y + 4]
  end

  # Press at offset from, release at offset to (or at from, a plain click)
  def drag(from, to)
    v = vma.buf.view
    x, y = xy(from)
    tx, ty = xy(to)
    v.instance_variable_get(:@click).signal_emit("pressed", 1, x, y)
    d = v.instance_variable_get(:@cnt_drag)
    d.signal_emit("drag-begin", x, y)
    if [x, y] != [tx, ty]
      d.signal_emit("drag-update", tx - x, ty - y)
      @marker_during_drag = v.drop_marker_pos
      @marker_widget = v.instance_variable_get(:@drop_marker)
    end
    v.instance_variable_get(:@click).signal_emit("released", 1, tx, ty) if [x, y] == [tx, ty]
    d.signal_emit("drag-end", tx - x, ty - y)
    drain_idle
  end

  def with_setting(val)
    old = cnf.mouse.drag_selection?
    cnf.mouse.drag_selection = val
    yield
  ensure
    cnf.mouse.drag_selection = old
  end

  def test_move_text_forward_and_back
    b = vma.buf
    b.set_content("abc def ghi\n")
    assert_eq 4..6, b.move_text(0..2, 7)       # "abc" before " ghi"
    assert_buf " defabc ghi\n"
    assert_eq 0..2, b.move_text(4..6, 0)
    assert_buf "abc def ghi\n"
    assert_eq nil, b.move_text(0..2, 3)        # right after itself: no-op
    assert_eq nil, b.move_text(0..2, 1)        # inside itself
    assert_buf "abc def ghi\n"
  end

  def test_move_text_is_one_undo_step
    b = vma.buf
    b.set_content("abc def ghi\n")
    b.move_text(0..2, 8)
    assert_buf " def abcghi\n"
    b.undo
    assert_buf "abc def ghi\n"
  end

  def test_drag_moves_selection
    with_setting(true) do
      b = setup_sel(TEXT.index("beta"), 5) # "beta "
      assert_mode :visual
      drag(TEXT.index("beta") + 1, TEXT.index("line"))
      assert_eq TEXT.index("line"), @marker_during_drag, "drop marker not at drop point"
      assert !@marker_widget.visible?, "drop marker still shown after the drop"
      assert_buf "alpha gamma\nsecond beta line\n"
      assert !b.visual_mode?, "selection still active after the drop"
      assert_mode :command
      assert_eq "alpha gamma\nsecond ".size, b.pos # at the moved text's start
    end
  end

  # Right half of a char drops after it; past the end of a line drops before "\n"
  def test_drop_pos_snaps_to_nearest_boundary
    b = vma.buf
    b.set_content(TEXT)
    drain_idle
    v = b.view
    x, y = v.pos_to_coord(1)
    w = v.get_iter_location(v.buffer.get_iter_at(:offset => 1)).width
    assert_eq 1, v.drop_pos(x + 1, y + 4)
    assert_eq 2, v.drop_pos(x + w - 1, y + 4)
    assert_eq TEXT.index("\n"), v.drop_pos(x + 500, y + 4)
  end

  def test_no_marker_when_drop_would_not_move
    with_setting(true) do
      b = setup_sel(TEXT.index("beta"), 5)
      drag(TEXT.index("beta") + 1, TEXT.index("beta") + 3)
      assert_eq nil, @marker_during_drag
      assert_buf TEXT
      assert !b.visual_mode?, "selection still active after the drop"
    end
  end

  def test_click_inside_selection_clears_it
    with_setting(true) do
      b = setup_sel(TEXT.index("beta"), 5)
      drag(TEXT.index("beta") + 2, TEXT.index("beta") + 2)
      assert_buf TEXT
      assert !b.visual_mode?, "selection still active"
      assert_pos 0, TEXT.index("beta") + 2
    end
  end

  def test_disabled_drag_starts_new_selection
    with_setting(false) do
      b = setup_sel(TEXT.index("beta"), 5)
      drag(TEXT.index("beta") + 1, TEXT.index("line"))
      assert_buf TEXT
    end
  end
end
