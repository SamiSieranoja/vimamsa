require "tmpdir"
require "fileutils"

# Covers Buffer#check_autosave_load's decision to prompt vs. silently drop an
# autosave file (.<name>_vma_autosave) when a file is opened:
#   - autosave identical to the file        -> deleted, no prompt
#   - autosave older than the file (stale)  -> deleted, no prompt  (the fix)
#   - autosave newer than the file          -> kept, prompt shown
#
# The prompt is a GTK popup; for the "newer" case we stub PopupFormGenerator#run
# so the test neither blocks nor leaves a window behind, and record whether it
# would have been shown.

class TestAutosave < VmaTest
  # Build a buffer backed by a real temp file, plus an autosave file next to it.
  # Returns [buffer, file_path, autosave_path]. Caller sets mtimes as needed.
  def make_backed_buffer(file_content, autosave_content)
    dir  = Dir.mktmpdir("vma_autosave_test")
    @tmpdirs << dir
    path = File.join(dir, "note.txt")
    File.write(path, file_content)
    b = create_new_buffer(file_content, "test", true)
    b.set_filename(path)
    apath = b.autosave_path
    File.write(apath, autosave_content)
    [b, path, apath]
  end

  def set_older(apath, path)
    now = Time.now
    File.utime(now - 100, now - 100, apath) # autosave older
    File.utime(now, now, path)              # file newer
  end

  def set_newer(apath, path)
    now = Time.now
    File.utime(now, now, apath)                 # autosave newer
    File.utime(now - 100, now - 100, path)      # file older
  end

  # Run block with PopupFormGenerator#run stubbed out; returns true if a popup
  # would have been shown.
  def popup_shown_during
    $vma_test_popup_shown = false
    orig = PopupFormGenerator.instance_method(:run)
    PopupFormGenerator.send(:define_method, :run) { |*_a| $vma_test_popup_shown = true; self }
    yield
    $vma_test_popup_shown
  ensure
    PopupFormGenerator.send(:define_method, :run, orig)
  end

  def setup_dirs
    @tmpdirs ||= []
  end

  def cleanup_dirs
    (@tmpdirs || []).each { |d| FileUtils.remove_entry(d, true) }
    @tmpdirs = []
  end

  def test_stale_autosave_deleted_silently
    setup_dirs
    b, path, apath = make_backed_buffer("current on disk\n", "stale autosave contents\n")
    set_older(apath, path)
    shown = popup_shown_during { b.check_autosave_load }
    assert(!File.exist?(apath), "stale autosave should be deleted")
    assert(!shown, "no prompt should be shown for a stale autosave")
  ensure
    cleanup_dirs
  end

  def test_identical_autosave_deleted_silently
    setup_dirs
    b, path, apath = make_backed_buffer("hello world\n", "hello world\n")
    # mtimes irrelevant here; identical content is dropped regardless.
    set_newer(apath, path)
    shown = popup_shown_during { b.check_autosave_load }
    assert(!File.exist?(apath), "autosave identical to file should be deleted")
    assert(!shown, "no prompt should be shown when autosave equals the file")
  ensure
    cleanup_dirs
  end

  def test_newer_autosave_kept_and_prompts
    setup_dirs
    b, path, apath = make_backed_buffer("saved version\n", "newer unsaved edits\n")
    set_newer(apath, path)
    shown = popup_shown_during { b.check_autosave_load }
    assert(File.exist?(apath), "a newer autosave must not be deleted")
    assert(shown, "a newer, differing autosave should prompt")
  ensure
    cleanup_dirs
  end

  # ── Deferred check for session-restored buffers ──────────────────────────
  # Session restore loads buffers without running check_autosave_load; the
  # check is deferred (needs_autosave_check) until the buffer is first entered
  # via set_current_buffer.

  # Enter another buffer, then switch (back) to `b` — the "enter buffer" path.
  def enter_buffer(b)
    create_new_buffer("\n", "decoy", true) # move current buffer away from b
    vma.buffers.set_current_buffer_by_id(b.id)
  end

  def test_restored_newer_autosave_prompts_on_enter
    setup_dirs
    b, path, apath = make_backed_buffer("saved version\n", "newer unsaved edits\n")
    set_newer(apath, path)
    b.needs_autosave_check = true
    shown = popup_shown_during { enter_buffer(b) }
    assert(shown, "restored buffer should prompt when first entered")
    assert(File.exist?(apath), "newer autosave must be kept")
    assert(!b.needs_autosave_check, "pending flag should be cleared after entering")
  ensure
    cleanup_dirs
  end

  def test_restored_stale_autosave_deleted_on_enter
    setup_dirs
    b, path, apath = make_backed_buffer("current on disk\n", "stale autosave\n")
    set_older(apath, path)
    b.needs_autosave_check = true
    shown = popup_shown_during { enter_buffer(b) }
    assert(!shown, "stale autosave should not prompt on enter")
    assert(!File.exist?(apath), "stale autosave should be deleted on enter")
    assert(!b.needs_autosave_check, "pending flag should be cleared after entering")
  ensure
    cleanup_dirs
  end

  def test_unflagged_buffer_not_checked_on_enter
    setup_dirs
    # No needs_autosave_check flag (a normal, non-restored buffer): entering it
    # must not run the autosave check, even with a newer differing autosave.
    b, path, apath = make_backed_buffer("saved version\n", "newer unsaved edits\n")
    set_newer(apath, path)
    shown = popup_shown_during { enter_buffer(b) }
    assert(!shown, "unflagged buffer must not prompt on enter")
    assert(File.exist?(apath), "unflagged buffer must not touch the autosave")
  ensure
    cleanup_dirs
  end
end
