require "tmpdir"

# A virtual microphone for the dictation E2E test.
#
# Instead of a physical mic, it synthesizes a known phrase to a WAV (via
# espeak / espeak-ng) and feeds that file into the dictation recorder through
# the *same* `cnf.dictation.source` knob that normally selects the microphone —
# as a GStreamer `filesrc ... ! wavparse` chain. So the real recorder pipeline
# (Gst.parse_launch -> audioconvert -> wavenc -> filesink) and the Whisper
# worker run end-to-end, with a deterministic, hermetic audio input and no
# dependency on the OS audio server.
#
# Real-microphone variant: for a test that also exercises the physical capture
# path, swap `open`/`gst_source` for a PulseAudio/PipeWire null sink —
#   pactl load-module module-null-sink sink_name=vma_test_sink
#   paplay -d vma_test_sink <wav>        # play while recording
#   cnf.dictation.source = "pulsesrc device=vma_test_sink.monitor"
# and unload the module in `close`. That needs `pactl`/`paplay` and a running
# sound server, so it is intentionally not the default here.
class VirtualMic
  attr_reader :wav_path, :phrase

  # Synth tools that can write a WAV from text, in preference order.
  SYNTH_TOOLS = %w[espeak-ng espeak].freeze

  def self.synth_tool
    SYNTH_TOOLS.find { |c| which(c) }
  end

  # nil if this test can run, otherwise a human-readable skip reason. Gated first
  # on the opt-in env var so the test is skipped by default.
  def self.unmet_requirement
    return "set VMA_E2E_DICTATION=1 to run (opt-in, slow, loads a Whisper model)" unless ENV["VMA_E2E_DICTATION"]
    return "no speech synth tool on PATH (#{SYNTH_TOOLS.join('/')})" unless synth_tool
    py = cnf.dictation.python! || "python3"
    unless system(py, "-c", "import faster_whisper", out: File::NULL, err: File::NULL)
      return "faster-whisper not importable by #{py}"
    end
    nil
  end

  def initialize(phrase)
    @phrase = phrase
    @wav_path = File.join(Dir.tmpdir, "vma_vmic_#{Process.pid}_#{Time.now.to_i}.wav")
  end

  # Synthesize the phrase to @wav_path. Returns self; raises if synthesis fails.
  def open
    tool = self.class.synth_tool
    ok = system(tool, "-w", @wav_path, @phrase, out: File::NULL, err: File::NULL)
    unless ok && File.exist?(@wav_path) && File.size(@wav_path) > 44 # > WAV header
      raise "speech synthesis failed via #{tool}"
    end
    self
  end

  # The GStreamer source description to assign to cnf.dictation.source.
  def gst_source
    "filesrc location=#{@wav_path} ! wavparse"
  end

  def close
    File.delete(@wav_path) if @wav_path && File.exist?(@wav_path)
  rescue => e
    warn "VirtualMic cleanup: #{e}"
  end
end
