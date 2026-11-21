module Vimamsa
# Plays a demo inside the running editor (Help ▸ Demos), on a fresh copy of
# scripts/demo/shapes.rb, with the key log panel showing each key and the
# action it ran. The demos (DEMOS) are step files in scripts/demo:
#   basic     demo_steps.txt, the README demo that scripts/demo/record_demo.rb
#             records into img/demo.gif
#   easyjump  demo_easyjump_steps.txt: moving and selecting with easy jump
#
# The keys go to the key bindings as if typed. At the end the file goes
# back to how it was and the demo starts again, until it is stopped: the
# same menu item again, the key log's ✕, or switching to another buffer.
# The buttons above the key log (and the help.demo.* actions) pause and
# continue it and change its speed. When it stops, the key log panel is
# hidden again if it wasn't shown before.
class DemoPlayer
  DIR = File.expand_path("../../scripts/demo", __dir__)
  STEPS = File.join(DIR, "demo_steps.txt")
  DEMOS = {
    basic: STEPS,
    easyjump: File.join(DIR, "demo_easyjump_steps.txt"),
  }
  SPEED = 0.7 # as the recording: every delay and wait is divided by this
  RATES = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4] # user speeds, times SPEED

  # Plays demo name; if it is the one playing, stops it instead (another
  # one playing is stopped first)
  def self.toggle(name = :basic)
    if @current&.running?
      same = @current.name == name
      @current.stop("Demo stopped")
      return if same
    end
    @current = new(name)
    @current.start
  end

  # The player started last
  def self.current
    @current
  end

  def self.current=(player)
    @current = player
  end

  # The player that is playing (or paused), else nil with a message
  def self.playing
    return @current if @current&.running?
    message("No demo is playing (Help ▸ Play demo)")
    nil
  end

  def self.pause_toggle = playing&.toggle_pause
  def self.faster = playing&.faster
  def self.slower = playing&.slower
  def self.stop = playing&.stop("Demo stopped")

  attr_reader :buf, :rate, :rounds, :name

  # speed: every delay and wait is divided by it (tests play it fast).
  # loop: start again at the end. steps: [command, argument] pairs instead
  # of demo_steps.txt (tests).
  def initialize(name = :basic, speed: SPEED, loop: true, steps: nil)
    @name = name
    @steps_file = DEMOS.fetch(name)
    @speed = speed
    @loop = loop
    @given_steps = steps
    @rate = 0.75
    @rounds = 0 # finished rounds
  end

  def running?
    @running
  end

  def paused?
    @paused
  end

  # Pause between two steps; a paused demo keeps its place
  def pause
    return if !@running || @paused
    @paused = true
    remove_timer
    show_controls
    message("Demo paused")
  end

  # Continue from where it was paused
  def resume
    return if !@running || !@paused
    @paused = false
    show_controls
    message("Demo continues")
    run_next
  end

  def toggle_pause
    @paused ? resume : pause
  end

  # Speed, as a multiple of the normal one (one of RATES); applies from the
  # next step
  def set_rate(r)
    @rate = r
    show_controls if @running
    message("Demo speed #{DemoPlayer.rate_label(r)}")
  end

  def faster
    set_rate(RATES.find { |r| r > @rate } || RATES.last)
  end

  def slower
    set_rate(RATES.reverse.find { |r| r < @rate } || RATES.first)
  end

  def self.rate_label(r)
    "#{r.to_s.sub(/\.0\z/, "")}×"
  end

  # The steps of demo_steps.txt as [command, argument] pairs (see its header)
  def self.parse(text)
    text.lines(chomp: true).filter_map { |line|
      line = line.sub(/\s+#\s.*\z/, "") unless line.start_with?("type ")
      next if line.strip.empty? || line.start_with?("#")
      cmd, arg = line.split(" ", 2)
      raise "demo_steps.txt: unknown command #{line.inspect}" if !%w[keys type wait delay target].include?(cmd)
      [cmd, arg.to_s]
    }
  end

  def start
    if !@given_steps && !File.exist?(@steps_file)
      message("Demo steps not found: #{@steps_file}")
      return
    end
    @steps = @given_steps || DemoPlayer.parse(File.read(@steps_file))
    # A fresh copy, so the demo can edit it
    dir = File.join(Dir.tmpdir, "vimamsa-demo")
    FileUtils.mkdir_p(dir)
    file = File.join(dir, "shapes.rb")
    FileUtils.cp(File.join(DIR, "shapes.rb"), file)
    old = vma.buffers.list.find { |b| b.fname == file }
    vma.buffers.close_buffer(old.id) if old
    @buf = open_new_file(file)
    @original = File.read(file)
    @keylog_was_shown = vma.gui.instance_variable_get(:@keylog_shown)
    vma.gui.show_keylog_panel
    DemoPlayer.current.stop if DemoPlayer.current&.running? && !DemoPlayer.current.equal?(self)
    DemoPlayer.current = self
    @running = true
    @paused = false
    show_controls
    message("Playing the demo. Pause and speed: the buttons above the key log; ✕ stops it.")
    begin_round
  end

  def stop(msg = nil)
    return if !@running
    @running = false
    @paused = false
    remove_timer
    vma.kbd.set_mode(:command) if vma.buf.equal?(@buf)
    vma.gui.keylog_panel.hide_demo_controls
    # The key log panel goes away again if the demo opened it
    vma.gui.hide_keylog_panel if !@keylog_was_shown
    message(msg) if msg
  end

  private

  # Each round starts with an empty key log
  def begin_round
    vma.gui.keylog_panel.clear
    vma.kbd.set_mode(:command)
    @queue = [] # [delay in s, proc]
    @delay = 0.4
    @target = nil
    @steps.each { |cmd, arg| plan(cmd, arg) }
    run_next
  end

  # The file as it was at the start, and the cursor at the top, for the
  # next round
  def restart
    @rounds += 1
    vma.kbd.set_mode(:command)
    @buf.revert_by_diff(@original.dup)
    @buf.set_pos(0)
    @buf.view&.handle_deltas
    begin_round
  end

  def remove_timer
    GLib::Source.remove(@timer) rescue nil if @timer
    @timer = nil
  end

  def show_controls
    vma.gui.keylog_panel.show_demo_controls(paused: @paused, rate: DemoPlayer.rate_label(@rate))
  end

  def plan(cmd, arg)
    case cmd
    when "wait" then @queue << [arg.to_f, nil]
    when "delay" then @delay = arg.to_f
    when "target" then @queue << [0, proc { @target = arg }]
    when "keys"
      arg.split.each { |k|
        if k == "@JUMP_LABEL@"
          # The label easy jump gave the target line: known only once the
          # labels are drawn, for this window size
          @queue << [@delay, proc { jump_label.each { |c| press(c) } }]
        else
          @queue << [@delay, proc { press(k) }]
        end
      }
    when "type"
      arg.each_char { |c| @queue << [@delay, proc { press(c == " " ? "space" : c) }] }
    end
  end

  # Waits for the next step and runs it. The step leaves the queue only when
  # it runs, so a pause in between plays it, with its whole delay, on resume.
  def run_next
    return if !@running || @paused
    if !vma.buf.equal?(@buf)
      stop("Demo stopped (another buffer was opened)")
      return
    end
    if @queue.empty?
      @loop ? restart : stop("Demo finished")
      return
    end
    delay = @queue.first[0]
    @timer = GLib::Timeout.add([(delay / (@speed * @rate) * 1000).round, 1].max) {
      @timer = nil
      if @running && !@paused
        _delay, action = @queue.shift
        begin
          action&.call
        rescue => e
          stop("Demo stopped: #{e.message}")
        end
        run_next
      end
      false
    }
  end

  # One key, as the GUI passes it to the key bindings: "ctrl" alone is a
  # press and a release (vimlike's ctrl! leaves Insert mode)
  def press(key)
    vma.kbd.match_key_conf(key, nil, :key_press)
    vma.kbd.match_key_conf("#{key}!", nil, :key_release) if %w[ctrl alt shift].include?(key)
    v = vma.buf.view
    v.handle_deltas
    v.draw_cursor
  end

  # The easy jump label of the start of the line @target names: "line N"
  # (1-based), or else the first line holding that text
  def jump_label
    ej = EasyJump.class_variable_get(:@@cur) rescue nil
    ls = target_line_start
    return ["esc"] if ej.nil? || ls.nil?
    marks = ej.instance_variable_get(:@easy_jump_wsmarks)
    seq = ej.instance_variable_get(:@jump_sequence)
    n = marks.index(ls)
    n.nil? || seq[n].nil? ? ["esc"] : seq[n].downcase.chars
  end

  def target_line_start
    return nil if @target.nil?
    if (m = /\Aline (\d+)\z/.match(@target))
      l = m[1].to_i - 1
      return nil if l < 0 || l > @buf.line_ends.size
      return l == 0 ? 0 : @buf.line_ends[l - 1] + 1
    end
    i = @buf.index(@target)
    return nil if i.nil?
    i == 0 ? 0 : (@buf.rindex("\n", i - 1) || -1) + 1
  end
end
end # module Vimamsa
