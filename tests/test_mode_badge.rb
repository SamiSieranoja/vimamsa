# Regression tests for the mode badge (e.g. COMMAND) shown in the status area.
#
# Bug: the badge stayed blank on startup because show_state_trail was only ever
# called from key handling — so the mode was not displayed until the first
# keypress. Editor#start now calls set_state_to_root + show_state_trail after
# init to paint it immediately.
class TestModeBadge < VmaTest

  def badge_text
    vma.gui.statnfo.text
  end

  # Force a re-render regardless of the last painted value (update_mode_badge
  # skips the update when the text is unchanged).
  def render_badge
    vma.gui.instance_variable_set(:@last_badge_text, nil)
    vma.kbd.set_state_to_root
    vma.kbd.show_state_trail
  end

  # The exact sequence Editor#start runs must paint a non-blank badge, even
  # starting from the pre-fix state where the label is empty.
  def test_startup_sequence_paints_badge
    vma.kbd.set_mode(:command)
    vma.gui.statnfo.text = ""          # simulate the blank pre-fix state
    render_badge
    assert !badge_text.empty?, "mode badge should be painted, was blank"
    assert_eq "COMMAND", badge_text
  end

  # Badge reflects the active mode.
  def test_badge_reflects_mode
    vma.kbd.set_mode(:insert)
    render_badge
    assert_eq "INSERT", badge_text

    vma.kbd.set_mode(:command)
    render_badge
    assert_eq "COMMAND", badge_text
  end

  # Bug: closing a popup with the mouse (e.g. "Restore" in the session-restore
  # prompt) restored the mode, but the badge kept showing the popup's form
  # mode "F" until the next key. The badge must follow the mode by itself.
  def test_badge_follows_popup_closed_with_mouse
    PopupFormGenerator.reset_popup_queue
    vma.kbd.set_mode(:command)
    clicked = false
    params = {
      "title" => "Test popup",
      "inputs" => { "yes_btn" => { :label => "Yes", :type => :button, :default_focus => true } },
      :callback => proc { clicked = true },
    }
    pop = PopupFormGenerator.new(params)
    pop.run
    drain_idle
    assert_mode :form
    assert_eq "F", badge_text, "badge should show the popup's form mode"
    # A mouse click: the button's "clicked" signal, no key event
    pop.instance_variable_get(:@default_button).signal_emit("clicked")
    drain_idle
    assert clicked, "button callback did not run"
    assert_mode :command
    assert_eq "COMMAND", badge_text, "badge should follow the mode without a key press"
  ensure
    PopupFormGenerator.reset_popup_queue
    vma.kbd.set_mode(:command)
  end
end
