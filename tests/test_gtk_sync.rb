
# Tests that the Ruby buffer and GTK SourceView buffer stay in sync.
#
# assert_gtk_sync compares vma.buf.to_s (Ruby) with view.buffer.text (GTK).
# Most tests also exercise assert_buf so both sides are checked explicitly.

class TestGtkSync < VmaTest

  # ── Helpers ─────────────────────────────────────────────────────────────────

  # Flush pending Ruby→GTK deltas in addition to GLib idle callbacks.
  # In the test harness key events are bypassed so handle_deltas is never
  # called from handle_key_event — we must call it explicitly.
  def drain_idle
    super
    vma.buf.view.handle_deltas if vma.buf&.view
  end

  def assert_gtk_sync(msg = nil)
    ruby_text = vma.buf.to_s
    gtk_text  = vma.buf.view.buffer.text
    return if ruby_text == gtk_text
    raise VmaTestFailure, (msg || "Ruby/GTK buffer mismatch\n" \
      "  ruby: #{ruby_text.inspect}\n" \
      "   gtk: #{gtk_text.inspect}")
  end

  # Insert text directly into the GTK buffer without going through key events,
  # simulating a Wayland IM commit (e.g. AltGr+q → ä).
  def im_commit(text)
    gtbuf = vma.buf.view.buffer
    iter  = gtbuf.get_iter_at(:offset => vma.buf.pos)
    gtbuf.insert(iter, text)
    drain_idle
  end

  # ── Basic editing ───────────────────────────────────────────────────────────

  def test_insert_syncs_gtk
    act 'buf.insert_txt("hello")'
    assert_buf "hello\n"
    assert_gtk_sync
  end

  def test_delete_syncs_gtk
    act 'buf.insert_txt("abcde")'
    act :jump_to_start_of_buffer
    act :delete_char_forward
    act :delete_char_forward
    assert_buf "cde\n"
    assert_gtk_sync
  end

  def test_undo_syncs_gtk
    act 'buf.insert_txt("hello")'
    act :undo
    assert_buf "\n"
    assert_gtk_sync
  end

  def test_newline_syncs_gtk
    act 'buf.insert_txt("first")'
    act 'buf.insert_txt("\n")'
    act 'buf.insert_txt("second")'
    assert_buf "first\nsecond\n"
    assert_gtk_sync
  end

  def test_key_sequence_syncs_gtk
    keys "i"
    "hello".each_char { |c| keys c }
    keys "esc"
    assert_buf "hello\n"
    assert_gtk_sync
  end

  def test_delete_line_syncs_gtk
    act 'buf.insert_txt("first\n")'
    act 'buf.insert_txt("second")'
    act :jump_to_start_of_buffer
    act :delete_line
    assert_buf "second\n"
    assert_gtk_sync
  end

  # ── Simulated Wayland IM commit ─────────────────────────────────────────────
  # Mimics the Wayland text-input protocol inserting a composed character
  # (e.g. AltGr+q → ä) directly into the GTK buffer, bypassing key events.
  # register_buffer_signals() must catch this via insert-text and mirror it
  # into the Ruby buffer.

  def test_im_commit_in_insert_mode
    vma.kbd.set_mode(:insert)
    drain_idle

    im_commit("ä")

    assert_buf "ä\n"
    assert_gtk_sync
  end

  def test_im_commit_mid_word
    act 'buf.insert_txt("ac")'
    act :jump_to_start_of_buffer
    act "buf.move(FORWARD_CHAR)"
    vma.kbd.set_mode(:insert)
    drain_idle

    im_commit("ö")

    assert_buf "aöc\n"
    assert_gtk_sync
  end

  def test_im_commit_not_in_insert_mode
    # In command mode the IM commit should be reverted from the GTK buffer.
    vma.kbd.set_mode(:command)
    drain_idle

    im_commit("ä")

    # Ruby buffer unchanged, GTK buffer reverted
    assert_buf "\n"
    assert_gtk_sync
  end
end
