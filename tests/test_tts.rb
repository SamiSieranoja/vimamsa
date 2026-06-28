class TestTts < VmaTest
  def load_tts
    load ppath("modules/tts/tts_info.rb")
    load ppath("modules/tts/tts.rb")
  end

  def ensure_disabled
    tts_disable if vma.actions.include?(:tts_speak_selection)
  end

  # --- _info ---

  def test_info_structure
    load ppath("modules/tts/tts_info.rb")
    info = tts_info
    assert info[:name].is_a?(String) && !info[:name].empty?, "name should be a non-empty String"
    assert_eq true, info[:no_restart], "tts should be no_restart"
  end

  # --- init / disable contract ---

  def test_init_registers_actions_and_menu
    ensure_disabled
    load_tts
    tts_init
    assert vma.actions.include?(:tts_speak_selection),       "speak action not registered"
    assert vma.actions.include?(:tts_stop),                  "stop action not registered"
    assert vma.gui.menu.module_action?(:tts_speak_selection), "speak menu item missing"
    assert vma.gui.menu.module_action?(:tts_stop),           "stop menu item missing"
  ensure
    tts_disable
  end

  def test_disable_unregisters
    ensure_disabled
    load_tts
    tts_init
    tts_disable
    assert !vma.actions.include?(:tts_speak_selection),       "speak action still registered"
    assert !vma.actions.include?(:tts_stop),                  "stop action still registered"
    assert !vma.gui.menu.module_action?(:tts_speak_selection), "speak menu still present"
  end

  def test_init_disable_cycle
    ensure_disabled
    load_tts
    3.times do |i|
      tts_init
      assert vma.actions.include?(:tts_speak_selection), "speak missing after init (cycle #{i})"
      tts_disable
      assert !vma.actions.include?(:tts_speak_selection), "speak present after disable (cycle #{i})"
    end
  end

  # --- detect_rate ---

  def test_detect_rate
    load_tts
    dir = Dir.mktmpdir("vma_tts_test")
    File.write(File.join(dir, "myvoice.onnx.json"),
               JSON.generate({ "audio" => { "sample_rate" => 16000 } }))
    rate = VmaTts.new.send(:detect_rate, dir, "myvoice")
    assert_eq 16000, rate, "sample rate not read from voice json"
    assert_eq nil, VmaTts.new.send(:detect_rate, dir, "missing"), "missing voice should be nil"
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end
end
