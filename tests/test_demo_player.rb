# Help ▸ Play demo: the README demo steps played inside the editor
# (demo_player.rb, scripts/demo/demo_steps.txt)
class TestDemoPlayer < VmaTest
  SHAPES = File.join(DemoPlayer::DIR, "shapes.rb")

  def wait_until_done(player, secs = 60)
    t = Time.now
    while player.running? && Time.now - t < secs
      drain_idle
      sleep 0.005
    end
    assert !player.running?, "demo still running after #{secs} s"
  end

  def test_steps_parse
    steps = DemoPlayer.parse(File.read(DemoPlayer::STEPS))
    assert steps.any? { |c, a| c == "keys" && a.include?("@JUMP_LABEL@") }
    assert steps.any? { |c, _| c == "target" }, "no target line for the easy jump"
    assert steps.any? { |c, a| c == "type" && a.start_with?("puts ") }
  end

  # The whole demo, fast: the file ends up with the typed line below the
  # last one (G k o), nothing else changed (the yank/paste/delete/undo/redo
  # cancel out), in Command mode at the top
  def test_plays_whole_demo
    p = DemoPlayer.new(speed: 50)
    p.start
    wait_until_done(p)
    want = File.read(SHAPES) + "puts \"Total: \#{shapes.sum(&:area).round(1)}\"\n"
    assert_eq want, p.buf.to_s
    assert_mode :command
    assert_eq 0, p.buf.pos
  ensure
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end

  # The easy jump label is looked up for the target line in this window (a
  # line near the top: the test window may not show line 16 the demo uses)
  def test_jump_label_reaches_target
    p = DemoPlayer.new
    b = create_new_buffer(File.read(SHAPES), "demotest", true)
    p.instance_variable_set(:@buf, b)
    p.instance_variable_set(:@target, "  def area")
    b.set_pos(0)
    # Let the new view get laid out: easy jump labels only what's visible
    20.times { drain_idle; sleep 0.02 }
    keys("s")
    ej = EasyJump.class_variable_get(:@@cur)
    label = p.send(:jump_label)
    marks = ej.instance_variable_get(:@easy_jump_wsmarks)
    assert label != ["esc"], "no label: target line start #{b.index("  def area")}, marks #{marks.first(30).inspect}, visible #{get_visible_area.inspect}, cur buf #{vma.buf.equal?(b)}"
    label.each { |c| p.send(:press, c) }
    assert_eq b.index("  def area"), b.pos
  ensure
    vma.buffers.close_buffer(b.id) if b
  end

  def test_toggle_stops
    DemoPlayer.toggle
    p = DemoPlayer.current
    assert p.running?
    DemoPlayer.toggle
    assert !p.running?
    drain_idle
  ensure
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end
end
