
# Test that changing font size via settings applies to all open buffers,
# not just the one currently visible in the active window.
#
# gui_refresh_font iterates $vmag.windows (at most 2 visible panels), so
# background buffers whose views are not mounted in any window are at risk
# of being skipped.  This test creates several buffers, triggers a font
# refresh, then verifies that every buffer view received the CSS provider.

class TestFontRefreshAllBuffers < VmaTest

  def test_font_applied_to_all_buffer_views
    # Create extra buffers (setcurrent=false → they stay in the background)
    b2 = create_new_buffer("second buffer\n", "b2", false)
    b3 = create_new_buffer("third buffer\n",  "b3", false)
    drain_idle

    all_views = vma.gui.buffers.dup   # {buf_id => VSourceView}

    # Need at least 3 buffers (setup adds one, we added two more)
    assert all_views.size >= 3,
           "Expected >= 3 buffer views, got #{all_views.size}"

    # Intercept add_provider to record which view style-contexts are touched.
    # We prepend once; subsequent test runs also benefit from the tracking
    # because provider_received is replaced each time.
    provider_received = {}
    all_views.each_value { |v| provider_received[v.style_context.object_id] = false }

    orig = Gtk::StyleContext.instance_method(:add_provider)
    tracker = Module.new do
      define_method(:add_provider) do |prov|
        provider_received[object_id] = true if provider_received.key?(object_id)
        orig.bind(self).call(prov)
      end
    end
    Gtk::StyleContext.prepend(tracker)

    original_size = get(cnf.font.size)
    new_size = original_size + 4
    cnf.font.size = new_size
    gui_refresh_font
    drain_idle

    all_views.each do |buf_id, view|
      sc_id = view.style_context.object_id
      assert provider_received[sc_id],
             "Font CSS provider was NOT applied to buffer #{buf_id} (view id #{view.object_id})"
    end
  ensure
    # Restore original font size so other tests are not affected
    cnf.font.size = original_size if defined?(original_size) && original_size
    gui_refresh_font rescue nil
  end

end
