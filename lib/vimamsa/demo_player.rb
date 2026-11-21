module Vimamsa
# Plays a demo inside the running editor (Help ▸ Demos), on fresh copies of
# files in scripts/demo, with the key log panel showing each key and the
# action it ran. The demos (DEMOS) are step files in scripts/demo:
#   basic     square/steps.txt (recorded with Help ▸ Demos ▸ Record demo):
#             editing shapes.rb into a Square class, with Insert and Visual
#             mode, easy jump, search and replace and the action search.
#             (demo_steps.txt is the README demo that record_demo.rb
#             records into img/demo.gif.)
#   easyjump  demo_easyjump_steps.txt: moving and selecting with easy jump
#   files     demo_files_steps.txt: switching between files (tab, browse
#             mode h / l, the file explorer , f)
#
# The keys go to the key bindings as if typed. At the end the files go back
# to how they were and the demo starts again, until it is stopped: the same
# menu item again, the key log's ✕, or switching to a buffer that isn't one
# of the demo's (or the file explorer).
# The buttons above the key log (and the help.demo.* actions) pause and
# continue it and change its speed. When it stops, the key log panel is
# hidden again if it wasn't shown before.
class DemoPlayer
  DIR = File.expand_path("../../scripts/demo", __dir__)
  STEPS = File.join(DIR, "demo_steps.txt")
  # steps: the step file. files: copied and opened, the first one last (it
  # is current and the newest in the buffer history). dir: a subfolder of
  # WORK_DIR, emptied first, so the file explorer shows only these files.
  # title, desc, action: for the Help ▸ Demos menu, the introduction page
  # (help/intro.txt) and the demo list above the key log.
  DEMOS = {
    basic: { steps: File.join(DIR, "square", "steps.txt"), files: ["shapes.rb"], src: File.join(DIR, "square"),
             title: "Basic editing", desc: "a Square class: editing, Visual mode, easy jump, replace, actions", action: "help.demo" },
    easyjump: { steps: File.join(DIR, "demo_easyjump_steps.txt"), files: ["shapes.rb"],
                title: "Easy jump", desc: "jump anywhere on the screen with a few keys", action: "help.demo.easyjump" },
    files: { steps: File.join(DIR, "demo_files_steps.txt"), files: ["shapes.rb", "report.rb", "notes.txt"], dir: "files",
             title: "Switching files", desc: "the last file, buffer history, the file explorer", action: "help.demo.files" },
  }
  WORK_DIR = File.join(Dir.tmpdir, "vimamsa-demo")

  # Recorded demos (demo_recorder.rb): <user dir>/demos/<slug>/steps.txt and
  # the files they start from
  def self.user_demos_dir
    File.join(vma_user_dir, "demos")
  end

  def self.user_demo_key(slug) = :"user_#{slug}"

  # The recorded demos, like DEMOS. Their title, desc and files come from
  # the steps file's header (title, desc, file). Each gets an action
  # help.demo.user.<slug>.
  def self.user_demos
    Dir[File.join(user_demos_dir, "*", "steps.txt")].sort.to_h { |f|
      dir = File.dirname(f)
      slug = File.basename(dir)
      steps = (parse(File.read(f)) rescue [])
      head = lambda { |c| steps.find { |x, _| x == c }&.last }
      files = steps.select { |x, _| x == "file" }.map(&:last)
      key = user_demo_key(slug)
      title = head.("title") || slug
      action = "help.demo.user.#{slug}"
      if vma.actions && !vma.actions.include?(action)
        reg_act(action, proc { DemoPlayer.toggle(key) }, "Play the recorded demo #{title} (again: stop it)")
      end
      [key, { steps: f, files: files.empty? ? ["demo.txt"] : files, src: dir, dir: "user_#{slug}",
              title: title, desc: head.("desc") || "recorded demo", action: action }]
    }
  end

  # The built-in demos and the recorded ones
  def self.demos
    DEMOS.merge(user_demos)
  end
  SPEED = 0.7 # as the recording: every delay and wait is divided by this
  RATES = [0.25, 0.5, 0.75, 1, 1.5, 2, 3, 4] # user speeds, times SPEED

  # Plays demo name; if it is the one playing, stops it instead (another
  # one playing is stopped first, and the new one keeps its speed)
  def self.toggle(name = :basic)
    rate = nil
    if @current&.running?
      same = @current.name == name
      rate = @current.rate
      @current.stop("Demo stopped")
      return if same
    end
    @current = rate ? new(name, rate: rate) : new(name)
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
  # demo: a demo entry like DEMOS' ({ steps:, files:, src: }) instead of
  # name's (e.g. a steps file given to scripts/demo/record_demo.rb).
  # controls: false hides the pause / speed controls (in a recording).
  # on_finish: called with the stop message when the demo stops.
  def initialize(name = :basic, speed: SPEED, loop: true, steps: nil, rate: 0.75, demo: nil, controls: true, on_finish: nil)
    @name = name
    @demo = demo || DemoPlayer.demos.fetch(name)
    @controls = controls
    @on_finish = on_finish
    @steps_file = @demo[:steps]
    @speed = speed
    @loop = loop
    @given_steps = steps
    @rate = rate
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

  # Seconds one round of demo name takes at the default speed (keys after
  # an easy jump label count as one)
  def self.duration(name, rate: new(name).rate)
    secs = 0.0
    delay = 0.4
    parse(File.read(demos.fetch(name)[:steps])).each { |cmd, arg|
      case cmd
      when "wait" then secs += arg.to_f
      when "delay" then delay = arg.to_f
      when "keys" then secs += delay * arg.split.size
      when "type" then secs += delay * arg.size
      end
    }
    secs / (SPEED * rate)
  end

  # "40 s", "2 min"
  def self.duration_text(name)
    s = duration(name)
    s < 90 ? "#{(s / 10).round * 10} s" : "#{(s / 60).round} min"
  end

  # The steps of demo_steps.txt as [command, argument] pairs (see its header)
  def self.parse(text)
    text.lines(chomp: true).filter_map { |line|
      line = line.sub(/\s+#\s.*\z/, "") unless line.start_with?("type ")
      next if line.strip.empty? || line.start_with?("#")
      cmd, arg = line.split(" ", 2)
      raise "demo_steps.txt: unknown command #{line.inspect}" if !%w[keys type wait delay target title desc file].include?(cmd)
      [cmd, arg.to_s]
    }
  end

  def start
    if !@given_steps && !File.exist?(@steps_file)
      message("Demo steps not found: #{@steps_file}")
      return
    end
    @steps = @given_steps || DemoPlayer.parse(File.read(@steps_file))
    # Started from a help page (the introduction): back to it at the end
    @return_buf = vma.buf if vma.buf&.help_page
    open_files
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

  # Why it stopped (the message shown), e.g. "Demo finished"
  attr_reader :stop_message

  def stop(msg = nil)
    return if !@running
    @stop_message = msg
    @running = false
    @paused = false
    remove_timer
    in_demo = demo_buf?(vma.buf) || explorer_buf?(vma.buf)
    vma.kbd.set_mode(:command) if demo_buf?(vma.buf)
    vma.gui.keylog_panel.hide_demo_controls
    # Back to the help page it was started from, unless the user went to
    # another buffer
    if in_demo && @return_buf && vma.buffers.list.any? { |b| b.equal?(@return_buf) }
      vma.buffers.set_current_buffer_by_id(@return_buf.id)
    end
    # The key log panel goes away again if the demo opened it
    vma.gui.hide_keylog_panel if !@keylog_was_shown
    message(msg) if msg
    @on_finish&.call(msg)
  end

  # The demo's buffers, the first file's first
  attr_reader :bufs

  private

  def demo_buf?(b)
    @bufs.any? { |x| x.equal?(b) }
  end

  # The file explorer (, f), which the files demo uses
  def explorer_buf?(b)
    b.respond_to?(:module) && b.module.is_a?(FileManager)
  end

  # Fresh copies of the demo's files (so the demo can edit them), opened
  # with the first one last
  def open_files
    dir = WORK_DIR
    if @demo[:dir]
      dir = File.join(WORK_DIR, @demo[:dir])
      FileUtils.rm_rf(dir) if dir.start_with?(WORK_DIR + "/")
    end
    FileUtils.mkdir_p(dir)
    files = @demo[:files].map { |f|
      path = File.join(dir, f)
      FileUtils.cp(File.join(@demo[:src] || DIR, f), path)
      old = vma.buffers.list.find { |b| b.fname == path }
      vma.buffers.close_buffer(old.id) if old
      path
    }
    @bufs = files.reverse.map { |f| open_new_file(f) }.reverse
    @buf = @bufs[0]
    @originals = @bufs.map { |b| File.read(b.fname) }
  end


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
    # The files as at the start, and the buffer history in the same order
    @bufs.zip(@originals).reverse_each { |b, text|
      vma.buffers.set_current_buffer(b.id)
      b.revert_by_diff(text.dup)
      b.set_pos(0)
      b.view&.handle_deltas
    }
    begin_round
  end

  def remove_timer
    GLib::Source.remove(@timer) rescue nil if @timer
    @timer = nil
  end

  def show_controls
    return if !@controls
    vma.gui.keylog_panel.show_demo_controls(paused: @paused, rate: DemoPlayer.rate_label(@rate), demo: @name)
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
          @queue << [@delay, proc { type_jump_label }]
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
    if !demo_buf?(vma.buf) && !explorer_buf?(vma.buf)
      stop("Demo stopped (another buffer was opened: #{vma.buf&.fname || vma.buf.class})")
      return
    end
    # A paste (p, P, ctrl-v) reads the clipboard asynchronously: the next
    # key waits for it (at most 2 s: the flag stays set if the read fails)
    if vma.buf.instance_variable_get(:@clipboard_paste_running)
      @paste_wait ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) - @paste_wait < 2
        @timer = GLib::Timeout.add(20) { @timer = nil; run_next; false }
        return
      end
    end
    @paste_wait = nil
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

  # Types the label easy jump gave the target. A target not shown in this
  # window (smaller than the one the demo was recorded in) has no label:
  # easy jump is cancelled and the cursor goes there directly, where the
  # jump would have taken it.
  def type_jump_label
    keys = jump_label
    tp = target_pos
    if keys == ["esc"] && tp
      press("esc")
      vma.buf.set_pos(tp)
      v = vma.buf.view
      v&.handle_deltas
      v&.draw_cursor
    else
      keys.each { |c| press(c) }
    end
  end

  # The easy jump label of the start of the line @target names: "line N"
  # (1-based), or else the first line holding that text
  def jump_label
    ej = EasyJump.class_variable_get(:@@cur) rescue nil
    tp = target_pos
    return ["esc"] if ej.nil? || tp.nil?
    marks = ej.instance_variable_get(:@easy_jump_wsmarks)
    seq = ej.instance_variable_get(:@jump_sequence)
    n = marks.index(tp)
    if n.nil?
      # Not labelled here (e.g. not visible in this window): the nearest
      # labelled place on the same line
      ls = line_start_of(tp)
      le = vma.buf.index("\n", tp) || vma.buf.size
      near = marks.each_with_index.select { |m, _| m >= ls && m <= le }.min_by { |m, _| (m - tp).abs }
      n = near&.last
    end
    n.nil? || seq[n].nil? ? ["esc"] : seq[n].downcase.chars
  end

  # Where @target says easy jump goes: "line N col C" (1-based, the place
  # the recorder saw the cursor land), "line N" (its start), or the start
  # of the first line holding the text
  def target_pos
    return nil if @target.nil?
    if (m = /\Aline (\d+)(?: col (\d+))?\z/.match(@target))
      l = m[1].to_i - 1
      return nil if l < 0 || l > vma.buf.line_ends.size
      ls = l == 0 ? 0 : vma.buf.line_ends[l - 1] + 1
      return ls if m[2].nil?
      le = vma.buf.index("\n", ls) || vma.buf.size
      return (ls + m[2].to_i - 1).clamp(ls, le)
    end
    i = vma.buf.index(@target)
    return nil if i.nil?
    line_start_of(i)
  end

  def line_start_of(pos)
    pos == 0 ? 0 : (vma.buf.rindex("\n", pos - 1) || -1) + 1
  end
end
end # module Vimamsa
