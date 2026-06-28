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
    rec = VmaDictationRecorder.new

    # Build a WAV with placeholder size fields (as wavenc leaves them without EOS).
    samples = "\x00\x00" * 8000   # 8000 frames of S16LE mono silence
    fmt = ["fmt ", 16, 1, 1, 16000, 32000, 2, 16].pack("a4VvvVVvv")
    data_chunk = "data" + [0x7FFF0000].pack("V") + samples
    riff = "RIFF" + [0x7FFF0024].pack("V") + "WAVE" + fmt + data_chunk

    path = File.join(Dir.tmpdir, "vma_dictation_test_#{Process.pid}.wav")
    File.binwrite(path, riff)

    rec.send(:fix_wav_header!, path)

    fixed = File.binread(path)
    riff_sz = fixed[4, 4].unpack1("V")
    data_sz = fixed[44 - 4, 4].unpack1("V")
    assert_eq fixed.bytesize - 8,  riff_sz, "RIFF size not finalized"
    assert_eq fixed.bytesize - 44, data_sz, "data size not finalized"
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
