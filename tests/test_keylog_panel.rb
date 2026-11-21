class TestKeylogPanel < VmaTest
  def panel
    vma.gui.keylog_panel
  end

  # Show the panel, run the block with a clean log, always hide again so
  # later tests (and other test files) start with logging off.
  def with_panel
    act "panel.keylog.toggle"
    panel.clear
    yield
  ensure
    act "panel.keylog.toggle"
  end

  def test_chord_and_action_logged
    with_panel do
      keys("g g")
      e = panel.entries.last
      assert_eq :action, e[:kind]
      assert_eq "move.buf.start", e[:action]
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
  def drain_for(secs)
    t = Time.now
    while Time.now - t < secs
      drain_idle
      sleep 0.01
    end
  end

  # The bubble next to the cursor (gui_key_hint.rb) shows the key and the
  # action, without the mode badge, near the cursor's line
  def test_hint_near_cursor
    act 'buf.insert_txt("one\ntwo\nthree\nfour\n")'
    keys "g g"
    with_panel do
      keys "j j"
      drain_for(0.1)
      h = panel.hint
      assert h.visible?, "hint not shown"
      assert h.markup.include?("<b>j</b>"), "hint was #{h.markup.inspect}"
      assert !h.markup.include?("[COMMAND]"), "hint has the mode: #{h.markup.inspect}"
      _x, y = vma.gui.view.pos_to_coord(vma.buf.pos)
      top = h.widget.margin_top
      assert (top - y).abs < 100, "hint at y #{top}, cursor at y #{y}"
      assert h.widget.can_target? == false, "the hint takes mouse input"
    end
  end

  # The bubble starts with the mode after the action: v shows VISUAL
  def test_hint_shows_mode
    with_panel do
      keys "j"
      drain_for(0.05)
      assert panel.hint.markup.include?("COMMAND"), panel.hint.markup
      keys "v"
      drain_for(0.05)
      assert panel.hint.markup.include?("VISUAL"), panel.hint.markup
      # the badge's own CSS classes, as the status badge: same theme colors
      ml = panel.hint.mode_label
      assert ml.has_css_class?("mode-badge") && ml.has_css_class?("mode-visual"), ml.css_classes.inspect
      assert !ml.has_css_class?("mode-command"), ml.css_classes.inspect
      keys "esc"
      keys "i"
      drain_for(0.05)
      assert panel.hint.markup.include?("INSERT"), panel.hint.markup
      keys "esc"
    end
  end

  # A long bubble on a long line stays inside the editor (it used to be
  # placed by the width of the previous, shorter text)
  def test_hint_fits_in_view
    with_panel do
      keys "i"
      keys ("a b c d e f g h " * 6).strip
      drain_for(0.1)
      w = panel.hint.widget
      ov = vma.gui.active_window[:overlay]
      right = w.measure(:horizontal, -1)[1] - w.margin_end # measure counts margin_start
      assert right <= ov.width + 1, "hint ends at x #{right}, editor is #{ov.width} wide"
      keys "esc"
    end
  end

  def test_hint_typed_text_and_pending
    with_panel do
      keys "g"
      assert panel.hint.markup.include?("<b>g</b> …"), panel.hint.markup
      keys "esc i a b c"
      assert panel.hint.markup.include?("typed"), panel.hint.markup
      assert panel.hint.markup.include?("abc"), panel.hint.markup
      keys "esc"
    end
  end

  def test_hint_fades_and_hides_with_panel
    with_panel do
      keys "j"
      assert panel.hint.visible?
      drain_for(KeyHint::SHOW_SECS + KeyHint::FADE_SECS + 0.4)
      assert !panel.hint.visible?, "hint didn't fade out"
      keys "k"
      assert panel.hint.visible?
    end
    assert !panel.hint.visible?, "hint still shown with the panel hidden"
  end
  # Easy jump reads its label keys itself; they are logged as one row
  def test_easy_jump_label_logged
    act 'buf.insert_txt("one\ntwo\nthree\nfour\n")'
    keys "g g"
    vma.buf.view.handle_deltas
    with_panel do
      20.times { drain_idle; sleep 0.02 } # laid out: easy jump labels only what's visible
      keys "s"
      ej = EasyJump.class_variable_get(:@@cur)
      marks = ej.instance_variable_get(:@easy_jump_wsmarks)
      seq = ej.instance_variable_get(:@jump_sequence)
      n = marks.index(vma.buf.line_ends[1] + 1) # the start of line 3
      assert n, "no label for line 3: marks #{marks.first(10).inspect}"
      label = seq[n].downcase
      keys label.chars.join(" ")
      e = panel.entries.last
      assert_eq :jump, e[:kind]
      assert_eq label, e[:text]
      assert_eq :jumped, e[:state]
      assert_eq 3, e[:line]
      assert_eq 1, panel.entries.count { |x| x[:kind] == :jump }, "one row per label"
      assert panel.hint.markup.include?(label), panel.hint.markup
    end
  end
end
