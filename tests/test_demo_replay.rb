# The built-in demos (DemoPlayer::DEMOS) as an extra regression test, not in
# the default set (exe/run_tests.rb excludes it):
#   ruby exe/run_tests.rb demo_replay
#   ./run_tests_vm.rb demo_replay
#
# Each demo is played to the end. After every key step (demo_player.rb
# on_step) the test records the buffer, the mode, the cursor and what the
# step changed in the text (a line diff against that buffer's text before
# it), and compares that with the record of an earlier run in
# tests/demo_records/<demo>.txt. A step that changes something else than it
# did before shows as the first record line that differs; the whole new
# record is left in tests/demo_records/<demo>.actual.txt.
#
# To make or update the records (after a change that is meant to change what
# a demo does, or an edit of its steps file):
#   VMA_UPDATE_DOC=1 ruby exe/run_tests.rb demo_replay
#   VMA_UPDATE_DOC=1 ./run_tests_vm.rb demo_replay   # copies them back
class TestDemoReplay < VmaTest
  RECORD_DIR = File.expand_path("demo_records", __dir__)
  SHAPES = File.join(DemoPlayer::DIR, "shapes.rb")
  # Playing speed of each demo (not faster for basic: at 50x an easy jump can
  # come before the view has scrolled to its target, which then has no label)
  SPEEDS = { basic: 3, easyjump: 50, files: 20 }

  def self.record_path(name, actual: false)
    File.join(RECORD_DIR, "#{name}#{actual ? ".actual" : ""}.txt")
  end

  # Runs the main loop until the player stops (at most secs)
  def wait_until_done(player, secs)
    t = Time.now
    while player.running? && Time.now - t < secs
      drain_idle
      sleep 0.005
    end
    assert !player.running?, "demo still running after #{secs} s"
  end

  # ── Recording ────────────────────────────────────────────────────────────

  # The file explorer's text lists a directory; only its cursor line is
  # recorded
  def explorer?(b)
    b.respond_to?(:module) && b.module.is_a?(FileManager)
  end

  def buf_name(b)
    return "(file explorer)" if explorer?(b)
    b.fname ? File.basename(b.fname) : "(#{b.class})"
  end

  # "-" and "+" lines for what changed between texts a and b (the lines
  # between their common start and end), each with its 1-based line number
  def self.line_diff(a, b)
    return [] if a == b
    al, bl = a.lines, b.lines
    pre = 0
    pre += 1 while pre < al.size && pre < bl.size && al[pre] == bl[pre]
    suf = 0
    suf += 1 while suf < al.size - pre && suf < bl.size - pre && al[-1 - suf] == bl[-1 - suf]
    out = al[pre...(al.size - suf)].each_with_index.map { |l, i| "  @#{pre + i + 1} -#{show(l)}" }
    out + bl[pre...(bl.size - suf)].each_with_index.map { |l, i| "  @#{pre + i + 1} +#{show(l)}" }
  end

  # A line as one record line: tabs and other control chars escaped
  def self.show(line)
    line.chomp.gsub(/[\x00-\x1f\x7f]/) { |c| c == "\t" ? "\\t" : format("\\x%02x", c.ord) }
  end

  # Plays demo name to the end; [player, record lines]. @seen: the buffer
  # of each step.
  def play_and_record(name)
    texts = {} # buffer => its text after the last step
    lines = []
    @seen = []
    n = 0
    on_step = proc { |label|
      n += 1
      b = vma.buf
      @seen << buf_name(b)
      line = "##{n} #{label} | #{buf_name(b)} #{vma.kbd.get_mode} #{b.lpos + 1}:#{b.cpos + 1}"
      if explorer?(b)
        lines << "#{line} > #{b.current_line.chomp.strip}"
      else
        lines << line
        lines.concat(TestDemoReplay.line_diff(texts[b.object_id] || "", b.to_s))
        texts[b.object_id] = b.to_s.dup
      end
    }
    p = DemoPlayer.new(name, speed: SPEEDS.fetch(name), loop: false, on_step: on_step)
    p.start
    # the demo's files as it opened them (its first step runs from a timer)
    p.bufs.each { |b| texts[b.object_id] = b.to_s.dup }
    wait_until_done(p, 300)
    assert_eq "Demo finished", p.stop_message
    [p, lines]
  end

  # Compares the record with tests/demo_records/<name>.txt (writes it with
  # VMA_UPDATE_DOC=1)
  def check_record(name, lines)
    want_path = TestDemoReplay.record_path(name)
    actual_path = TestDemoReplay.record_path(name, actual: true)
    header = ["# Demo record: #{name} (#{File.basename(DemoPlayer::DEMOS[name][:steps])}); see tests/test_demo_replay.rb",
              "# step | buffer mode line:col, then the lines the step changed (@line -old +new)"]
    text = (header + lines).join("\n") + "\n"
    if ENV["VMA_UPDATE_DOC"] == "1"
      FileUtils.mkdir_p(RECORD_DIR)
      File.write(want_path, text)
      File.delete(actual_path) if File.exist?(actual_path)
      return
    end
    skip "#{want_path} missing (make it with VMA_UPDATE_DOC=1)" if !File.exist?(want_path)
    want = File.read(want_path).lines(chomp: true).reject { |l| l.start_with?("# ") }
    if want == lines
      File.delete(actual_path) if File.exist?(actual_path)
      return
    end
    File.write(actual_path, text)
    i = (0...[want.size, lines.size].max).find { |k| want[k] != lines[k] }
    # the step line the first difference belongs to
    step = (0..i).to_a.reverse.map { |k| want[k] }.find { |l| l&.start_with?("#") }
    assert false, "#{name} demo differs from its record at line #{i + 3} (in step #{step.inspect}):\n" \
                  "  expected: #{want[i].inspect}\n  got:      #{lines[i].inspect}\n" \
                  "  the new record: #{actual_path}"
  end

  def close_demo(p)
    (p&.bufs || []).each { |b| vma.buffers.close_buffer(b.id) if vma.buffers.list.any? { |x| x.equal?(b) } }
    drain_idle
  end

  # ── The demos ────────────────────────────────────────────────────────────

  def test_line_diff
    assert_eq [], TestDemoReplay.line_diff("a\nb\n", "a\nb\n")
    assert_eq ["  @2 -b", "  @2 +x"], TestDemoReplay.line_diff("a\nb\nc\n", "a\nx\nc\n")
    assert_eq ["  @2 +n"], TestDemoReplay.line_diff("a\nb\n", "a\nn\nb\n")
    assert_eq ["  @1 -a\\tb"], TestDemoReplay.line_diff("a\tb\nc\n", "c\n")
  end

  # The basic demo turns Circle into a Square class with a width (search and
  # replace in a form, the action search, easy jumps), back in Command mode
  def test_basic_demo
    # its action searches find the same action whatever else is registered
    assert_eq "sel.convert.remove_empty_lines", vma.actions.search_actions_update_callback("sel.convert.remempty")[0][1]
    assert_eq "sel.convert.eval", vma.actions.search_actions_update_callback("sel.convert.eval")[0][1]
    p, lines = play_and_record(:basic)
    t = p.buf.to_s
    assert t.include?("class Square < Shape"), t
    assert t.include?("@width**2"), t
    # the action search ran the eval converter on the whole file
    assert t.include?("[3.141592653589793, 1]"), t
    assert_mode :command
    check_record(:basic, lines)
  ensure
    close_demo(p)
  end

  # The easy jump demo moves Shape#to_s above area, with v + easy jump to
  # select it, x and P
  def test_easyjump_demo
    p, lines = play_and_record(:easyjump)
    l = File.read(SHAPES).lines
    want = l[0..4] + ["\n"] + l[10..12] + ["\n"] + l[6..8] + l[13..]
    assert_eq want.join, p.buf.to_s
    assert_mode :command
    check_record(:easyjump, lines)
  ensure
    close_demo(p)
  end

  # The file switching demo: tab, browse mode h / l and the file explorer
  # visit every file and end on shapes.rb, unchanged, at the top
  def test_files_demo
    p, lines = play_and_record(:files)
    seen = @seen
    %w[notes.txt report.rb shapes.rb].each { |f| assert seen.include?(f), "#{f} not visited: #{seen.uniq.inspect}" }
    assert seen.include?("(file explorer)"), "file explorer not used"
    assert_eq "shapes.rb", File.basename(vma.buf.fname.to_s)
    assert_eq File.read(SHAPES), vma.buf.to_s
    assert_eq 0, vma.buf.pos
    assert vma.buffers.list.none? { |b| explorer?(b) rescue false }, "file explorer still open"
    check_record(:files, lines)
  ensure
    close_demo(p)
  end
end
