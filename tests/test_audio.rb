class TestAudio < VmaTest
  def load_audio
    load ppath("modules/audio/audio_info.rb")
    load ppath("modules/audio/audio.rb")
  end

  def ensure_disabled
    audio_disable if vma.actions.include?("audio.stop")
  end

  def test_info_structure
    load ppath("modules/audio/audio_info.rb")
    info = audio_info
    assert info[:name].is_a?(String) && !info[:name].empty?, "name should be a non-empty String"
    assert_eq true, info[:no_restart]
  end

  # Disabled by default: none of it is in the core any more.
  def test_not_in_core_by_default
    return skip("audio module enabled in this config") if cnf.modules.audio.enabled?
    assert !vma.actions.include?("audio.stop"), "audio.stop registered without the module"
    assert !vma.actions.include?("mode.audio"), "mode.audio registered without the module"
  end

  def test_init_disable_cycle
    ensure_disabled
    load_audio
    2.times do |i|
      audio_init
      %w[audio.stop audio.forward audio.backward mode.audio].each do |a|
        assert vma.actions.include?(a), "#{a} missing after init (cycle #{i})"
      end
      audio_disable
      %w[audio.stop audio.forward audio.backward mode.audio].each do |a|
        assert !vma.actions.include?(a), "#{a} still registered after disable (cycle #{i})"
      end
    end
  end

  def test_audio_mode_keys
    ensure_disabled
    load_audio
    audio_init
    vma.kbd.set_mode(:command)
    keys(", m a")
    assert_mode :audio
    keys("q")
    assert_mode :command
  ensure
    vma.kbd.set_mode(:command)
    audio_disable
  end

  def test_disable_leaves_audio_mode
    ensure_disabled
    load_audio
    audio_init
    vma.kbd.set_mode(:command)
    act("mode.audio")
    assert_mode :audio
    audio_disable
    assert_mode :command
  ensure
    vma.kbd.set_mode(:command)
  end
end
