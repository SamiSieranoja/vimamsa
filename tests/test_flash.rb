# Gui.flash_range visualises the yanked/deleted range with a brief highlight,
# deferring the delete via a GLib timeout. That deferral must NOT happen during
# macro playback — it reorders the delete relative to the rest of the macro and
# breaks it. This test verifies the macro guard forces the synchronous path.
#
# Flashing is normally inactive under --test, so the test temporarily removes
# that guard to exercise the real active-decision.

class TestFlash < VmaTest
  def test_flash_synchronous_during_macro
    act('buf.insert_txt("AAAA\nBBBB\n")')
    # Need a real view for the deferred path to be reachable; otherwise the
    # synchronous fallback would fire regardless of the macro guard.
    skip("no GUI view in this environment") unless buf.view

    had_test = ARGV.delete("--test")
    cnf.flash.enabled = true
    begin
      ran = false
      vma.macro.instance_variable_set(:@running_macro, true)
      Gui.flash_range(buf, 0..1) { ran = true }
      assert(ran, "flash block must run synchronously while a macro is running")
    ensure
      vma.macro.instance_variable_set(:@running_macro, false)
      ARGV.push("--test") if had_test
    end
  end

  # Sanity: with no macro running (and --test removed), flashing defers the
  # block, so it has NOT run by the time flash_range returns — then fires after
  # the timeout. This proves the synchronous test above is not a false positive.
  def test_flash_defers_when_not_in_macro
    act('buf.insert_txt("AAAA\nBBBB\n")')
    skip("no GUI view in this environment") unless buf.view

    had_test  = ARGV.delete("--test")
    prev_dur  = cnf.flash.duration!
    cnf.flash.enabled = true
    cnf.flash.duration = 0.01 # keep the deferral short so the test is fast
    begin
      ran = false
      Gui.flash_range(buf, 0..1) { ran = true }
      assert(!ran, "flash block should be deferred (not yet run) outside a macro")
      # Let the timeout fire so the deferred cleanup completes (no leak into
      # later tests).
      deadline = Time.now + 2
      GLib::MainContext.default.iteration(true) while !ran && Time.now < deadline
      assert(ran, "deferred flash block should run after the timeout")
    ensure
      cnf.flash.duration = prev_dur
      ARGV.push("--test") if had_test
    end
  end

  # A key pressed while a delete is still flashing must see the delete
  # already done. Typing "d w j" faster than cnf.flash.duration used to run
  # j first; the deferred delete then snapped the cursor back to line 0
  # (and a macro recorded that way replayed from the wrong place).
  def test_key_during_flash_runs_pending_delete_first
    act('buf.insert_txt("  sdf sdfsdf\n  sdf sdfsdf\n  sdf sdfsdf")')
    skip("no GUI view in this environment") unless buf.view
    act :jump_to_start_of_buffer

    had_test = ARGV.delete("--test")
    prev_dur = cnf.flash.duration!
    cnf.flash.enabled = true
    cnf.flash.duration = 5 # long enough that it can't fire during the test
    begin
      keys "d w j"
      assert_buf "sdf sdfsdf\n  sdf sdfsdf\n  sdf sdfsdf\n"
      assert_pos 1, 0
    ensure
      Gui.flush_flash
      cnf.flash.duration = prev_dur
      ARGV.push("--test") if had_test
    end
  end
end
