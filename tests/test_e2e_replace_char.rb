require_relative "support/virtual_keyboard"

# True end-to-end test of the "r" (replace character) command with a *non-ASCII*
# replacement typed via AltGr: a uinput virtual keyboard emits real key events
# (kernel -> compositor -> IM -> this GTK window), so the "ä" arrives the same
# way it does for a user on an English (international, AltGr dead keys) layout,
# where AltGr-q produces "ä" (keysym adiaeresis).
#
# Sequence: type a random line, "g g" to the start of the buffer, then "r" +
# AltGr-q — the first character must become "ä".
#
# Skips when /dev/uinput is not writable, xmodmap is missing, the editor window
# is not the focused window, or the active layout has no "ä" key.
class TestE2eReplaceChar < VmaTest
  include VkbTest

  CHAR = "ä" # AltGr-q on us(altgr-intl); typed by keysym, so layout-independent

  def test_replace_first_char_with_altgr_umlaut
    with_vkb do |kb|
      skip "layout cannot type #{CHAR.inspect} (no adiaeresis key)" if !kb.can_type?(CHAR)
      assert_mode :command

      text = random_line
      expected = CHAR + text[1..] + "\n"

      # Enter one line of random text.
      kb.type("i")
      assert wait_until(3) { vma.kbd.get_mode == :insert }, "'i' enters insert mode"
      kb.type(text)
      assert wait_until(5) { vma.buf.to_s == text + "\n" },
             "typed line landed in the buffer (buffer is #{vma.buf.to_s.inspect})"
      kb.tap_keysym("Escape")
      assert wait_until(3) { vma.kbd.get_mode == :command }, "Escape returns to command mode"

      # Go to the beginning of the buffer.
      kb.type("gg")
      assert wait_until(3) { vma.buf.pos == 0 },
             "'g g' moved to the start of the buffer (pos is #{vma.buf.pos})"

      # "r" then AltGr-q: replace the first character with "ä".
      kb.type("r")
      kb.tap_keysym(Gdk::Keyval.to_name(CHAR.ord)) # adiaeresis == AltGr-q
      assert wait_until(3) { vma.buf.to_s == expected },
             "first character replaced by #{CHAR.inspect}\n" \
             "  expected: #{expected.inspect}\n  actual:   #{vma.buf.to_s.inspect}"
      assert_mode :command
    end
  end

  private

  # A line of random lowercase words. Kept to unshifted ASCII so typing it does
  # not depend on the layout; the first character is what "r" will replace.
  def random_line
    4.times.map { (3 + rand(5)).times.map { ("a".."z").to_a.sample }.join }.join(" ")
  end
end
