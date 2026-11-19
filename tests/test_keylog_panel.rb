class TestKeylogPanel < VmaTest
  def panel
    vma.gui.keylog_panel
  end

  # Show the panel, run the block with a clean log, always hide again so
  # later tests (and other test files) start with logging off.
  def with_panel
    act :toggle_keylog_panel
    panel.clear
    yield
  ensure
    act :toggle_keylog_panel
  end

  def test_chord_and_action_logged
    with_panel do
      keys("g g")
      e = panel.entries.last
      assert_eq :action, e[:kind]
      assert_eq :jump_start_of_buffer, e[:action]
      assert e[:chord].include?("g g"), "chord was #{e[:chord].inspect}"
      assert e[:chord].include?("[COMMAND]"), "chord was #{e[:chord].inspect}"
    end
  end

  def test_pending_chord_shown
    with_panel do
      keys("g")
      e = panel.entries.last
      assert_eq :pending, e[:kind]
      assert e[:chord].include?("g"), "chord was #{e[:chord].inspect}"
      keys("g")
      # Completing the chord replaces the pending row with the action row
      assert_eq :action, panel.entries.last[:kind]
      assert_eq 0, panel.entries.count { |x| x[:kind] == :pending }
    end
  end

  def test_insert_mode_coalesced
    with_panel do
      keys("i h e l l o")
      ins = panel.entries.select { |e| e[:kind] == :insert }
      assert_eq 1, ins.size
      assert_eq "hello", ins.first[:text]
      keys("esc")
    end
  end

  def test_no_logging_when_hidden
    n = panel.entries.size
    keys("g g")
    assert_eq n, panel.entries.size
  end

  def test_newest_shown_at_top_and_highlighted
    with_panel do
      keys("j")
      keys("k")
      row = panel.newest_row
      assert row.css_classes.include?("keylog-newest"), "newest row not highlighted"
      assert_eq row, panel.top_row
      assert_eq :action, panel.entries.last[:kind]
    end
  end

  def test_entry_cap
    with_panel do
      210.times { keys("j") }
      cap = Vimamsa::KeyLogPanel::MAX_ENTRIES
      assert panel.entries.size <= cap, "#{panel.entries.size} entries exceeds cap #{cap}"
    end
  end

  # Let GTK lay out the pane (set_keylog_width waits for an allocation)
  def settle
    t = Time.now
    drain_idle
    GLib::MainContext.default.iteration(false) while Time.now - t < 0.4
  end

  # First show uses the default width, and long entries (even without
  # spaces) don't widen it
  def test_width_fixed_on_first_show
    gui = vma.gui
    old = gui.instance_variable_get(:@keylog_width)
    gui.instance_variable_set(:@keylog_width, nil)
    with_panel do
      settle
      w = gui.keylog_width
      assert (w - VMAgui::PANEL_DEFAULT_WIDTH[:keylog]).abs <= 2, "first width #{w}"
      5.times { keys("e") }    # "Jump to the end of the next word"
      keys("o esc")            # a long action string without spaces
      keys("g g")
      settle
      assert_eq w, gui.keylog_width
    end
  ensure
    gui.instance_variable_set(:@keylog_width, old)
  end
end
