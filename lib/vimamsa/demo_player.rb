module Vimamsa
# Plays the README demo (scripts/demo/demo_steps.txt) inside the running
# editor: Help ▸ Play demo. The same steps that scripts/demo/record_demo.rb
# records into img/demo.gif, on a fresh copy of scripts/demo/shapes.rb, with
# the key log panel showing each key and the action it ran.
#
# The keys go to the key bindings as if typed. Running it again while it
# plays stops it; so does switching to another buffer. When it ends, the key
# log panel is hidden again if it wasn't shown before.
class DemoPlayer
  DIR = File.expand_path("../../scripts/demo", __dir__)
  STEPS = File.join(DIR, "demo_steps.txt")
  SPEED = 0.7 # as the recording: every delay and wait is divided by this

  def self.toggle
    if @current&.running?
      @current.stop("Demo stopped")
    else
      @current = new
      @current.start
    end
  end

  def self.current
    @current
  end

  attr_reader :buf

  # speed: every delay and wait is divided by it (tests play it fast)
  def initialize(speed: SPEED)
    @speed = speed
  end

  def running?
    @running
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
    if !File.exist?(STEPS)
      message("Demo steps not found: #{STEPS}")
      return
    end
    @steps = DemoPlayer.parse(File.read(STEPS))
    # A fresh copy, so the demo can edit it
    dir = File.join(Dir.tmpdir, "vimamsa-demo")
    FileUtils.mkdir_p(dir)
    file = File.join(dir, "shapes.rb")
    FileUtils.cp(File.join(DIR, "shapes.rb"), file)
    old = vma.buffers.list.find { |b| b.fname == file }
    vma.buffers.close_buffer(old.id) if old
    @buf = open_new_file(file)
    @keylog_was_shown = vma.gui.instance_variable_get(:@keylog_shown)
    vma.gui.show_keylog_panel
    vma.kbd.set_mode(:command)
    @queue = [] # [delay in s, proc]
    @delay = 0.4
    @target = nil
    @running = true
    message("Playing the demo. Help ▸ Play demo again stops it.")
    @steps.each { |cmd, arg| plan(cmd, arg) }
    run_next
  end

  def stop(msg = nil)
    return if !@running
    @running = false
    GLib::Source.remove(@timer) rescue nil if @timer
    @timer = nil
    vma.kbd.set_mode(:command) if vma.buf.equal?(@buf)
    # The key log panel goes away again if the demo opened it
    vma.gui.hide_keylog_panel if !@keylog_was_shown
    message(msg) if msg
  end

  private

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

  def run_next
    return if !@running
    if !vma.buf.equal?(@buf)
      stop("Demo stopped (another buffer was opened)")
      return
    end
    if @queue.empty?
      stop("Demo finished")
      return
    end
    delay, action = @queue.shift
    @timer = GLib::Timeout.add([(delay / @speed * 1000).round, 1].max) {
      @timer = nil
      if @running
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

  # The easy jump label of the start of the line holding @target
  def jump_label
    ej = EasyJump.class_variable_get(:@@cur) rescue nil
    i = @target && @buf.index(@target)
    return ["esc"] if ej.nil? || i.nil?
    ls = i == 0 ? 0 : (@buf.rindex("\n", i - 1) || -1) + 1
    marks = ej.instance_variable_get(:@easy_jump_wsmarks)
    seq = ej.instance_variable_get(:@jump_sequence)
    n = marks.index(ls)
    n.nil? || seq[n].nil? ? ["esc"] : seq[n].downcase.chars
  end
end
end # module Vimamsa
