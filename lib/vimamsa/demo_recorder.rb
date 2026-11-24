module Vimamsa
# Records a demo like a macro (help.demo.record),
# into the demo step format that DemoPlayer plays (doc/demo_recording_plan.md,
# part 2). The keys are taken where every key comes in (the :key_input event
# of KeyBindingTree#match_key_conf, where DemoPlayer also feeds them), so
# whatever goes through the key bindings is recorded, typing in forms too.
#
# Recorded per key: the time, the key name, the mode before it, the action
# it ran (if any) and the cursor's line before it. At the end the keys become
# steps (DemoRecorder.steps): delay, wait, keys, type, and target +
# @JUMP_LABEL@ for easy jump labels (they depend on the window size). The
# demo is saved in <user dir>/demos/<name>/ with a copy of the file as it was
# at the start, and played with DemoPlayer.toggle (DemoPlayer.demos).
class DemoRecorder
  # One recorded key
  # read: read by something else than the key bindings (easy jump's label
  # keys, while its key override is on)
  Key = Struct.new(:t, :key, :mode, :action, :line, :col, :read, keyword_init: true)

  MODIFIERS = %w[ctrl alt shift]
  MAX_WAIT = 3.0 # a longer pause is cut to this

  class << self
    # The recorder recording now, or nil
    attr_accessor :current
    # The demo saved last (a DemoPlayer.demos key)
    attr_accessor :last_saved
  end

  def self.toggle
    if @current
      @current.stop
    else
      @current = new
      @current.start
    end
  end

  def self.recording? = !@current.nil?

  attr_reader :keys, :buf, :start_text

  def initialize
    @keys = []
  end

  def start
    @buf = vma.buf
    # Where a demo starts playing: Command mode, the cursor at the top
    vma.kbd.set_mode(:command)
    @buf.set_pos(0)
    @start_text = @buf.to_s.dup
    @start_fname = @buf.fname
    @t0 = now
    @recording = true
    DemoRecorder.watch
    vma.gui.set_status_indicator(:demo_record, "● REC demo", css_class: "status-recording") rescue nil
    message("Recording a demo from the top of the file. Running help.demo.record again stops it.")
  end

  # Stops; asks for a name and saves (save: false only stops, for tests)
  def stop(save: true)
    @recording = false
    DemoRecorder.current = nil
    vma.gui.set_status_indicator(:demo_record, nil) rescue nil
    drop_stop_keys
    @end_line = @buf.lpos
    @end_col = @buf.cpos
    if @keys.empty?
      message("Demo recording stopped: no keys recorded")
      return
    end
    ask_name_and_save if save
  end

  def recording? = @recording

  # A key from :key_input
  def key_input(c, event_type)
    return if !@recording
    if event_type == :key_release
      # ctrl (alt, shift) alone: pressed and released with nothing between,
      # which is what "ctrl!" means and what DemoPlayer#press("ctrl") plays
      if @pending_mod && c == "#{@pending_mod.key}!"
        @keys << @pending_mod
      end
      @pending_mod = nil
      return
    end
    k = Key.new(t: now - @t0, key: c, mode: vma.kbd.get_mode, line: vma.buf.lpos, col: vma.buf.cpos,
                read: vma.kbd.keyhandling_override?)
    if MODIFIERS.include?(c)
      @pending_mod = k
    else
      @pending_mod = nil
      @keys << k
    end
  end

  # The action the last key ran (:key_action)
  def key_action(action)
    return if !@recording || @keys.empty?
    @keys.last.action = action.to_s
  end

  # The steps file text (see DemoRecorder.steps)
  def steps_text(title: nil, file: nil)
    DemoRecorder.steps(@keys, end_line: @end_line || @buf.lpos, end_col: @end_col || @buf.cpos, title: title, file: file)
  end

  # Saves into <user dir>/demos/<slug>/: steps.txt and the start file
  def save(name)
    slug = DemoRecorder.slug(name)
    dir = File.join(DemoPlayer.user_demos_dir, slug)
    FileUtils.mkdir_p(dir)
    file = @start_fname ? File.basename(@start_fname) : "demo.txt"
    File.write(File.join(dir, file), @start_text)
    File.write(File.join(dir, "steps.txt"), steps_text(title: name, file: file))
    DemoRecorder.last_saved = DemoPlayer.user_demo_key(slug)
    message("Demo saved: #{dir} (play it: help.demo.recorded.last)")
    dir
  end

  # "My demo!" -> "my_demo"
  def self.slug(name)
    s = name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "")
    s.empty? ? "demo" : s
  end

  # Subscribes once to the key events
  def self.watch
    return if @watched
    @watched = true
    vma.kbd.on(:key_input) { |c, ev| @current&.key_input(c, ev) }
    vma.kbd.on(:key_action) { |_trail, action| @current&.key_action(action) }
  end

  # Steps from recorded keys (Key list, times in seconds from the start).
  # end_line, end_col: the cursor's place when recording stopped (for an
  # easy jump at the end).
  def self.steps(keys, end_line: 0, end_col: 0, title: nil, file: nil)
    out = []
    out << "# Recorded with help.demo.record (#{Time.now.strftime("%Y-%m-%d")})."
    out << "# Edit freely; the format is in scripts/demo/demo_steps.txt."
    out << "title #{title}" if title
    out << "file #{file}" if file
    gaps = keys.each_cons(2).map { |a, b| b.t - a.t }.select { |g| g > 0 && g < 2.0 }
    delay = gaps.empty? ? 0.4 : (median(gaps) * 20).round / 20.0
    delay = delay.clamp(0.2, 0.8)
    out << "delay #{fmt(delay)}"
    out << "wait 1"

    groups = group(keys, end_line, end_col)
    prev_t = nil
    groups.each { |g|
      if prev_t
        gap = g[:t] - prev_t
        w = [gap - delay, MAX_WAIT].min
        out << "wait #{fmt((w * 10).round / 10.0)}" if gap > 2 * delay && w >= 0.1
      end
      out.concat(g[:lines])
      prev_t = g[:t_end]
    }
    out.join("\n") + "\n"
  end

  # Keys in groups that become step lines: a run typed in Insert (or form)
  # mode is a type line; an easy jump label is target + @JUMP_LABEL@; other
  # keys go in keys lines, a new one after a pause
  def self.group(keys, end_line, end_col = 0)
    groups = []
    i = 0
    while i < keys.size
      k = keys[i]
      if typed_char(k)
        j = i
        text = +""
        while j < keys.size && typed_char(keys[j]) && (j == i || keys[j].t - keys[j - 1].t < 2.0)
          text << typed_char(keys[j])
          j += 1
        end
        lines = []
        # leading spaces would be lost after "type "
        lead = text[/\A */].size
        lines << "keys #{(["space"] * lead).join(" ")}" if lead > 0
        lines << "type #{text[lead..]}" if text.size > lead
        groups << { t: k.t, t_end: keys[j - 1].t, lines: lines }
        i = j
      elsif k.action.to_s.match?(/jump\.easy/)
        # The label keys after it: read by easy jump itself (not just any
        # key without an action: the d of d d has none either)
        j = i + 1
        j += 1 while j < keys.size && keys[j].read
        # Where the cursor landed: the place before the next key
        line, col = j < keys.size ? [keys[j].line, keys[j].col] : [end_line, end_col]
        groups << { t: k.t, t_end: k.t, lines: ["# #{desc(k)}", "keys #{k.key}"] } # s
        groups << { t: keys[i + 1]&.t || k.t, t_end: keys[j - 1].t,
                    lines: ["target line #{line + 1} col #{col.to_i + 1}", "keys @JUMP_LABEL@"] } if j > i + 1
        i = j
      else
        j = i
        run = []
        while j < keys.size && !typed_char(keys[j]) && !keys[j].action.to_s.match?(/jump\.easy/) &&
              (j == i || keys[j].t - keys[j - 1].t < 1.0)
          run << keys[j]
          j += 1
        end
        lines = []
        d = run.map { |x| desc(x) }.compact.uniq
        lines << "# #{d.join(", ")}" if d.any?
        # "#" can only be last on a line (" # " starts a comment)
        line = []
        run.each { |x|
          line << x.key
          if x.key == "#"
            lines << "keys #{line.join(" ")}"
            line = []
          end
        }
        lines << "keys #{line.join(" ")}" if line.any?
        groups << { t: k.t, t_end: run.last.t, lines: lines }
        i = j
      end
    end
    groups
  end

  # The character a key typed in Insert or form mode, or nil
  def self.typed_char(k)
    return nil if ![:insert, :form].include?(k.mode)
    return nil if !k.action.to_s.match?(/insert\.(char|space)|insert_txt/)
    return " " if k.key == "space"
    k.key.size == 1 ? k.key : nil
  end

  # The description of the action a key ran
  def self.desc(k)
    return nil if k.action.nil?
    id = k.action[/\Aa\.([a-z][a-z0-9_.]*)!/, 1] || k.action
    d = vma.actions[id]&.method_name.to_s
    d.empty? || d == id ? id : d.sub("<char>", k.key)
  end

  def self.median(a)
    s = a.sort
    s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0
  end

  def self.fmt(x)
    x.to_s.sub(/\.0\z/, "")
  end

  private

  def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # The keys of the stop command itself (when it has a key binding): from the
  # last key that ran another action
  def drop_stop_keys
    i = @keys.rindex { |k| k.action.to_s.include?("help.demo.record") }
    return if i.nil?
    j = i
    j -= 1 while j > 0 && @keys[j - 1].action.nil?
    @keys.slice!(j..)
  end

  # A form for the demo's name (typed in form mode, so this works with keys)
  def ask_name_and_save
    params = { "title" => "Save the recorded demo", "inputs" => {} }
    base = @start_fname ? File.basename(@start_fname, ".*") : "demo"
    params["inputs"]["name"] = { label: "Name", type: :entry, initial_text: "#{base} demo" }
    params["inputs"]["save_btn"] = { label: "Save", type: :button }
    params[:callback] = proc { |x| save(x["name"]) if !x["name"].to_s.strip.empty? }
    PopupFormGenerator.new(params).run
  end
end
end # module Vimamsa
