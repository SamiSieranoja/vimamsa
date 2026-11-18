# Double-clicking a line runs the buffer's line action, like Enter.
class TestDoubleClick < VmaTest
  def dbl_click(pos)
    v = vma.buf.view
    x, y = v.pos_to_coord(pos)
    v.instance_variable_get(:@click).signal_emit("pressed", 2, x + 2, y + 4)
    drain_idle
  end

  # Ack (grep) result buffers set a handler that takes the line number;
  # double-click used to call module.select_line without it and crash.
  def test_calls_line_action_handler_with_line
    b = vma.buf
    b.set_content("first\nsecond\nthird\n")
    drain_idle
    got = nil
    mod = Object.new
    def mod.select_line(lineno) = raise("select_line called without the handler")
    b.module = mod
    b.line_action_handler = proc { |l| got = l }
    dbl_click("first\nsecond\n".size + 1)
    assert_eq 2, got
  ensure
    b.module = nil
    b.line_action_handler = nil
  end

  def test_module_select_line_without_args
    b = vma.buf
    b.set_content("a\nb\n")
    drain_idle
    called = false
    mod = Object.new
    mod.define_singleton_method(:select_line) { called = true }
    b.module = mod
    dbl_click(2)
    assert called, "module.select_line not called"
  ensure
    b.module = nil
  end
end
