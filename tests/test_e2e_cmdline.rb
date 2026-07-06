require_relative "support/virtual_keyboard"

# True end-to-end test of the ":" command line: a uinput virtual keyboard types
# real key events (kernel -> compositor -> this GTK window), verifying that
# focus enters the command line entry — via the @entry_has_focus bypass in the
# window key controller — and that a shell command executes into a new buffer.
#
# Skips when /dev/uinput is not writable, xmodmap is missing, or the editor
# window is not the focused window (never type into someone else's window).
class TestE2eCmdline < VmaTest
  def test_colon_focuses_cmdline_and_executes_shell_command
    with_vkb do |kb|
      assert_mode :command
      orig_buf_id = vma.buf.id
      orig_text = vma.buf.to_s

      kb.type(":")
      assert wait_until(3) { stack.visible_child_name == "cmdline" },
             "':' key opens the command line"
      assert focus_inside?(vma.gui.cmd_line.entry),
             "keyboard focus is inside the command line entry"

      kb.type("!ls")
      assert wait_until(3) { vma.gui.cmd_line.entry.text == "!ls" },
             "typed keys land in the entry (entry has #{vma.gui.cmd_line.entry.text.inspect})"
      assert_eq orig_text, vma.buf.to_s, "editor buffer untouched while typing in the command line"

      kb.tap_keysym("Return")
      ok = wait_until(5) {
        vma.buf.id != orig_buf_id &&
          Dir.children(Dir.pwd).any? { |f| vma.buf.to_s.include?(f) }
      }
      assert ok, "!ls output opened in a new buffer (current buffer starts: #{vma.buf.to_s[0, 80].inspect})"
    end
  end

  def test_escape_closes_and_returns_focus_to_editor
    with_vkb do |kb|
      assert_mode :command
      kb.type(":")
      assert wait_until(3) { stack.visible_child_name == "cmdline" },
             "':' key opens the command line"

      kb.tap_keysym("Escape")
      assert wait_until(3) { stack.visible_child_name != "cmdline" },
             "Escape closes the command line"
      assert !focus_inside?(vma.gui.cmd_line.entry), "focus left the entry"

      # Keys must reach the editor again: 'i' should enter insert mode
      kb.type("i")
      assert wait_until(3) { vma.kbd.get_mode == :insert }, "editor receives keys again after Escape"
      keys("esc")
    end
  end

  private

  # Guard preconditions, open/close the uinput device around the block.
  def with_vkb
    # uinput events go to the real seat's focused window. Only type when this
    # app is itself on the real Wayland session — never on a headless backend
    # (Broadway/Xvfb), where the keystrokes would land in some other program.
    # gtype.name: ruby-gnome has no named Ruby class for some backends.
    backend = Gdk::Display.default&.gtype&.name.to_s
    if !backend.include?("Wayland")
      skip "not on a real Wayland seat (#{backend})"
    end
    skip "no writable /dev/uinput" if !VirtualKeyboard.available?
    skip "xmodmap not available" if !KeyTyper.available?
    vkb = nil
    vma.gui.window.present
    if !wait_until(3) { vma.gui.window.active? }
      skip "editor window is not focused; typing would go to another window"
    end
    vkb = VirtualKeyboard.new.open
    yield KeyTyper.new(vkb)
  ensure
    vkb&.close
  end

  # Poll cond while letting the GTK main loop process the incoming key events.
  def wait_until(timeout)
    t0 = Time.now
    loop do
      drain_idle
      return true if yield
      return false if Time.now - t0 > timeout
      sleep 0.05
    end
  end

  def stack
    vma.gui.instance_variable_get(:@minibuf_stack)
  end

  # True if the window's focus widget is `widget` or one of its descendants
  # (Gtk::Entry keeps focus on an internal GtkText child).
  def focus_inside?(widget)
    f = vma.gui.window.focus_widget
    while f
      return true if f == widget
      f = f.parent
    end
    false
  end
end
