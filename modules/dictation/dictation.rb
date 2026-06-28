require "gstreamer"
require "open3"
require "tmpdir"
require "json"

# Voice Dictation module
#
# Records from the microphone with GStreamer, transcribes the audio with a
# persistent faster-whisper worker, and inserts the resulting text at the cursor.
#
# One toggle action drives it: first invocation starts recording, the second
# stops recording and kicks off transcription.
#
# Transcription runs in a long-lived Python worker (whisper_worker.py) that loads
# the model once and stays warm, so repeated dictation is fast. The worker is
# started when recording begins so the model loads while you speak.
#
# Configuration (via cnf, all optional):
#   cnf.dictation.python       python interpreter    (default "python3")
#   cnf.dictation.worker       worker script path     (default bundled whisper_worker.py)
#   cnf.dictation.model        faster-whisper model   (default "large-v3")
#   cnf.dictation.language     language code           (default "en")
#   cnf.dictation.device       auto / cuda / cpu       (default "auto")
#   cnf.dictation.compute_type compute type            (default "float16"; use "int8" on CPU)
#   cnf.dictation.normalize    ffmpeg level norm       (default true)
#   cnf.dictation.source       GStreamer mic source    (default "autoaudiosrc")
#
# Requires faster-whisper (pip install faster-whisper) and ffmpeg on PATH.

# Records mic audio to a WAV file.
#
# The Ruby gstreamer binding cannot construct a usable EOS event, so wavenc
# never finalizes its header (the RIFF/data size fields stay at streaming
# placeholders). All audio samples are written regardless; we record with fixed
# caps (S16LE / 16 kHz / mono) and rewrite the two size fields ourselves after
# stopping, which yields a standard WAV that whisper reads directly.
class VmaDictationRecorder
  attr_reader :recording, :wav_path

  def initialize
    @pipeline = nil
    @recording = false
    @wav_path = nil
  end

  def start
    return false if @recording

    src = cnf.dictation.source! || "autoaudiosrc"
    @wav_path = File.join(Dir.tmpdir, "vma_dictation_#{Process.pid}_#{Time.now.to_i}.wav")

    desc = "#{src} ! audioconvert ! audioresample ! " \
           "audio/x-raw,format=S16LE,rate=16000,channels=1 ! " \
           "wavenc ! filesink location=#{@wav_path}"

    @pipeline = Gst.parse_launch(desc)
    if @pipeline.nil?
      message("Dictation: failed to build GStreamer pipeline")
      return false
    end

    @pipeline.set_state(:playing)
    # Block until the pipeline actually reaches PLAYING (e.g. mic opened ok).
    res, = @pipeline.get_state(3 * Gst::SECOND)
    if res == Gst::StateChangeReturn::FAILURE
      message("Dictation: could not start recording — no microphone?")
      @pipeline.set_state(:null)
      @pipeline = nil
      return false
    end

    @recording = true
    true
  end

  # Stop recording, finalize the WAV, and return its path (or nil on failure).
  def stop
    return nil unless @recording
    @pipeline.set_state(:null)
    @pipeline = nil
    @recording = false

    return nil unless @wav_path && File.exist?(@wav_path)
    fix_wav_header!(@wav_path)
    @wav_path
  end

  private

  # Rewrite the RIFF chunk size and data chunk size to match the real file
  # length. Walks the chunk list to find "data" rather than assuming an offset.
  def fix_wav_header!(path)
    data = File.binread(path)
    return false unless data[0, 4] == "RIFF" && data[8, 4] == "WAVE"

    off = 12
    data_off = nil
    while off + 8 <= data.bytesize
      cid = data[off, 4]
      csz = data[off + 4, 4].unpack1("V")
      if cid == "data"
        data_off = off
        break
      end
      off += 8 + csz + (csz.odd? ? 1 : 0)
    end
    return false unless data_off

    real_data = data.bytesize - (data_off + 8)
    data[4, 4] = [data.bytesize - 8].pack("V")
    data[data_off + 4, 4] = [real_data].pack("V")
    File.binwrite(path, data)
    true
  end
end

# Persistent faster-whisper worker.
#
# Spawns whisper_worker.py once and keeps it alive, so the model is loaded a
# single time and reused across dictations. Communication is line-based JSON over
# the worker's stdin/stdout (see whisper_worker.py for the protocol). Requests are
# serialized with a mutex; a dead worker is restarted on the next request.
class VmaWhisperWorker
  def initialize
    @mutex = Mutex.new
    @stdin = nil
    @stdout = nil
    @wait = nil
    @ready = false
    @start_error = nil
  end

  # Start the worker if it is not already running. Non-blocking: the model loads
  # in the worker process; readiness is awaited later in #transcribe. Safe to
  # call repeatedly (e.g. when recording starts, to warm the model).
  def ensure_started
    @mutex.synchronize { _spawn unless _alive? }
  end

  # Transcribe a WAV file. Returns a result hash:
  #   { ok: true,  text: "..." }
  #   { ok: false, error: "..." }
  def transcribe(wav)
    @mutex.synchronize do
      _spawn unless _alive?
      return { ok: false, error: @start_error || "worker not running" } unless _alive?
      return { ok: false, error: @start_error || "model not ready" } unless _await_ready

      begin
        @stdin.puts(wav)
        @stdin.flush
        line = @stdout.gets
        return { ok: false, error: "worker closed unexpectedly" } if line.nil?
        resp = JSON.parse(line)
        if resp["ok"]
          { ok: true, text: (resp["text"] || "").strip }
        else
          { ok: false, error: resp["error"] || "unknown error" }
        end
      rescue => e
        { ok: false, error: "#{e.class}: #{e.message}" }
      end
    end
  end

  def stop
    @mutex.synchronize do
      begin
        @stdin&.close
      rescue
        nil
      end
      @stdin = @stdout = @wait = nil
      @ready = false
    end
  end

  private

  def _alive?
    @wait && @wait.alive?
  end

  def _spawn
    @ready = false
    @start_error = nil
    python = cnf.dictation.python! || "python3"
    worker = cnf.dictation.worker! || ppath("modules/dictation/whisper_worker.py")

    cmd = [python, worker,
           "--model", (cnf.dictation.model! || "large-v3"),
           "--language", (cnf.dictation.language! || "en"),
           "--device", (cnf.dictation.device! || "auto"),
           "--compute-type", (cnf.dictation.compute_type! || "float16")]
    cmd << "--no-normalize" if cnf.dictation.normalize! == false

    @stdin, @stdout, @wait = Open3.popen2(*cmd)
  rescue => e
    @start_error = "could not start worker (#{e.class}: #{e.message})"
    @stdin = @stdout = @wait = nil
  end

  # Block until the worker prints its readiness line (model loaded). Cached so it
  # is only read once. Returns true if ready, false on failure.
  def _await_ready
    return true if @ready
    return false unless @stdout
    line = @stdout.gets
    if line.nil?
      @start_error = "worker exited before becoming ready (check faster-whisper/ffmpeg)"
      return false
    end
    resp = JSON.parse(line) rescue {}
    if resp["ready"]
      @ready = true
      true
    else
      @start_error = resp["error"] || "worker failed to load model"
      false
    end
  end
end

def dictation_worker
  $vma_dictation_worker ||= VmaWhisperWorker.new
end

# Toggle: start recording, or stop + transcribe + insert.
def dictation_toggle
  $vma_dictation ||= VmaDictationRecorder.new
  rec = $vma_dictation

  if rec.recording
    wav = rec.stop
    if wav.nil?
      message("Dictation: nothing recorded")
      return
    end
    message("Dictation: transcribing…")
    pos = vma.buf.pos
    Thread.new do
      res = dictation_worker.transcribe(wav)
      File.delete(wav) if File.exist?(wav)
      GLib::Idle.add do
        if !res[:ok]
          message("Dictation: transcription failed — #{res[:error]}")
        elsif res[:text] && !res[:text].empty?
          vma.buf.insert_txt_at(res[:text], pos)
          vma.buf.view.handle_deltas
          message("Dictation: inserted #{res[:text].length} chars")
        else
          message("Dictation: no speech recognized")
        end
        false
      end
    end
  else
    if rec.start
      # Warm the model while the user speaks so transcription is near-instant.
      Thread.new { dictation_worker.ensure_started }
      message("Dictation: recording… (toggle again to stop)")
    end
  end
end

def dictation_init
  reg_act(:dictation_toggle, proc { dictation_toggle },
          "Voice dictation: start/stop recording and transcribe")
  add_keys "dictation", { "C , k" => :dictation_toggle }
  vma.gui.menu.add_module_action(:dictation_toggle, "Start/Stop Dictation")
end

def dictation_disable
  # Stop any in-progress recording and the worker before tearing down.
  $vma_dictation.stop if $vma_dictation && $vma_dictation.recording
  $vma_dictation_worker&.stop
  unreg_act(:dictation_toggle)
  unbindkey "C , k"
  vma.gui.menu.remove_module_action(:dictation_toggle)
end
