# Form input mode (form_input.rb, doc/demo_recording_plan.md part 1): keys
# in a form go through the key bindings, in mode F, and edit each field's
# Buffer; the Gtk::Entry shows it. Also the shared key names (key_names.rb).
class TestFormInput < VmaTest
  K = Gdk::Keyval

  def teardown_form
    f = FormInput.current
    f&.cancel
    drain_idle
    PopupFormGenerator.reset_popup_queue
  end

  def field
    FormInput.current.field
  end

  # Waits (running the main loop) until the block is true
  def wait_until(secs = 3)
    t = Time.now
    until yield || Time.now - t > secs
      drain_idle
      sleep 0.01
    end
    yield
  end

  def test_key_names
    none = {}
    assert_eq "j", gui_key_name(K::KEY_j, "j", none)
    assert_eq "ctrl-r", gui_key_name(K::KEY_r, "r", { ctrl: true })
    assert_eq "ctrl", gui_key_name(K::KEY_Control_L, "", { ctrl: true }), "no ctrl-ctrl"
    assert_eq "P", gui_key_name(K::KEY_P, "P", { shift: true }), "shift-P is P"
    assert_eq "shift-tab", gui_key_name(K::KEY_ISO_Left_Tab, "", { shift: true })
    assert_eq "space", gui_key_name(K::KEY_space, " ", none)
    assert_eq "esc", gui_key_name(K::KEY_Escape, "\e", none)
    assert_eq "enter", gui_key_name(K::KEY_Return, "\r", none)
    assert_eq "ctrl", gui_key_name(K::KEY_Caps_Lock, "", { ctrl: true }), "caps remapped to ctrl"
    assert_eq "", gui_key_name(0, "\u0000", none)
  end

  # , r r: typed into the form's fields with keys, tab between them, enter
  def test_search_replace_by_keys
    b = create_new_buffer("one two one\n", "formtest")
    act "search.replace"
    assert FormInput.current, "no form"
    assert_mode :form
    keys "o n e tab t h r e e"
    assert_eq "three", field.text
    assert_eq "three", field.entry.text, "entry not showing the buffer"
    keys "enter"
    assert_eq "three two three\n", b.to_s
    assert_mode :command
    assert FormInput.current.nil?
  ensure
    teardown_form
  end

  def test_editing_keys
    act "search.replace"
    keys "a b c d"
    keys "left left backspace"
    assert_eq "acd", field.text
    assert_eq 1, field.pos
    keys "delete"
    assert_eq "ad", field.text
    keys "home x end y"
    assert_eq "xady", field.text
    keys "space z"
    assert_eq "xady z", field.text
    assert_eq field.pos, field.entry.position
  ensure
    teardown_form
  end

  # ctrl-a selects all, ctrl-x cuts it to the system clipboard, ctrl-v
  # pastes it back (asynchronously); typing replaces a selection
  def test_clipboard_keys
    act "search.replace"
    keys "h e l l o"
    keys "ctrl-a"
    assert_eq [0, 5], field.sel
    keys "ctrl-x"
    assert_eq "", field.text
    keys "ctrl-v"
    assert wait_until { field.text == "hello" }, "paste: #{field.text.inspect}"
    keys "ctrl-a ctrl-c x"
    assert_eq "x", field.text, "typing over the selection"
    keys "ctrl-v"
    assert wait_until { field.text == "xhello" }, "paste after x: #{field.text.inspect}"
  ensure
    teardown_form
  end

  def test_esc_cancels
    b = create_new_buffer("one\n", "formtest")
    act "search.replace"
    keys "o n e tab t w o esc"
    assert FormInput.current.nil?
    assert_mode :command
    assert_eq "one\n", b.to_s
  ensure
    teardown_form
  end

  # tab moves through the fields and the buttons; enter on a button presses it
  def test_tab_order_and_buttons
    act "search.replace"
    f = FormInput.current
    assert_eq 4, f.items.size # search, replace, Replace all, Cancel
    keys "tab"
    assert f.field.equal?(f.fields[1])
    keys "tab"
    assert f.focused.is_a?(Gtk::Button)
    keys "x"
    assert_eq ["", ""], f.fields.map(&:text), "typing on a button"
    keys "tab tab"
    assert f.field.equal?(f.fields[0]), "tab wraps around"
    keys "shift-tab"
    assert_eq "Cancel", f.focused.label
    keys "enter"
    assert FormInput.current.nil?, "Cancel not pressed"
  ensure
    teardown_form
  end

  # Keys as the form window's controller passes them (FormInput#key): GTK
  # keyvals translated to key names, modifiers from vma.kbd.modifiers,
  # "ctrl!" only for a ctrl released alone
  def test_window_key_path
    act "search.replace"
    f = FormInput.current
    f.key(K::KEY_h, "h", :key_press)
    f.key(K::KEY_h, "h", :key_release)
    f.key(K::KEY_i, "i", :key_press)
    assert_eq "hi", field.text
    vma.kbd.modifiers[:ctrl] = true
    f.key(K::KEY_Control_L, "", :key_press)
    f.key(K::KEY_a, "a", :key_press)
    f.key(K::KEY_Control_L, "", :key_release) # not alone: no ctrl!
    vma.kbd.modifiers[:ctrl] = false
    assert_eq [0, 2], field.sel, "ctrl-a"
    assert_mode :form
    f.key(K::KEY_BackSpace, "", :key_press)
    assert_eq "", field.text
  ensure
    vma.kbd.modifiers[:ctrl] = false
    teardown_form
  end

  # A confirmation (no fields): enter presses the default button
  def test_confirm_by_enter
    got = nil
    Gui.confirm("Sure?", proc { |x| got = x })
    assert_mode :form
    keys "enter"
    assert_eq "submit", got && got["yes_btn"]
    assert_mode :command
  ensure
    teardown_form
  end

  # The widget's own changes (paste from its menu, input method) and a mouse
  # selection reach the buffer
  def test_widget_changes_reach_buffer
    act "search.replace"
    field.entry.text = "from gtk"
    assert_eq "from gtk", field.text
    field.entry.select_region(0, 4)
    field.pull_cursor
    assert_eq [0, 4], field.sel
    keys "x"
    assert_eq "x gtk", field.text
  ensure
    teardown_form
  end

  # The fields' buffers aren't in the buffer list, and go away with the form
  def test_field_buffers_cleaned_up
    act "search.replace"
    ids = FormInput.current.fields.map { |f| f.buf.id }
    assert vma.buffers.list.none? { |b| ids.include?(b.id) }, "field buffer in the buffer list"
    assert ids.all? { |i| vma.gui.buffers.key?(i) }
    keys "esc"
    assert ids.none? { |i| vma.gui.buffers.key?(i) }, "hidden views left"
  ensure
    teardown_form
  end

  # The key log shows form keys like any others
  def test_key_log_shows_form_keys
    act "panel.keylog.toggle"
    vma.gui.keylog_panel.clear
    act "search.replace"
    keys "q"
    keys "w"
    e = vma.gui.keylog_panel.entries.last
    assert e && e.values.join(" ").include?("qw"), "typed text not in the key log: #{e.inspect}"
  ensure
    teardown_form
    act "panel.keylog.toggle" if vma.gui.keylog_panel.active?
  end
end
