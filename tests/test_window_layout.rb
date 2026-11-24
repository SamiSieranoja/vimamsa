require "tmpdir"

# Window geometry and view layout saved on shutdown and restored on startup
# (VMAgui#window_layout / fit_view_layout / apply_view_layout in gui.rb).
# Test runs never read or write the saved layout, so most of these call the
# pieces directly; test_restored_after_restart starts the real editor.
class TestWindowLayout < VmaTest
  OFF = { :shown => false }
  PLAIN = { :two_column => OFF, :file_panel => OFF, :func_panel => OFF, :keylog => OFF }

  def gui
    vma.gui
  end

  def with_layout(l)
    gui.apply_view_layout(l)
    drain_idle
    yield
  ensure
    gui.apply_view_layout(PLAIN)
    drain_idle
  end

  def shown(width = nil)
    { :shown => true, :width => width }
  end

  def view_parts(l)
    [:two_column, :file_panel, :func_panel].map { |k| [l[k][:shown], l[k][:width]] }
  end

  def test_round_trip_columns_and_panels
    l = PLAIN.merge(:two_column => shown(300), :file_panel => shown(150), :func_panel => shown(140))
    with_layout(l) {
      got = gui.window_layout
      assert_eq [[true, 300], [true, 150], [true, 140]], view_parts(got)
      # Applying the layout it reports changes nothing
      gui.apply_view_layout(got)
      drain_idle
      assert_eq view_parts(got), view_parts(gui.window_layout)
    }
    got = gui.window_layout
    assert_eq [false, false, false], view_parts(got).map(&:first)
  end

  def test_widths_kept_when_panel_is_toggled
    with_layout(PLAIN.merge(:file_panel => shown(210))) {
      gui.hide_file_panel
      gui.show_file_panel
      drain_idle
      assert_eq 210, gui.window_layout[:file_panel][:width]
    }
  end

  def test_minibuffer_history_height_kept
    old = gui.instance_variable_get(:@minibuf_history_height)
    gui.apply_view_layout(PLAIN.merge(:minibuf_history_height => 222))
    assert_eq 222, gui.window_layout[:minibuf_history_height]
  ensure
    gui.instance_variable_set(:@minibuf_history_height, old)
  end

  def test_editor_works_after_restoring_layout
    with_layout(PLAIN.merge(:two_column => shown, :file_panel => shown)) {
      vma.buf.set_content("\n")
      keys("i a b c esc")
      assert_buf "abc\n"
    }
    vma.buf.set_pos(0)
    keys("i x esc")
    assert_buf "xabc\n"
  end

  def test_second_column_gets_its_file_back
    Dir.mktmpdir { |dir|
      path = "#{dir}/col2.txt"
      File.write(path, "second\n")
      main = vma.buf
      b = open_new_file(path)
      vma.buffers.set_current_buffer(main.id)
      drain_idle
      begin
        with_layout(PLAIN.merge(:two_column => shown, :column2_file => path)) {
          view = gui.instance_variable_get(:@windows)[2][:sw].child
          assert_eq path, view.bufo.fname
          assert_eq path, gui.window_layout[:column2_file]
        }
      ensure
        vma.buffers.close_buffer(b.id)
      end
    }
  end

  # ── fit_view_layout / pick_layout with fake monitor sizes ──

  SAVED = { :width => 1800, :height => 1100, :maximized => true, :win_width => 1920,
            :file_panel => { :shown => true, :width => 480, :frac => 0.25 },
            :func_panel => { :shown => true, :width => 192, :frac => 0.1 },
            :keylog => { :shown => false },
            :two_column => { :shown => true, :width => 600, :frac => 0.3125 } }

  def test_same_resolution_keeps_pixels
    l = gui.fit_view_layout(SAVED, 1920, 1200, true)
    assert_eq [1800, 1100, true], l.values_at(:width, :height, :maximized)
    assert_eq [[true, 600], [true, 480], [true, 192]], view_parts(l)
  end

  def test_smaller_screen_clamps_and_scales
    l = gui.fit_view_layout(SAVED, 1280, 800, false)
    assert_eq [1152, 720], l.values_at(:width, :height)    # 90% of the monitor
    assert_eq false, l[:maximized]                          # saved window didn't fit
    assert_eq [[true, 360], [true, 288], [true, 115]], view_parts(l) # fractions of 1152
  end

  def test_editor_keeps_minimum_width
    narrow = SAVED.merge(:file_panel => { :shown => true, :width => 480, :frac => 0.5 },
                         :func_panel => { :shown => true, :width => 300, :frac => 0.3 })
    l = gui.fit_view_layout(narrow, 1000, 700, false)       # window 900 wide
    assert_eq 900, l[:width]
    assert_eq [true, 450], [l[:file_panel][:shown], l[:file_panel][:width]]
    assert_eq false, l[:func_panel][:shown], "func panel should be hidden, not squeeze the editor"
    assert 900 - 450 >= VMAgui::EDITOR_MIN_WIDTH
  end

  def test_first_start_default_size
    l = gui.fit_view_layout({}, 1920, 1080, true)
    assert_eq [1000, 800, false], l.values_at(:width, :height, :maximized)
    assert_eq [false, false, false], view_parts(l).map(&:first)
    # Small screen: 90% of it, but at least the 600 px minimum
    assert_eq [921, 691], gui.fit_view_layout({}, 1024, 768, true).values_at(:width, :height)
    assert_eq [720, 600], gui.fit_view_layout({}, 800, 600, true).values_at(:width, :height)
  end

  def test_pick_prefers_layout_of_this_resolution
    all = { "1920x1200@1" => SAVED.merge(:used => 1.0),
            "1280x800@1" => SAVED.merge(:width => 1000, :maximized => false, :used => 0.5) }
    assert_eq 1000, gui.pick_layout(all, "1280x800@1", 1280, 800)[:width]
    # Unknown resolution: the most recent layout, fitted
    l = gui.pick_layout(all, "3840x2160@2", 1920, 1080)
    assert_eq [1728, 972], l.values_at(:width, :height)
  end

  def test_keeps_most_recent_layouts
    all = {}
    7.times { |i| all = gui.merge_layouts(all, "#{i}x1@1", { :width => i }, i.to_f) }
    assert_eq VMAgui::LAYOUT_KEEP, all.size
    assert_eq %w[6x1@1 5x1@1 4x1@1 3x1@1 2x1@1], all.keys
  end

  def test_not_saved_in_test_mode
    gui.save_window_layout
    assert !File.exist?(get_data_path(VMAgui::LAYOUT_FILE)), "test run wrote the layout"
  end

  # ── Real startups ──

  # Start the real editor (not in test mode) with config dir ud and wait for
  # it to quit on its own (its custom.rb calls vma.shutdown).
  def run_editor(ud)
    exe = File.expand_path("../exe/vimamsa", __dir__)
    pid = Process.spawn(*vma_editor_command(exe), "--user-dir", ud, out: File::NULL, err: "#{ud}/log.txt")
    t = Time.now
    while Process.waitpid(pid, Process::WNOHANG).nil?
      if Time.now - t > 60
        Process.kill("KILL", pid)
        Process.wait(pid)
        raise VmaTestFailure, "editor did not quit (log: #{ud}/log.txt)"
      end
      sleep 0.2
    end
  end

  # Two real startups with a throwaway config dir (data goes there too). The
  # first starts with the default size, maximizes, shows two columns and the
  # file panel, and quits; the second reports what it restored.
  def test_restored_after_restart
    skip "needs a window manager to maximize (--headless has none)" if ENV["VMA_HEADLESS"]
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    Dir.mktmpdir { |dir|
      ud = "#{dir}/ud"
      Dir.mkdir(ud)
      File.write("#{ud}/custom.rb", <<~RUBY)
        def hook_custom_after_init
          GLib::Timeout.add(3000) {
            n = File.exist?(#{"#{dir}/run1".inspect}) ? 2 : 1
            File.binwrite(#{dir.inspect} + "/run\#{n}", Marshal.dump(vma.gui.window_layout))
            if n == 1
              vma.gui.window.maximize
              vma.gui.toggle_two_column
              vma.gui.toggle_file_panel
              # Like dragging the divider: once the new pane is laid out
              GLib::Timeout.add(800) { vma.gui.instance_variable_get(:@file_panel_pane).set_position(222); false }
            end
            GLib::Timeout.add(2000) { vma.shutdown; false }
            false
          }
        end
      RUBY
      mw, mh = gui.monitor_size(gui.layout_monitor)
      want = gui.fit_view_layout({}, mw, mh, true)

      run_editor(ud)
      first = Marshal.load(File.binread("#{dir}/run1"))
      # The window manager may shrink it to the usable area (e.g. GNOME's top bar)
      w, h = first.values_at(:width, :height)
      assert w <= want[:width] && h <= want[:height] && w >= 600 && h >= 500,
             "first start: #{[w, h]}, default #{want.values_at(:width, :height)}"
      # (GNOME may also maximize it on a small screen, e.g. the VM's 1024x768)
      assert_eq false, first[:two_column][:shown], "first start: #{first.inspect}, monitor #{[mw, mh]}"
      assert File.exist?("#{ud}/#{VMAgui::LAYOUT_FILE}"), "layout not saved"

      run_editor(ud)
      second = Marshal.load(File.binread("#{dir}/run2"))
      assert_eq true, second[:maximized]
      assert_eq [w, h], second.values_at(:width, :height)
      assert_eq [true, true, 222], [second[:two_column][:shown], second[:file_panel][:shown], second[:file_panel][:width]],
                "second start: #{second.inspect}\nsaved: #{Marshal.load(File.binread("#{ud}/#{VMAgui::LAYOUT_FILE}")).inspect}"
    }
  end

  # custom.rb for a real startup: after 3 s, run the Ruby code in steps (a
  # list of [delay ms, code] run one after another), then write the window
  # layout to dir/name and quit
  def layout_custom_rb(dir, name, steps = [])
    chain = steps.reverse.inject("File.binwrite(#{"#{dir}/#{name}".inspect}, Marshal.dump(vma.gui.window_layout))\n" \
                                 "GLib::Timeout.add(1000) { vma.shutdown; false }") { |inner, (ms, code)|
      "#{code}\nGLib::Timeout.add(#{ms}) {\n#{inner}\nfalse }"
    }
    "def hook_custom_after_init\n  GLib::Timeout.add(3000) {\n#{chain}\nfalse }\nend\n"
  end

  # Maximize (full display), then make the window somewhat narrower, keeping
  # the full height (like dragging its side edge), and quit: the next starts
  # get that size back, not the maximized one, and starting and quitting
  # doesn't change it.
  def test_resized_after_maximize_restored
    skip "needs a window manager to maximize (--headless has none)" if ENV["VMA_HEADLESS"]
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    Dir.mktmpdir { |dir|
      ud = "#{dir}/ud"
      Dir.mkdir(ud)
      mw, mh = gui.monitor_size(gui.layout_monitor)
      # Each step waits (up to 8 s) for the window manager to really
      # maximize or unmaximize: with animations, or on a busy machine, that
      # can take a while
      File.write("#{ud}/custom.rb", <<~RUBY)
        def hook_custom_after_init
          win = vma.gui.window
          save = ->(name) { File.binwrite(#{dir.inspect} + "/" + name, Marshal.dump(vma.gui.window_layout)) }
          wait = ->(cond, done) {
            t0 = Time.now
            GLib::Timeout.add(100) { (cond.() || Time.now - t0 > 8) ? (done.(); false) : true }
          }
          GLib::Timeout.add(3000) {
            win.maximize
            wait.(-> { win.maximized? }, -> {
              GLib::Timeout.add(500) { # let the maximized size settle
                save.("max")
                w, h = win.width, win.height
                win.unmaximize
                wait.(-> { !win.maximized? }, -> {
                  win.set_default_size((w * 0.85).to_i, h)
                  GLib::Timeout.add(1500) {
                    save.("run1")
                    GLib::Timeout.add(1000) { vma.shutdown; false }
                    false
                  }
                })
                false
              }
            })
            false
          }
        end
      RUBY
      run_editor(ud)
      max = Marshal.load(File.binread("#{dir}/max"))
      assert_eq true, max[:maximized], "the window manager didn't maximize the window within 8 s: #{max.inspect}"
      maxw = max[:win_width]
      first = Marshal.load(File.binread("#{dir}/run1"))
      assert_eq false, first[:maximized], "still maximized after unmaximize: #{first.inspect}"
      fw, fh = first.values_at(:width, :height)
      w = (maxw * 0.85).to_i
      # The window manager may adjust it a little, but it must be narrower
      # than the maximized window
      assert fw < maxw && (fw - w).abs <= 50, "resized width #{fw}, asked #{w}, maximized #{maxw}, monitor #{mw}x#{mh}"

      File.write("#{ud}/custom.rb", layout_custom_rb(dir, "run2"))
      run_editor(ud)
      second = Marshal.load(File.binread("#{dir}/run2"))
      saved = Marshal.load(File.binread("#{ud}/#{VMAgui::LAYOUT_FILE}")).inspect
      assert_eq [false, fw, fh], second.values_at(:maximized, :width, :height),
                "second start: #{second.inspect}\nsaved: #{saved}"

      File.write("#{ud}/custom.rb", layout_custom_rb(dir, "run3"))
      run_editor(ud)
      third = Marshal.load(File.binread("#{dir}/run3"))
      assert_eq [false, fw, fh], third.values_at(:maximized, :width, :height),
                "third start (after a plain start and stop): #{third.inspect}"
    }
  end
end
