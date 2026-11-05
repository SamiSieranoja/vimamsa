# An exception raised by a dialog callback must not escape to GTK: ruby-gnome
# calls exit for exceptions leaving a signal handler, quitting the editor.
class TestDialogCallbackErrors < VmaTest
  def test_run_dialog_callback_returns_nil_and_reports
    r = run_dialog_callback("test cb") { raise ArgumentError, "boom" }
    assert_eq nil, r
    assert $vmag.instance_variable_get(:@minibuf_messages).first.include?("ERROR in test cb: boom")
  end

  def test_run_dialog_callback_returns_block_value
    assert_eq 42, run_dialog_callback { 42 }
  end

  def test_run_dialog_callback_does_not_swallow_exit
    raised = false
    begin
      run_dialog_callback { exit }
    rescue SystemExit
      raised = true
    end
    assert raised, "SystemExit must propagate"
  end

  def test_form_submit_with_raising_callback_closes_popup
    PopupFormGenerator.reset_popup_queue
    params = { "inputs" => { "q" => { :label => "Q", :type => :entry } },
               :callback => proc { |_| raise "form boom" } }
    p1 = PopupFormGenerator.new(params)
    p1.run
    drain_idle
    p1.submit
    drain_idle
    assert !PopupFormGenerator.popup_active?, "popup should close even though callback raised"
  ensure
    PopupFormGenerator.reset_popup_queue
  end

  def test_key_controller_submit_raising_is_caught
    entry = Gtk::Entry.new
    press = on_submit_escape(entry, submit: proc { raise "submit boom" })
    handled = press.signal_emit("key-pressed", Gdk::Keyval::KEY_Return, 0, 0)
    assert_eq true, handled
  end
end
