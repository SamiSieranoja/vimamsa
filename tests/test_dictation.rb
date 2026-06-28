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
end
