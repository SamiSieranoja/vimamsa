class TestDictation < VmaTest
  def load_dictation
    load ppath("modules/dictation/dictation_info.rb")
    load ppath("modules/dictation/dictation.rb")
  end

  def ensure_disabled
    dictation_disable if vma.actions.include?(:dictation_toggle)
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
    assert vma.actions.include?(:dictation_toggle),        "action not registered after init"
    assert vma.gui.menu.module_action?(:dictation_toggle),  "menu item missing after init"
  ensure
    dictation_disable
  end

  def test_disable_unregisters
    ensure_disabled
    load_dictation
    dictation_init
    dictation_disable
    assert !vma.actions.include?(:dictation_toggle),       "action still registered after disable"
    assert !vma.gui.menu.module_action?(:dictation_toggle), "menu item still present after disable"
  end

  def test_init_disable_cycle
    ensure_disabled
    load_dictation
    3.times do |i|
      dictation_init
      assert vma.actions.include?(:dictation_toggle),       "action missing after init (cycle #{i})"
      dictation_disable
      assert !vma.actions.include?(:dictation_toggle),      "action present after disable (cycle #{i})"
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
    assert res[:error].to_s.include?("not loaded"), "unexpected error: #{res[:error].inspect}"
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
    [:dictation_enter_mode, :dictation_toggle_stay,
     :dictation_newline, :dictation_exit_mode].each do |a|
      assert vma.actions.include?(a), "#{a} not registered after init"
    end
    dictation_disable
    [:dictation_enter_mode, :dictation_toggle_stay,
     :dictation_newline, :dictation_exit_mode].each do |a|
      assert !vma.actions.include?(a), "#{a} still registered after disable"
    end
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
    act(:dictation_newline)
    assert_buf "abc\n\n", "Enter should insert a newline when not dictating"
  ensure
    dictation_disable
  end
end
