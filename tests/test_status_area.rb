class TestStatusArea < VmaTest

  # ── Mode badge CSS class + text ──────────────────────────────────────────

  def test_badge_insert_mode
    keys "i"
    assert vma.gui.statnfo.css_classes.include?("mode-insert"), "badge should have mode-insert class"
    assert_eq "INSERT", vma.gui.statnfo.text
    keys "esc"
  end

  def test_badge_command_mode
    keys "i esc"
    assert vma.gui.statnfo.css_classes.include?("mode-command"), "badge should have mode-command class"
    assert !vma.gui.statnfo.css_classes.include?("mode-insert"), "mode-insert class should be removed"
    assert_eq "COMMAND", vma.gui.statnfo.text
  end

  def test_badge_visual_mode
    keys "v"
    assert vma.gui.statnfo.css_classes.include?("mode-visual"), "badge should have mode-visual class"
    assert_eq "VISUAL", vma.gui.statnfo.text
    keys "esc"
  end

  # ── Pending key trail ────────────────────────────────────────────────────

  def test_keytrail_shows_pending_chord
    keys ","
    assert vma.gui.keytrail.text.include?(","), "keytrail should show pending chord key"
    keys "esc"
    assert_eq "", vma.gui.keytrail.text
  end

  def test_keytrail_shows_repeat_count
    keys "3"
    assert vma.gui.keytrail.text.include?("3"), "keytrail should show repeat count"
    keys "esc"
  end

  # ── Modified dot in subtitle ─────────────────────────────────────────────

  def test_modified_dot_appears_on_edit
    act 'buf.insert_txt("hello")'
    act "buf.refresh_title"
    drain_idle
    assert vma.gui.subtitle.text.include?("●"), "subtitle should show modified dot after edit"
  end
end
