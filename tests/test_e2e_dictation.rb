require_relative "support/virtual_mic"

# End-to-end dictation test driven by a virtual microphone (see
# support/virtual_mic.rb): a synthesized phrase is fed into the real dictation
# recorder pipeline, transcribed by the Whisper worker, and asserted to land in
# the buffer.
#
# SKIPPED BY DEFAULT. It is slow (loads a Whisper model) and needs a speech
# synth tool + faster-whisper, so it only runs when opted in:
#
#   VMA_E2E_DICTATION=1 ruby exe/run_tests.rb e2e_dictation
#
# The first run also downloads the tiny Whisper model (~75 MB); allow time.
class TestE2eDictation < VmaTest
  PHRASE = "the quick brown fox jumps over the lazy dog"
  # Any one of these words appearing in the transcript proves ASR worked. Kept
  # loose on purpose — Whisper output is not deterministic word-for-word.
  EXPECT = %w[quick brown fox jumps lazy dog].freeze
  TIMEOUT = 180 # seconds: model load + CPU transcription of a short clip

  def test_dictation_transcribes_virtual_mic
    reason = VirtualMic.unmet_requirement
    skip reason if reason
    ensure_dictation_loaded or return skip("dictation module unavailable")

    mic = VirtualMic.new(PHRASE).open
    with_dictation_config(mic.gst_source) do
      buf.set_pos(buf.size - 1)
      before = buf.to_s

      s = dictation_session
      # Respawn the worker so it picks up the fast test model config.
      $vma_dictation_worker&.stop

      unless s.start(nil)
        skip "recorder failed to start (GStreamer source? no audio libs?)"
      end
      # `start` began playing the fixture via filesrc; let it feed a moment, then
      # finalize (add_newline:false keeps the assertion to just the transcript).
      sleep 1.5
      s.stop(add_newline: false)

      got = wait_until(TIMEOUT) { buf.to_s != before }
      assert got, "no transcript was inserted within #{TIMEOUT}s (Whisper worker failed?)"

      transcript = buf.to_s.sub(before.chomp, "").strip
      words = transcript.downcase.gsub(/[^a-z ]/, " ").split
      assert (EXPECT & words).any?,
             "transcript #{transcript.inspect} contained none of #{EXPECT.inspect}"
    end
  ensure
    $vma_dictation_worker&.stop
    mic&.close
  end

  private

  # Load the dictation module if the suite ran without it enabled, so the test
  # is self-sufficient when opted in. Returns true if usable.
  def ensure_dictation_loaded
    # Module-level defs (dictation_session etc.) load as *private* methods on
    # Object, so include private methods in the check.
    return true if respond_to?(:dictation_session, true)
    df = ppath("modules/dictation/dictation.rb")
    return false unless File.exist?(df)
    load df
    respond_to?(:dictation_session, true)
  end

  # Point dictation at the virtual mic and a fast CPU model, disable the live
  # preliminary passes (so only the final transcript lands), run the block, then
  # restore every key we touched.
  def with_dictation_config(source)
    keys = %i[source model device compute_type chunk_secs normalize]
    saved = keys.to_h { |k| [k, cnf.dictation.public_send("#{k}!")] }
    cnf.dictation.source = source
    cnf.dictation.model = "tiny.en"
    cnf.dictation.device = "cpu"
    cnf.dictation.compute_type = "int8"
    cnf.dictation.chunk_secs = 999   # suppress preliminary chunk transcriptions
    cnf.dictation.normalize = false  # skip ffmpeg loudnorm on the final pass
    yield
  ensure
    saved&.each { |k, v| cnf.dictation.public_send("#{k}=", v) }
  end

  # Poll `cond` while pumping the GTK main loop (the finalize insert arrives via
  # GLib::Idle from the worker thread).
  def wait_until(timeout)
    t0 = Time.now
    loop do
      drain_idle
      return true if yield
      return false if Time.now - t0 > timeout
      sleep 0.1
    end
  end
end
