# PopupFormGenerator serializes modal popups: only one shows at a time, the
# rest queue and appear as each closes. This prevents two modal dialogs (e.g.
# the session-restore dialog and a startup file's autosave dialog at startup)
# from grabbing input simultaneously and getting stuck.

class TestPopupQueue < VmaTest
  def popup_params
    { "inputs" => { "ok" => { :label => "OK", :type => :button } }, :callback => proc {} }
  end

  def test_second_popup_queues_until_first_closes
    PopupFormGenerator.reset_popup_queue

    p1 = PopupFormGenerator.new(popup_params)
    p1.run
    assert(PopupFormGenerator.popup_active?, "first popup should be active")
    assert_eq(0, PopupFormGenerator.popup_queue_size)

    # Second popup requested while the first is open -> queued, not shown.
    p2 = PopupFormGenerator.new(popup_params)
    p2.run
    assert(PopupFormGenerator.popup_active?, "first popup still active")
    assert_eq(1, PopupFormGenerator.popup_queue_size, "second popup should be queued")

    # Close the first -> the queued popup is presented.
    p1.close
    drain_idle
    assert(PopupFormGenerator.popup_active?, "queued popup should now be active")
    assert_eq(0, PopupFormGenerator.popup_queue_size, "queue should be drained")

    # Close the second -> nothing left active.
    p2.close
    drain_idle
    assert(!PopupFormGenerator.popup_active?, "no popup should remain active")
  ensure
    PopupFormGenerator.reset_popup_queue
  end

  def test_single_popup_shows_immediately
    PopupFormGenerator.reset_popup_queue
    p1 = PopupFormGenerator.new(popup_params)
    p1.run
    assert(PopupFormGenerator.popup_active?)
    assert_eq(0, PopupFormGenerator.popup_queue_size)
    p1.close
    drain_idle
    assert(!PopupFormGenerator.popup_active?)
  ensure
    PopupFormGenerator.reset_popup_queue
  end
end
