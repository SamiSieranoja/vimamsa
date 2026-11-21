# Recording demos (demo_recorder.rb, doc/demo_recording_plan.md part 2):
# keys into steps, and a recorded demo played back (DemoPlayer user demos)
class TestDemoRecorder < VmaTest
  K = DemoRecorder::Key

  def lines(keys, end_line: 0)
    DemoRecorder.steps(keys, end_line: end_line).lines.map(&:chomp).reject { |l| l.start_with?("#") }
  end

  def wait_until(secs = 60)
    t = Time.now
    until yield || Time.now - t > secs
      drain_idle
      sleep 0.005
    end
    yield
  end

  # delay from the typical gap, wait for a pause, type for Insert-mode typing
  def test_steps_from_keys
    ins = "a.edit.insert.char!('%s')"
    keys = [
      K.new(t: 0.0, key: "j", mode: :command, action: "move.line.next"),
      K.new(t: 0.4, key: "j", mode: :command, action: "move.line.next"),
      K.new(t: 3.0, key: "i", mode: :command, action: "mode.insert"),
      K.new(t: 3.4, key: "h", mode: :insert, action: ins % "h"),
      K.new(t: 3.8, key: "i", mode: :insert, action: ins % "i"),
      K.new(t: 4.2, key: "esc", mode: :insert, action: "mode.prev"),
    ]
    assert_eq ["delay 0.4", "wait 1", "keys j j", "wait 2.2", "keys i", "type hi", "keys esc"], lines(keys)
  end

  def test_long_pause_capped
    keys = [K.new(t: 0.0, key: "j", mode: :command, action: "x"), K.new(t: 30.0, key: "k", mode: :command, action: "x")]
    assert lines(keys).include?("wait 3"), lines(keys).inspect
  end

  # Leading spaces of typed text go in a keys line ("type " would lose them)
  def test_typed_leading_space
    keys = [" ", "a"].each_with_index.map { |c, i|
      K.new(t: i * 0.3, key: c == " " ? "space" : c, mode: :insert, action: c == " " ? "edit.insert.space" : "a.edit.insert.char!('a')")
    }
    assert_eq ["keys space", "type a"], lines(keys).last(2)
  end

  # An easy jump's label keys become the target line and @JUMP_LABEL@
  def test_easy_jump_label
    keys = [
      K.new(t: 0.0, key: "s", mode: :command, action: "jump.easy", line: 0),
      K.new(t: 0.4, key: "a", mode: :command, action: nil, line: 0, read: true),
      K.new(t: 0.8, key: "b", mode: :command, action: nil, line: 0, read: true),
      K.new(t: 1.2, key: "d", mode: :command, action: nil, line: 7, col: 12),
      K.new(t: 1.4, key: "d", mode: :command, action: "edit.delete.line", line: 7),
    ]
    l = lines(keys)
    i = l.index("keys s")
    assert i, l.inspect
    # the d of d d has no action, but isn't a label key
    assert_eq ["target line 8 col 13", "keys @JUMP_LABEL@", "keys d d"], l[i + 1, 3]
  end

  # ctrl alone is a key ("ctrl!"), ctrl held for ctrl-r is not
  def test_bare_modifier
    r = DemoRecorder.new
    r.instance_variable_set(:@recording, true)
    r.instance_variable_set(:@t0, 0)
    r.key_input("ctrl", :key_press)
    r.key_input("ctrl!", :key_release)
    r.key_input("ctrl", :key_press)
    r.key_input("ctrl-r", :key_press)
    r.key_input("j", :key_press)
    r.key_input("j!", :key_release)
    assert_eq ["ctrl", "ctrl-r", "j"], r.keys.map(&:key)
  end

  # Record real keys (an edit and , r r with typing in the form), name it in
  # the save form, play it back: the same text
  def test_record_save_and_play_back
    b = create_new_buffer("one two one\nline two\n", "rectest")
    rec = DemoRecorder.new
    DemoRecorder.current = rec
    rec.start
    keys "j d d"
    keys ", r r o n e tab 1 enter"
    want = b.to_s.dup
    assert_eq "1 two 1\n", want
    rec.stop
    assert FormInput.current, "no name form"
    keys "ctrl-a r t enter"
    dir = File.join(DemoPlayer.user_demos_dir, "rt")
    assert File.exist?(File.join(dir, "steps.txt")), "not saved"
    steps = File.read(File.join(dir, "steps.txt"))
    assert steps.include?("type one"), steps
    assert_eq "one two one\nline two\n", File.read(File.join(dir, "demo.txt")), "start file"
    assert_eq :user_rt, DemoRecorder.last_saved
    assert DemoPlayer.demos.key?(:user_rt)
    assert vma.actions.include?("help.demo.user.rt")

    p = DemoPlayer.new(:user_rt, speed: 50, loop: false)
    p.start
    assert wait_until { !p.running? }, "demo still running"
    assert_eq "Demo finished", p.stop_message, steps
    assert_eq want, p.buf.to_s, steps
  ensure
    DemoRecorder.current = nil
    FormInput.current&.cancel
    drain_idle
    p&.bufs&.each { |x| vma.buffers.close_buffer(x.id) }
    FileUtils.rm_rf(DemoPlayer.user_demos_dir)
  end

  # An easy jump to a word inside a line (s + a label), then d w: all keys
  # play back, at the same character (the d, which has no action, used to be
  # taken for a label key)
  def test_record_dd_then_easy_jump
    text = (1..12).map { |i| "line number #{i} with words\n" }.join
    b = create_new_buffer(text, "rectest")
    # easy jump labels only what is shown: wait until the view is laid out
    assert wait_until(10) { (a = get_visible_area) && a[1] - a[0] > 100 }, "view not laid out: #{get_visible_area.inspect}"
    rec = DemoRecorder.new
    DemoRecorder.current = rec
    rec.start
    keys "s"
    ej = EasyJump.class_variable_get(:@@cur)
    # a labelled word inside line 6, not its start
    ls = b.index("line number 6")
    marks = ej.instance_variable_get(:@easy_jump_wsmarks)
    target = marks.select { |m| m > ls && m < b.index("\n", ls) }.min
    assert target, "no labelled word inside line 6: #{marks.sort.inspect}"
    n = marks.index(target)
    label = ej.instance_variable_get(:@jump_sequence)[n].downcase.chars
    keys label.join(" ")
    assert_eq target, b.pos, "jump"
    keys "d w"
    keys "x"
    want = b.to_s.dup
    rec.stop(save: false)
    steps = rec.steps_text(file: "demo.txt")
    assert steps.include?("keys d w"), steps
    col = target - ls + 1
    assert steps.include?("target line 6 col #{col}"), steps
    rec.save("ddjump")
    p = DemoPlayer.new(:user_ddjump, speed: 50, loop: false)
    p.start
    assert wait_until { !p.running? }, "demo still running"
    assert_eq want, p.buf.to_s, steps
  ensure
    vma.kbd.remove_keyhandling_override # easy jump left reading keys
    vma.gui.clear_overlay rescue nil
    vma.kbd.set_mode(:command)
    DemoRecorder.current = nil
    p&.bufs&.each { |x| vma.buffers.close_buffer(x.id) }
    FileUtils.rm_rf(DemoPlayer.user_demos_dir)
  end

  # The stop command's own keys aren't in the demo
  def test_stop_keys_dropped
    rec = DemoRecorder.new
    DemoRecorder.current = rec
    rec.start
    keys "j"
    rec.key_input(",", :key_press)
    rec.key_input("x", :key_press)
    rec.key_action("help.demo.record")
    rec.stop(save: false)
    assert_eq ["j"], rec.keys.map(&:key)
  ensure
    DemoRecorder.current = nil
  end
end
