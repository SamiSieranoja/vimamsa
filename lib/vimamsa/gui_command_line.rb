
module Vimamsa
# Interactive command line at the bottom of the window, like vim's ":".
# Lives in the minibuffer area (shares the Gtk::Stack with the message label).
#
# Input is Ruby code by default, evaluated at top level, so the whole editor
# API is available: buf, vma, cnf, bufs, registered helper methods, etc.
# Config changes are plain Ruby assignments:
#   :cnf.font.size = 14
# Local variables persist between invocations (TOPLEVEL_BINDING).
#
# Convenience forms checked before Ruby eval:
#   :!cmd       run cmd in a shell, output to a new buffer
#   :42         jump to line 42
#   :e PATH     open file
#   :w  :q  :wq save / quit / save-and-quit
class CommandLine
  attr_reader :history, :entry

  HISTORY_FILE = "~/.vimamsa/cmd_history.txt"
  HISTORY_MAX = 100

  def initialize(css_provider)
    @active = false
    @history = load_history
    @hist_idx = nil

    prompt = Gtk::Label.new(":")
    prompt.add_css_class("minibuf")
    prompt.style_context.add_provider(css_provider)

    @entry = Gtk::Entry.new
    @entry.hexpand = true
    @entry.has_frame = false
    @entry.add_css_class("minibuf")
    @entry.style_context.add_provider(css_provider)

    @box = Gtk::Box.new(:horizontal, 0)
    @box.append(prompt)
    @box.append(@entry)

    @entry.signal_connect("activate") do
      line = @entry.text
      close
      execute(line)
    end

    keyctr = Gtk::EventControllerKey.new
    keyctr.signal_connect "key-pressed" do |_ctr, keyval, _keycode, _state|
      case Gdk::Keyval.to_name(keyval)
      when "Escape"
        close
        true
      when "Up"
        history_move(1)
        true
      when "Down"
        history_move(-1)
        true
      else
        false
      end
    end
    @entry.add_controller(keyctr)

    # Clicking elsewhere abandons the command line (like vim losing ":" focus)
    focusctr = Gtk::EventControllerFocus.new
    focusctr.signal_connect("leave") { close }
    @entry.add_controller(focusctr)
  end

  # The outermost widget, added to the minibuffer stack as "cmdline".
  def widget
    @box
  end

  def active?
    @active
  end

  def start
    return if @active
    @active = true
    @hist_idx = nil
    @entry.text = ""
    vma.gui.cmd_line_show
    @entry.grab_focus
  end

  def close
    return if !@active
    @active = false
    vma.gui.cmd_line_hide
  end

  # Parse and run one command line. Public so tests and other code can drive
  # the command line without the GUI entry.
  def execute(line)
    line = line.strip
    return if line.empty?
    add_to_history(line)

    case line
    when /\A!(.+)\z/m
      shell_to_buffer(Regexp.last_match(1).strip)
    when /\A\d+\z/
      buf.jump_to_line(line.to_i)
    when "w"
      buf.save
    when "q"
      exec_action(:quit)
    when "wq"
      buf.save
      exec_action(:quit)
    when /\Ae\s+(\S.*)\z/
      open_new_file(File.expand_path(Regexp.last_match(1).strip))
    else
      eval_ruby(line)
    end
  end

  private

  # Run Ruby at top level; locals persist across invocations because
  # TOPLEVEL_BINDING is reused. Result (or error) is echoed to the minibuffer.
  def eval_ruby(code)
    result = eval(code, TOPLEVEL_BINDING)
    s = (result.inspect rescue result.class.to_s)
    s = s[0, 200] + "…" if s.size > 200
    message("=> #{s}")
  rescue SystemExit, SignalException
    raise
  rescue Exception => e
    message("ERROR: #{e.class}: #{e.message}")
  end

  # Run a shell command in a background thread; open stdout (+stderr) in a
  # new buffer. GTK work is marshalled back onto the main loop.
  def shell_to_buffer(cmd)
    return if cmd.empty?
    Thread.new do
      begin
        require "open3"
        stdout, stderr, status = Open3.capture3(cmd)
        GLib::Idle.add do
          out = stdout
          out += "\n[stderr]\n#{stderr}" if !stderr.empty?
          out = "(no output)\n" if out.empty?
          create_new_buffer(out, "shellcmd")
          message("!#{cmd}: exit status #{status.exitstatus}") if !status.success?
          false
        end
      rescue Exception => e
        GLib::Idle.add do
          message("ERROR: !#{cmd}: #{e.message}")
          false
        end
      end
    end
  end

  # ── History ────────────────────────────────────────────────────────────────

  # dir: 1 = older, -1 = newer. Leaving the newest entry restores the text
  # that was being typed before browsing started.
  def history_move(dir)
    return if @history.empty?
    if @hist_idx.nil?
      return if dir < 0
      @pending_text = @entry.text
      @hist_idx = 0
    else
      @hist_idx += dir
    end
    if @hist_idx < 0
      @hist_idx = nil
      @entry.text = @pending_text.to_s
    else
      @hist_idx = @history.size - 1 if @hist_idx >= @history.size
      @entry.text = @history[@history.size - 1 - @hist_idx]
    end
    @entry.set_position(-1)
  end

  def add_to_history(line)
    @history.delete(line)
    @history << line
    @history = @history.last(HISTORY_MAX)
    save_history
  end

  def load_history
    f = File.expand_path(HISTORY_FILE)
    return [] if !File.exist?(f)
    File.readlines(f, chomp: true).reject(&:empty?).last(HISTORY_MAX)
  rescue StandardError
    []
  end

  def save_history
    return if ARGV.include?("--test") # don't pollute history from test runs
    f = File.expand_path(HISTORY_FILE)
    return if !Dir.exist?(File.dirname(f))
    File.write(f, @history.join("\n") + "\n")
  rescue StandardError
  end
end
end # module Vimamsa
