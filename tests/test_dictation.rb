class TestDictation < VmaTest
  def load_dictation
    load ppath("modules/dictation/dictation_info.rb")
    load ppath("modules/dictation/dictation.rb")
  end

  def ensure_disabled
    dictation_disable if vma.actions.include?("dictation.toggle")
  end

  # --- _info ---

  def test_info_structure
    load ppath("modules/dictation/dictation_info.rb")
    info = dictation_info
    assert info[:name].is_a?(String) && !info[:name].empty?, "name should be a non-empty String"
    assert_eq true, info[:no_restart], "dictation should be no_restart"
  end

  # --- init / disable contract ---

  def test_init_registers_action_and_menu
    ensure_disabled
    load_dictation
    dictation_init
    assert vma.actions.include?("dictation.toggle"),        "action not registered after init"
    assert vma.gui.menu.module_action?("dictation.enter_mode"), "menu item missing after init"
  ensure
    dictation_disable
  end

  # "Start/Stop Dictation" runs the `, k` action, so its menu label shows the key
  def test_menu_item_shows_key_binding
    ensure_disabled
    load_dictation
    dictation_init
    hint = vma.gui.menu.kbd_hint("dictation.enter_mode")
    assert hint.include?("[C]</span> , k"), "no , k hint: #{hint.inspect}"
  ensure
    dictation_disable
  end

  def test_disable_unregisters
    ensure_disabled
    load_dictation
    dictation_init
    dictation_disable
    assert !vma.actions.include?("dictation.toggle"),       "action still registered after disable"
    assert !vma.gui.menu.module_action?("dictation.enter_mode"), "menu item still present after disable"
    assert !vma.actions.include?("dictation.review_toggle"), "review action still registered after disable"
    assert !vma.gui.menu.module_action?("dictation.review_enter"), "review menu item still present after disable"
    assert !$vma_dict_review_hooks_on, "review listeners still active after disable"
  end

  def test_init_disable_cycle
    ensure_disabled
    load_dictation
    3.times do |i|
      dictation_init
      assert vma.actions.include?("dictation.toggle"),       "action missing after init (cycle #{i})"
      dictation_disable
      assert !vma.actions.include?("dictation.toggle"),      "action present after disable (cycle #{i})"
    end
  end

  # --- WAV header finalization (the one piece of nontrivial logic) ---

  def test_wav_header_fix
    load_dictation

    # Build a WAV with placeholder size fields (as wavenc leaves them without EOS).
    samples = "\x00\x00" * 8000   # 8000 frames of S16LE mono silence
    fmt = ["fmt ", 16, 1, 1, 16000, 32000, 2, 16].pack("a4VvvVVvv")
    data_chunk = "data" + [0x7FFF0000].pack("V") + samples
    riff = "RIFF" + [0x7FFF0024].pack("V") + "WAVE" + fmt + data_chunk

    path = File.join(Dir.tmpdir, "vma_dictation_test_#{Process.pid}.wav")
    File.binwrite(path, riff)

    vma_wav_fix_header!(path)

    fixed = File.binread(path)
    riff_sz = fixed[4, 4].unpack1("V")
    data_sz = fixed[44 - 4, 4].unpack1("V")
    assert_eq fixed.bytesize - 8,  riff_sz, "RIFF size not finalized"
    assert_eq fixed.bytesize - 44, data_sz, "data size not finalized"
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  # PCM tail-slicing: a WAV written by vma_write_wav can be located and split into
  # PCM halves that recombine to the original — the basis of the incremental pass.
  def test_pcm_tail_slice
    load_dictation
    pcm = (0...4000).map { |i| (i % 256) - 128 }.pack("s<*")  # 2000 frames S16LE
    path = File.join(Dir.tmpdir, "vma_dict_slice_#{Process.pid}.wav")
    vma_write_wav(path, pcm)

    bytes = File.binread(path)
    doff = vma_wav_data_offset(bytes)
    assert !doff.nil?, "data offset not found"
    assert_eq pcm.bytesize, bytes.bytesize - doff, "data size mismatch"

    half = doff + (pcm.bytesize / 2 / DICT_FRAME) * DICT_FRAME
    a = bytes[doff...half]
    b = bytes[half...bytes.bytesize]
    assert_eq pcm, a + b, "sliced PCM does not recombine to original"
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  # --- status indicator ---

  # The generic status slot the module drives: set, replace, and clear.
  def test_status_indicator_slot
    vma.gui.set_status_indicator(:_test_slot, "WORKING…", css_class: "status-busy")
    assert_eq "WORKING…", vma.gui.status_indicator(:_test_slot)

    vma.gui.set_status_indicator(:_test_slot, "DONE", css_class: "status-active")
    assert_eq "DONE", vma.gui.status_indicator(:_test_slot)

    vma.gui.set_status_indicator(:_test_slot, nil)
    assert_eq nil, vma.gui.status_indicator(:_test_slot), "slot should be gone once cleared"
  ensure
    vma.gui.set_status_indicator(:_test_slot, nil)
  end

  # Every phase must map to text, or the user gets a blank badge mid-dictation.
  def test_status_phases_all_have_text
    load_dictation
    %i[loading listening transcribing failed].each do |phase|
      text, css = VmaDictationSession::STATUS_PHASES[phase]
      assert !text.to_s.empty?, "phase #{phase} has no text"
      assert !css.to_s.empty?, "phase #{phase} has no css class"
    end
  end

  # --- model selection ---

  # Applying a preset must set the language too: a Finnish model left on "en"
  # transcribes badly and nothing in the UI would show the mismatch.
  def test_apply_model_sets_model_and_language
    load_dictation
    prev_model = cnf.dictation.model!
    prev_lang = cnf.dictation.language!

    vma_dict_apply_model("Finnish-NLP/whisper-large-finnish-v3-ct2", "fi")
    assert_eq "Finnish-NLP/whisper-large-finnish-v3-ct2", cnf.dictation.model!
    assert_eq "fi", cnf.dictation.language!
  ensure
    cnf.dictation.model = prev_model
    cnf.dictation.language = prev_lang
  end

  # A blank id must not wipe the current model.
  def test_apply_model_ignores_blank
    load_dictation
    cnf.dictation.model = "large-v3"
    vma_dict_apply_model("   ", "fi")
    assert_eq "large-v3", cnf.dictation.model!, "blank model id should be ignored"
  end

  # The Finnish model the presets are built around must be offered, with "fi".
  def test_model_presets_include_finnish
    load_dictation
    entry = VMA_DICT_MODELS.find { |id, _l, _lang| id == "Finnish-NLP/whisper-large-finnish-v3-ct2" }
    assert !entry.nil?, "Finnish large-v3 preset missing"
    assert_eq "fi", entry[2], "Finnish preset should select the fi language"
  end

  # --- cold start (model not loaded yet) ---

  # A worker that hasn't loaded its model reports itself not ready, so the
  # preliminary passes skip themselves instead of queueing on the worker mutex
  # and stalling the final pass behind the load.
  def test_worker_not_ready_before_model_loads
    load_dictation
    w = VmaWhisperWorker.new
    assert_eq false, w.ready?, "a freshly built worker should not claim to be ready"
  end

  # A worker that never becomes ready must fail the request rather than block
  # forever: an unbounded wait leaves every later request stuck behind it with
  # the editor sitting on "finalizing…" and nothing to report.
  def test_await_ready_gives_up_instead_of_hanging
    load_dictation
    prev = cnf.dictation.startup_timeout!
    cnf.dictation.startup_timeout = 1

    r, wr = IO.pipe          # nothing is ever written -> never becomes ready
    blocked = Thread.new { sleep 30 }
    w = VmaWhisperWorker.new
    w.instance_variable_set(:@stdout, r)
    w.instance_variable_set(:@stdin, wr)
    w.instance_variable_set(:@wait, blocked)   # looks alive, so no respawn

    t0 = Time.now
    res = w.transcribe("/nonexistent.wav")
    elapsed = Time.now - t0

    assert_eq false, res[:ok], "transcribe should fail when the model never loads"
    assert res[:error].to_s.include?("no progress"), "unexpected error: #{res[:error].inspect}"
    assert elapsed < 10, "transcribe blocked #{elapsed.round(1)}s; should give up after the timeout"
  ensure
    cnf.dictation.startup_timeout = prev
    blocked&.kill
    r&.close
    wr&.close
  end

  # The span-replace approach: insert preliminary chunks into a buffer, then
  # delete the whole tracked span and insert the final text in its place.
  def test_span_replace
    load_dictation
    start = 0  # fresh test buffer is "\n"; dictate at the beginning

    # Simulate preliminary inserts, tracking the span length.
    len = 0
    ["hello", "there", "world"].each do |chunk|
      t = (len > 0 ? " " : "") + chunk
      act("buf.insert_txt_at(#{t.inspect}, #{start + len})")
      len += t.size
    end
    assert_buf "hello there world\n", "preliminary text not assembled"

    # Replace the whole span with the final transcript.
    act("buf.delete_range(#{start}, #{start + len - 1})")
    act("buf.insert_txt_at('Hello, there, world.', #{start})")
    assert_buf "Hello, there, world.\n", "final replacement incorrect"
  end

  # --- dictation keyboard mode (no microphone / recorder involved) ---

  def test_mode_actions_registered
    ensure_disabled
    load_dictation
    dictation_init
    ["dictation.enter_mode", "dictation.toggle_stay",
     "dictation.newline", "dictation.exit_mode"].each do |a|
      assert vma.actions.include?(a), "#{a} not registered after init"
    end
    dictation_disable
    ["dictation.enter_mode", "dictation.toggle_stay",
     "dictation.newline", "dictation.exit_mode"].each do |a|
      assert !vma.actions.include?(a), "#{a} still registered after disable"
    end
  end

  # The menu item runs "dictation.enter_mode"; clicked while already in the
  # mode it leaves the mode instead (session not active: no recorder starts).
  def test_enter_mode_action_exits_when_in_mode
    ensure_disabled
    load_dictation
    dictation_init
    vma.kbd.set_mode(:dictation)
    assert_eq :dictation, vma.kbd.get_mode
    act("dictation.enter_mode")
    assert_eq :command, vma.kbd.get_mode, "menu toggle did not leave dictation mode"
  ensure
    vma.kbd.set_mode(:command)
    dictation_disable
  end

  # `, , k` enters dictation mode without starting a recording.
  def test_enter_mode_idle
    ensure_disabled
    load_dictation
    dictation_init
    vma.kbd.set_mode(:command)
    keys(", , k")
    assert_mode :dictation
    assert !dictation_session.active?, ", , k should not start listening"
    keys("esc")
    assert_mode :command
  ensure
    vma.kbd.set_mode(:command)
    dictation_disable
  end

  # The mode is a minor mode that inherits command mode, and exiting returns to
  # the previous mode. Drive the mode machinery directly so no recorder starts.
  def test_mode_enter_inherits_and_exit
    ensure_disabled
    load_dictation
    dictation_init
    vma.kbd.set_mode(:command)
    vma.kbd.set_mode(:dictation)
    assert_eq :dictation, vma.kbd.get_mode, "did not enter dictation mode"
    assert vma.kbd.mode_root_state.major_modes.include?(:command),
           "dictation mode should inherit command mode"
    # Session is inactive, so exit is just a mode pop back to command.
    assert !dictation_session.active?, "no dictation should be active in this test"
    dictation_exit_mode
    assert_eq :command, vma.kbd.get_mode, "did not return to command mode on exit"
  ensure
    vma.kbd.set_mode(:command)
    dictation_disable
  end

  # Enter with no active dictation just inserts a newline at the cursor.
  def test_newline_when_inactive_inserts_newline
    ensure_disabled
    load_dictation
    dictation_init
    act("buf.insert_txt_at('abc', 0)")  # fresh buffer "\n" -> "abc\n"
    act("buf.set_pos(3)")               # end of "abc", before the trailing "\n"
    assert !dictation_session.active?, "precondition: no active dictation"
    act("dictation.newline")
    assert_buf "abc\n\n", "Enter should insert a newline when not dictating"
  ensure
    dictation_disable
  end

  # --- code review mode ---

  # Stands in for VmaDictationSession: no microphone, no worker. The test plays
  # the final pass by calling sink.finish itself.
  class FakeReviewSession
    attr_reader :sink, :stopped
    def initialize(sink:)
      @sink = sink
      @active = false
      $fake_review_sessions << self
    end

    def start(_prompt)
      @active = true
      @sink.begin(self)
      true
    end

    def active?; @active; end
    def finalizing?; false; end

    def stop(add_newline: true, restart: false, discard: false)
      @active = false
      @stopped = discard ? :discard : :final
    end
  end

  def set_lang(id)
    lang = GtkSource::LanguageManager.default.get_language(id)
    vma.buf.instance_variable_set(:@lang_nfo, lang)
    vma.buf.instance_variable_set(:@lang, id)
  end

  def set_text(t)
    act("buf.insert_txt_at(#{t.inspect}, 0)")   # fresh buffer "\n"
    act("buf.delete_range(buf.size - 1, buf.size - 1)") if t.end_with?("\n")
  end

  def with_review
    ensure_disabled
    load_dictation
    dictation_init
    $fake_review_sessions = []
    $vma_dict_review_session_class = FakeReviewSession
    yield
  ensure
    $vma_dict_review_session_class = nil
    vma.buf.end_visual_mode if vma.kbd.get_mode == :visual
    vma.kbd.set_mode(:command)
    dictation_disable
  end

  def test_review_comment_ruby_keeps_indent
    load_dictation
    set_text("def foo\n  bar\nend\n")
    set_lang("ruby")
    dictation_insert_review_comment(vma.buf, 10, "check this")
    assert_buf "def foo\n  # COMMENT: check this\n  bar\nend\n"
  end

  def test_review_comment_c
    load_dictation
    set_text("int x;\n")
    set_lang("c")
    dictation_insert_review_comment(vma.buf, 2, "why int")
    assert_buf "// COMMENT: why int\nint x;\n"
  end

  def test_review_comment_html_block
    load_dictation
    set_text("<p>hi</p>\n")
    set_lang("html")
    dictation_insert_review_comment(vma.buf, 0, "use a heading")
    assert_buf "<!-- COMMENT: use a heading -->\n<p>hi</p>\n"
  end

  def test_review_comment_wraps_and_aligns
    load_dictation
    lines = dictation_review_comment_lines("aaaa bbbb cccc dddd eeee ffff gggg hhhh",
                                           indent: "  ", com: "#", wrap: 32)
    assert_eq ["  # COMMENT: aaaa bbbb cccc dddd\n",
               "  #          eeee ffff gggg hhhh\n"], lines
    assert lines.all? { |l| l.chomp.size <= 32 }, "a line is wider than the wrap: #{lines.inspect}"
  end

  def test_review_comment_one_undo
    load_dictation
    set_text("def foo\n  bar\nend\n")
    set_lang("ruby")
    before = vma.buf.to_s
    dictation_insert_review_comment(vma.buf, 10, "one two three " * 20)
    assert vma.buf.to_s.lines.size > 5, "long comment should wrap onto several lines"
    vma.buf.undo
    assert_buf before, "one undo should remove the whole comment"
  end

  # The code moved while transcribing: the comment still goes above it.
  def test_review_locate_moved_line
    load_dictation
    set_text("a\nb\ntarget\nc\n")
    assert_eq 4, dictation_review_locate(vma.buf, 2, "target")
    act("buf.insert_txt_at(\"x\\ny\\n\", 0)")
    assert_eq 8, dictation_review_locate(vma.buf, 2, "target")
    assert_eq nil, dictation_review_locate(vma.buf, 2, "gone")
  end

  def test_review_lifecycle_keyboard
    with_review do
      set_text("def foo\n  bar\nend\n")
      set_lang("ruby")
      act("buf.set_pos(10)")
      vma.kbd.set_mode(:dictation)
      keys("c")
      assert dictation_review?, "c should turn review mode on"
      keys("v")
      assert_eq 1, $fake_review_sessions.size, "v should start a review recording"
      s = $fake_review_sessions[0]
      assert s.active?, "recording should be running while the selection is up"
      keys("l l esc")
      assert_mode :dictation
      assert_eq :final, s.stopped, "esc should stop and transcribe"
      assert_eq 10..12, s.sink.range
      s.sink.finish("check this")
      assert_buf "def foo\n  # COMMENT (next line): check this\n  bar\nend\n"
      assert_eq [], $vma_dict_review_sessions, "finished session should be dropped"
    end
  end

  # The comment says how many lines it is about.
  def test_review_comment_says_range
    with_review do
      set_text("def foo\n  bar\nend\n")
      set_lang("ruby")
      act("buf.set_pos(0)")
      vma.kbd.set_mode(:dictation)
      dictation_review_on
      keys("v j j esc")
      s = $fake_review_sessions[0]
      s.sink.finish("whole method")
      assert_buf "# COMMENT (next 3 lines): whole method\ndef foo\n  bar\nend\n"
    end
  end

  def test_review_prefix
    load_dictation
    assert_eq "COMMENT (next line):", dictation_review_prefix(1)
    assert_eq "COMMENT (next 4 lines):", dictation_review_prefix(4)
    assert_eq "COMMENT:", dictation_review_prefix(nil)
    prev = cnf.dictation.review_range!
    cnf.dictation.review_range = false
    assert_eq "COMMENT:", dictation_review_prefix(4), "review_range = false: no range"
  ensure
    cnf.dictation.review_range = prev
  end

  def test_review_edited_selection_discarded
    with_review do
      set_text("def foo\n  bar\nend\n")
      set_lang("ruby")
      act("buf.set_pos(10)")
      vma.kbd.set_mode(:dictation)
      dictation_review_on
      keys("v l d")
      s = $fake_review_sessions[0]
      assert !s.nil?, "no recording started"
      assert_eq :discard, s.stopped, "an edited selection should throw the recording away"
      assert !vma.buf.to_s.include?("COMMENT"), "no comment should be added"
    end
  end

  def test_review_yank_keeps_comment
    with_review do
      set_text("abc\n")
      vma.kbd.set_mode(:dictation)
      dictation_review_on
      keys("v l y")
      s = $fake_review_sessions[0]
      assert_eq :final, s.stopped, "yank doesn't edit, the comment should still be added"
    end
  end

  # Mouse selections go through the same visual mode path.
  def test_review_lifecycle_mouse
    with_review do
      set_text("abc def\n")
      vma.kbd.set_mode(:dictation)
      dictation_review_on
      b = vma.buf
      b.set_pos(4)
      b.start_selection
      vma.kbd.set_mode(:visual)
      b.set_pos(6)
      b.end_visual_mode
      s = $fake_review_sessions[0]
      assert !s.nil?, "mouse selection should start a recording"
      assert_eq :final, s.stopped
      assert_eq 4..6, s.sink.range
      assert_mode :dictation
    end
  end

  def test_review_off_records_nothing
    with_review do
      set_text("abc\n")
      vma.kbd.set_mode(:dictation)
      keys("v l esc")
      assert_eq 0, $fake_review_sessions.size, "review off: no recording"
      keys("c c")
      assert !dictation_review?, "c twice should leave review off"
      keys("v l esc")
      assert_eq 0, $fake_review_sessions.size, "review toggled off: no recording"
    end
  end

  def test_review_exit_mode_turns_off
    with_review do
      act("dictation.review_enter")
      assert_mode :dictation
      assert dictation_review?, ", ; r should turn review on"
      keys("esc")
      assert_mode :command
      assert !dictation_review?, "leaving dictation mode should turn review off"
      keys("v l esc")
      assert_eq 0, $fake_review_sessions.size, "command mode selection should not record"
    end
  end

  # A comment landing while the next selection is up must not count as the user
  # editing that selection, and the selection stays on its text.
  def test_review_comment_during_next_selection
    with_review do
      set_text("aa\nbb\n")
      vma.kbd.set_mode(:dictation)
      dictation_review_on
      act("buf.set_pos(0)")
      keys("v l esc")
      first = $fake_review_sessions[0]
      act("buf.set_pos(3)")
      keys("v l")
      first.sink.finish("note")
      assert_buf "# COMMENT (next line): note\naa\nbb\n".sub("#", vma.buf.get_com_str)
      keys("esc")
      second = $fake_review_sessions[1]
      assert_eq :final, second.stopped, "own comment insert should not discard the next one"
      assert_eq "bb", second.sink.code
    end
  end
end
