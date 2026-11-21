# Help ▸ Play demo: the README demo steps played inside the editor
# (demo_player.rb, scripts/demo/demo_steps.txt)
class TestDemoPlayer < VmaTest
  SHAPES = File.join(DemoPlayer::DIR, "shapes.rb")

  def wait_until_done(player, secs = 60)
    wait_for(secs) { !player.running? }
    assert !player.running?, "demo still running after #{secs} s"
  end

  # Runs the main loop until the block is true or secs pass; the block's value
  def wait_for(secs)
    t = Time.now
    until (ok = yield) || Time.now - t > secs
      drain_idle
      sleep 0.005
    end
    ok
  end

  # Runs the main loop for secs
  def idle_for(secs)
    wait_for(secs) { false }
  end

  # A short demo: after a wait, x deletes the first character of the file;
  # then the closing wait, if any
  def short_player(wait, closing = nil, **opts)
    steps = [["wait", wait.to_s], ["keys", "x"]]
    steps << ["wait", closing.to_s] if closing
    DemoPlayer.new(speed: 1, steps: steps, **opts)
  end

  def original
    File.read(SHAPES)
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
    p = DemoPlayer.new(speed: 50, loop: false)
    p.start
    wait_until_done(p)
    want = File.read(SHAPES) + "puts \"Total: \#{shapes.sum(&:area).round(1)}\"\n"
    assert_eq want, p.buf.to_s
    assert_mode :command
    assert_eq 0, p.buf.pos
  ensure
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end

  # The easy jump demo moves Shape#to_s above area, with v + easy jump to
  # select it, x and P
  def test_easyjump_demo_moves_to_s
    p = DemoPlayer.new(:easyjump, speed: 50, loop: false)
    p.start
    wait_until_done(p)
    l = original.lines
    want = l[0..4] + ["\n"] + l[10..12] + ["\n"] + l[6..8] + l[13..]
    assert_eq want.join, p.buf.to_s
    assert_mode :command
  ensure
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end

  # The file switching demo: tab, browse mode h / l and the file explorer
  # visit every file and end on shapes.rb, unchanged, at the top
  def test_files_demo_switches_files
    p = DemoPlayer.new(:files, speed: 20, loop: false)
    p.start
    seen = []
    t = Time.now
    while p.running? && Time.now - t < 60
      seen << File.basename(vma.buf.fname.to_s)
      drain_idle
      sleep 0.005
    end
    assert !p.running?, "demo still running"
    order = seen.chunk_while { |a, b| a == b }.map(&:first)
    assert_eq "Demo finished", p.stop_message, "#{p.stop_message}; buffers in order: #{order.inspect}, log: #{vma.gui.keylog_panel.entries.last(4).map { |e| e[:chord] || e[:text] }.inspect}"
    # "": the file explorer's buffer
    assert_eq ["", "notes.txt", "report.rb", "shapes.rb"], seen.uniq.sort
    assert_eq "shapes.rb", File.basename(vma.buf.fname.to_s)
    assert_eq File.read(SHAPES), vma.buf.to_s
    assert_eq 0, vma.buf.pos
    assert vma.buffers.list.none? { |b| b.module.is_a?(FileManager) rescue false }, "file explorer still open"
  ensure
    p&.bufs&.each { |b| vma.buffers.close_buffer(b.id) }
  end

  def test_easyjump_steps_parse
    steps = DemoPlayer.parse(File.read(DemoPlayer::DEMOS[:easyjump][:steps]))
    assert steps.count { |c, a| c == "keys" && a.include?("@JUMP_LABEL@") } >= 5
  end

  # Another demo from the menu stops the playing one and starts; the same
  # one again stops it
  def test_toggle_switches_demo
    DemoPlayer.toggle(:basic)
    a = DemoPlayer.current
    DemoPlayer.toggle(:easyjump)
    b = DemoPlayer.current
    assert !a.running?
    assert b.running?
    assert_eq :easyjump, b.name
    DemoPlayer.toggle(:easyjump)
    assert !b.running?
    drain_idle
  ensure
    [a, b].compact.each { |x| x.stop; vma.buffers.close_buffer(x.buf.id) if x.buf }
  end

  # The key log's close button stops the demo and hides the panel
  def test_close_button_stops_demo
    p = short_player(5)
    p.start
    panel = vma.gui.keylog_panel
    assert panel.active?, "key log not shown by the demo"
    panel.close_btn.signal_emit("clicked")
    drain_idle
    assert !p.running?, "demo still running"
    assert !panel.active?, "key log still shown"
  ensure
    p&.stop
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

  # At the end the file goes back to how it was and the demo plays again
  def test_loops_until_stopped
    p = short_player(0.3, 0.3)
    p.start
    assert wait_for(5) { p.buf.to_s == original[1..] }, "the first round didn't delete a char"
    assert wait_for(5) { p.rounds >= 1 }, "no second round"
    assert p.running?
    assert_eq original, p.buf.to_s
    assert wait_for(5) { p.buf.to_s == original[1..] }, "the second round didn't play"
    p.stop
    assert !p.running?
  ensure
    p&.stop
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end

  # The key log starts empty, without the keys typed before the demo
  def test_key_log_cleared_at_start
    act "panel.keylog.toggle"
    keys "j k"
    assert vma.gui.keylog_panel.entries.size > 0
    p = short_player(5, loop: false)
    p.start
    assert_eq [], vma.gui.keylog_panel.entries
  ensure
    p&.stop
    vma.buffers.close_buffer(p.buf.id) if p&.buf
    act "panel.keylog.toggle" if vma.gui.keylog_panel.active?
  end

  # Paused, the step waits; continued, it runs. The button label follows.
  def test_pause_and_continue
    p = short_player(0.2, loop: false)
    panel = vma.gui.keylog_panel
    p.start
    assert panel.demo_bar.visible?
    assert_eq "Pause", panel.demo_pause_btn.label
    p.toggle_pause
    assert p.paused?
    assert_eq "Continue", panel.demo_pause_btn.label
    idle_for(0.6)
    assert_eq original, p.buf.to_s, "a paused demo went on"
    p.toggle_pause
    assert !p.paused?
    assert_eq "Pause", panel.demo_pause_btn.label
    wait_until_done(p, 5)
    assert_eq original[1..], p.buf.to_s
    assert !panel.demo_bar.visible?, "demo controls still shown after the end"
  ensure
    p&.stop
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end

  def test_speed_steps
    p = DemoPlayer.new
    r = p.rate
    assert DemoPlayer::RATES.include?(r), "default rate #{r} not in RATES"
    p.faster
    assert_eq DemoPlayer::RATES[DemoPlayer::RATES.index(r) + 1], p.rate
    8.times { p.faster }
    assert_eq DemoPlayer::RATES.last, p.rate
    20.times { p.slower }
    assert_eq DemoPlayer::RATES.first, p.rate
    assert_eq "0.25×", DemoPlayer.rate_label(0.25)
    assert_eq "2×", DemoPlayer.rate_label(2)
  end

  # Speed divides the waits: a 2 s wait at 4× takes 0.5 s, a 0.2 s wait at
  # 0.25× takes 0.8 s (the bounds are loose for slow machines)
  def test_speed_changes_waits
    p = short_player(2, loop: false)
    p.set_rate(4)
    p.start
    assert_eq "4×", vma.gui.keylog_panel.demo_speed_lbl.label
    assert wait_for(1.5) { !p.running? }, "a 2 s wait at 4× took over 1.5 s"
    vma.buffers.close_buffer(p.buf.id)

    p = short_player(0.2, loop: false)
    p.set_rate(0.25)
    p.start
    idle_for(0.4)
    assert p.running?, "a 0.2 s wait at 0.25× took under 0.4 s"
    wait_until_done(p, 5)
  ensure
    p&.stop
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end

  def test_toggle_stops
    DemoPlayer.toggle
    p = DemoPlayer.current
    assert p.running?
    assert vma.gui.keylog_panel.demo_bar.visible?
    DemoPlayer.toggle
    assert !p.running?
    assert !vma.gui.keylog_panel.demo_bar.visible?
    drain_idle
  ensure
    vma.buffers.close_buffer(p.buf.id) if p&.buf
  end
end
