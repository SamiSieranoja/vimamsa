require "gstreamer"
require "open3"
require "tmpdir"
require "json"

# Voice Dictation module
#
# Records from the microphone with GStreamer and transcribes with a persistent
# faster-whisper worker, inserting text at the cursor.
#
# Real-time (hybrid) flow:
#   C , k    -> start fast (no dialog), reusing the last-used initial prompt.
#   C , ; k  -> start with the prompt-selection dialog.
#   (either, while recording) -> stop.
# While you speak, a *preliminary* transcript is inserted incrementally (every few
# seconds, only the new audio is transcribed, so it scales to long dictations). On
# stop, the whole recording is re-transcribed once at best quality and replaces the
# preliminary text in place (a single undo step), ending with a newline.
#
# Note: don't edit elsewhere in the buffer while a dictation is in progress — the
# inserted span is tracked by position, so concurrent edits would misplace the
# final replacement.
#
# Configuration (set in ~/.vimamsa/settings.rb via cnf, all optional):
#   cnf.dictation.python         python interpreter     (default "python3")
#   cnf.dictation.worker         worker script path      (default bundled whisper_worker.py)
#   cnf.dictation.model          faster-whisper model    (default "large-v3")
#   cnf.dictation.language       language code            (default "en")
#   cnf.dictation.device         auto / cuda / cpu        (default "auto")
#   cnf.dictation.compute_type   compute type             (default "float16"; use "int8" on CPU)
#   cnf.dictation.normalize      ffmpeg level norm        (default true; final pass)
#   cnf.dictation.initial_prompt default prompt           (default none; usually set per-dictation
#                                                          in the start dialog)
#   cnf.dictation.chunk_secs     preliminary cadence (s)  (default 4)
#   cnf.dictation.idle_timeout   worker self-exits after   (default 300; <=0 disables)
#                                this many idle seconds to
#                                release VRAM
#   cnf.dictation.startup_timeout give up waiting for the  (default 600; <=0 waits
#                                model to load after this   forever)
#                                many seconds
#   cnf.dictation.source         GStreamer mic source     (default "autoaudiosrc")
#
# Requires faster-whisper (pip install faster-whisper) and ffmpeg on PATH.

# Fixed capture format (what whisper expects). Used by the recorder and by the
# preliminary tail-slicer that writes its own chunk WAVs.
DICT_RATE  = 16000
DICT_CH    = 1
DICT_BITS  = 16
DICT_FRAME = DICT_CH * DICT_BITS / 8

# Return the byte offset where PCM samples begin (just past the "data" chunk
# header), walking the chunk list. Returns nil if not a recognizable WAV.
def vma_wav_data_offset(bytes)
  return nil unless bytes.bytesize >= 12 && bytes[0, 4] == "RIFF" && bytes[8, 4] == "WAVE"
  off = 12
  while off + 8 <= bytes.bytesize
    cid = bytes[off, 4]
    csz = bytes[off + 4, 4].unpack1("V")
    return off + 8 if cid == "data"
    off += 8 + csz + (csz.odd? ? 1 : 0)
  end
  nil
end

# Canonical 44-byte PCM WAV header for the fixed capture format + given data size.
def vma_wav_header(data_size)
  byte_rate   = DICT_RATE * DICT_FRAME
  block_align = DICT_FRAME
  "RIFF" + [36 + data_size].pack("V") + "WAVE" +
    "fmt " + [16, 1, DICT_CH, DICT_RATE, byte_rate, block_align, DICT_BITS].pack("VvvVVvv") +
    "data" + [data_size].pack("V")
end

# Write raw PCM bytes as a standalone WAV in the fixed capture format.
def vma_write_wav(path, pcm)
  File.binwrite(path, vma_wav_header(pcm.bytesize) + pcm)
end

# Rewrite the RIFF + data chunk sizes of a WAV to match its real length. Needed
# because the GStreamer Ruby binding can't send EOS, so wavenc leaves streaming
# placeholders in the header. All samples are present; only the sizes are wrong.
def vma_wav_fix_header!(path)
  data = File.binread(path)
  data_content = vma_wav_data_offset(data) or return false
  data_off = data_content - 8
  real_data = data.bytesize - data_content
  data[4, 4] = [data.bytesize - 8].pack("V")
  data[data_off + 4, 4] = [real_data].pack("V")
  File.binwrite(path, data)
  true
end

# Records mic audio to a WAV file (fixed S16LE / 16 kHz / mono).
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
           "audio/x-raw,format=S16LE,rate=#{DICT_RATE},channels=#{DICT_CH} ! " \
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

  # Stop capturing, right now. Split from #finalize so the mic can be released the
  # moment the user asks for it, even while a preliminary pass is still reading
  # the file (rewriting the header under a concurrent reader is what's unsafe,
  # not stopping the pipeline).
  def stop_capture
    return false unless @recording
    @pipeline.set_state(:null)
    @pipeline = nil
    @recording = false
    true
  end

  # Fix up the streaming placeholder header of the stopped recording and return
  # its path (or nil). Call only once no one else is reading the file.
  def finalize
    return nil unless @wav_path && File.exist?(@wav_path)
    vma_wav_fix_header!(@wav_path)
    @wav_path
  end

  # Stop recording, finalize the WAV header, and return its path (or nil).
  def stop
    return nil unless stop_capture
    finalize
  end
end

# Persistent faster-whisper worker.
#
# Spawns whisper_worker.py once and keeps it alive, so the model is loaded a
# single time and reused. Communication is line-based JSON over stdin/stdout (see
# whisper_worker.py). Requests are serialized with a mutex; a dead worker is
# restarted on the next request.
class VmaWhisperWorker
  # Why the last start/transcribe attempt failed, for display (nil when fine).
  attr_reader :start_error

  # proc {|phase, fraction| } called as the worker reports progress of a long
  # phase ("download"/"load"/"transcribe"; fraction is 0..1 or nil). Runs on
  # whichever thread is talking to the worker, never the main loop.
  attr_accessor :on_progress

  def initialize
    @mutex = Mutex.new
    @stdin = nil
    @stdout = nil
    @wait = nil
    @ready = false
    @start_error = nil
  end

  # Start the worker and wait for the model to finish loading. Blocks the calling
  # thread (never the main loop): call it from a background thread at dictation
  # start so the load overlaps with the user speaking. Safe to call repeatedly.
  def ensure_started
    @mutex.synchronize do
      _spawn unless _alive?
      _await_ready
    end
  end

  # True when a request would be served without waiting for the model to load.
  # Deliberately lock-free so a preliminary pass can cheaply skip itself during a
  # cold start instead of queueing on the mutex behind the load. Racing with
  # _spawn/_await_ready is benign: at worst one preliminary pass is skipped, or
  # one is attempted a moment early and blocks as it used to.
  def ready?
    @ready && _alive?
  end

  # Transcribe a WAV file with optional per-request overrides:
  #   :initial_prompt, :beam_size, :normalize, :vad
  # Returns { ok: true, text: "..." } or { ok: false, error: "..." }.
  def transcribe(wav, opts = {})
    @mutex.synchronize do
      _spawn unless _alive?
      return { ok: false, error: @start_error || "worker not running" } unless _alive?
      return { ok: false, error: @start_error || "model not ready" } unless _await_ready

      begin
        req = { "path" => wav }
        req["initial_prompt"] = opts[:initial_prompt] if opts[:initial_prompt]
        req["beam_size"] = opts[:beam_size] if opts[:beam_size]
        req["normalize"] = opts[:normalize] if opts.key?(:normalize)
        req["vad"] = opts[:vad] if opts.key?(:vad)

        @stdin.puts(JSON.generate(req))
        @stdin.flush
        resp = _read_response
        return { ok: false, error: "worker closed unexpectedly" } if resp.nil?
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
    # Close stale handles from a previous (now-dead) worker before respawning.
    begin; @stdin&.close; rescue; end
    begin; @stdout&.close; rescue; end

    python = cnf.dictation.python! || "python3"
    worker = cnf.dictation.worker! || ppath("modules/dictation/whisper_worker.py")
    idle = cnf.dictation.idle_timeout!
    idle = 300 if idle.nil?

    cmd = [python, worker,
           "--model", (cnf.dictation.model! || "large-v3"),
           "--language", (cnf.dictation.language! || "en"),
           "--device", (cnf.dictation.device! || "auto"),
           "--compute-type", (cnf.dictation.compute_type! || "float16"),
           "--idle-timeout", idle.to_s]
    cmd << "--no-normalize" if cnf.dictation.normalize! == false
    ip = cnf.dictation.initial_prompt!
    cmd += ["--initial-prompt", ip.to_s] if ip && !ip.to_s.empty?

    @stdin, @stdout, @wait = Open3.popen2(*cmd)
  rescue => e
    @start_error = "could not start worker (#{e.class}: #{e.message})"
    @stdin = @stdout = @wait = nil
  end

  # Read protocol lines until a terminating (non-progress) one arrives, handing
  # each {"progress": …} line to the observer. Returns the parsed terminating
  # line, or nil if the worker closed its pipe first.
  def _read_response
    loop do
      line = @stdout.gets
      return nil if line.nil?
      resp = JSON.parse(line) rescue nil
      next if resp.nil? # ignore anything that isn't protocol JSON
      if (p = resp["progress"])
        _notify_progress(p)
        next
      end
      return resp
    end
  end

  # Fan a progress report out to whoever registered interest. Called on the
  # worker-facing thread, so the observer is responsible for getting itself onto
  # the main thread before touching any widget.
  def _notify_progress(p)
    @on_progress&.call(p["phase"].to_s, p["fraction"])
  rescue => e
    debug "Dictation: progress handler error: #{e}"
  end

  # Block until the worker prints its readiness line (model loaded). Cached.
  #
  # Bounded, because this runs while holding @mutex: a worker that never becomes
  # ready (model download stalled, wedged CUDA init) would otherwise hang every
  # later request behind it forever, leaving the editor stuck on "finalizing…"
  # with nothing to report. A first-ever run legitimately downloads several GB,
  # so the default is generous.
  def _await_ready
    return true if @ready
    return false unless @stdout
    limit = cnf.dictation.startup_timeout! || 600

    loop do
      # The limit is per line, not for the whole startup: progress lines prove
      # the worker is alive and downloading, so they legitimately extend the
      # wait. Only silence for the full period counts as wedged.
      if limit > 0 && !@stdout.wait_readable(limit)
        @start_error = "no progress from the speech model for #{limit}s (download stalled?)"
        return false
      end
      line = @stdout.gets
      if line.nil?
        @start_error = "worker exited before becoming ready (check faster-whisper/ffmpeg)"
        return false
      end
      resp = JSON.parse(line) rescue nil
      next if resp.nil?
      if (p = resp["progress"])
        _notify_progress(p)
        next
      end
      if resp["ready"]
        @ready = true
        return true
      end
      @start_error = resp["error"] || "worker failed to load model"
      return false
    end
  end
end

def dictation_worker
  $vma_dictation_worker ||= VmaWhisperWorker.new
end

# Drives one real-time dictation: recording + incremental preliminary inserts +
# final high-quality replacement.
class VmaDictationSession
  def initialize
    @active = false
    @finalizing = false
  end

  def active?
    @active
  end

  # Begin a dictation. `prompt` (or nil) is the whisper initial_prompt.
  def start(prompt)
    return false if @active
    @recorder = VmaDictationRecorder.new
    return false unless @recorder.start

    @prompt = (prompt && !prompt.empty?) ? prompt : nil
    @buf = vma.buf
    @dict_start = @buf.pos
    @dict_len = 0
    @prelim_text = ""
    @pcm_off = nil
    @active = true
    @buf.new_undo_group

    # The mic is already live either way; what differs is whether anything can be
    # transcribed yet. Say which, because a cold start is silent for as long as
    # the model takes to load (seconds warm, minutes on a first download) and
    # otherwise looks like dictation simply not working.
    if dictation_worker.ready?
      _status(:listening)
      message("Dictation: listening… (toggle again to stop)")
    else
      _status(:loading)
      message("Dictation: loading speech model… (already listening; text appears once loaded)")
    end

    # ensure_started blocks until the model is loaded, so report the outcome
    # back on the main thread once it lands. Progress arrives meanwhile.
    dictation_worker.on_progress = method(:_progress_update)
    Thread.new do
      ok = dictation_worker.ensure_started
      GLib::Idle.add { _on_worker_ready(ok); false }
    end
    @running = true
    @prelim_thread = Thread.new { _prelim_loop }
    true
  end

  # Stop recording and produce the final high-quality transcript, replacing the
  # preliminary text. Runs the heavy work off the main thread.
  # add_newline: end the finalized text with a trailing "\n" (default). The space
  #   toggle in dictation mode passes false so pausing doesn't break the line.
  # restart: begin a fresh dictation segment once the finalize lands (used by the
  #   Enter key to continue speaking on the new line).
  def stop(add_newline: true, restart: false)
    return unless @active
    @active = false
    @running = false
    @finalize_newline = add_newline
    @restart_after = restart
    @finalizing = true
    # On a cold start the final pass just queues behind the model load, so don't
    # claim to be transcribing while we are really still waiting for the model
    # (a first-use download can sit here for minutes). _on_worker_ready promotes
    # this to :transcribing once the model actually lands.
    if dictation_worker.ready?
      _status(:transcribing)
      message("Dictation: finalizing…")
    else
      _status(:queued)
      message("Dictation: waiting for the speech model before transcribing…")
    end
    # Release the mic here, not after the join below: on a cold start the
    # preliminary pass can still be blocked waiting for the model to load, and
    # recording through that wait would append seconds of audio the user
    # recorded after they asked to stop.
    @recorder.stop_capture

    Thread.new do
      @prelim_thread&.join          # no more preliminary file reads / inserts
      wav = @recorder.finalize      # rewrite header (safe: no concurrent reader)
      if wav.nil?
        GLib::Idle.add { @finalizing = false; _status(nil); message("Dictation: nothing recorded"); false }
      else
        res = dictation_worker.transcribe(wav, _final_opts)
        File.delete(wav) if wav && File.exist?(wav)
        GLib::Idle.add { _finalize_replace(res); false }
      end
    end
  end

  private

  # Status-area slot key, and the text/style for each phase of a dictation.
  STATUS_KEY = :dictation
  # Base labels, without trailing ellipsis: #_status appends either "…" or a
  # percentage, so a phase reads "DOWNLOADING MODEL 42%" once the worker starts
  # reporting and "DOWNLOADING MODEL…" before it can.
  STATUS_PHASES = {
    loading:      ["🎙 LOADING MODEL",     "status-busy"],
    downloading:  ["⬇ DOWNLOADING MODEL", "status-busy"],
    listening:    ["🎙 LISTENING",         "status-active"],
    queued:       ["⏳ WAITING FOR MODEL", "status-busy"],
    transcribing: ["⏳ TRANSCRIBING",      "status-busy"],
    failed:       ["🎙 MODEL FAILED",      "status-error"],
  }.freeze

  # Steady states rather than work in progress: no ellipsis, no percentage.
  STATUS_STEADY = %i[listening failed].freeze

  # (main thread) Show a dictation phase in the status area, or clear the slot
  # when phase is nil. Unlike the minibuf messages this stays put, so the user
  # can see at a glance whether it is still listening, still loading, or done.
  # `fraction` (0..1) renders as a percentage.
  def _status(phase, fraction = nil)
    if phase.nil?
      vma.gui&.set_status_indicator(STATUS_KEY, nil)
      return
    end
    text, css = STATUS_PHASES[phase]
    return if text.nil?
    if fraction
      text = "#{text} #{(fraction.to_f * 100).round}%"
    elsif !STATUS_STEADY.include?(phase)
      text = "#{text}…"
    end
    vma.gui&.set_status_indicator(STATUS_KEY, text, css_class: css)
  end

  # (worker thread) A progress report from the worker. Hop onto the main thread,
  # then map the phase onto whichever status this session is currently in — a
  # download can be running while still listening or while already finalizing,
  # and the two must not show the same thing.
  def _progress_update(phase, fraction)
    GLib::Idle.add do
      case phase
      when "download"
        _status(:downloading, fraction) if @active || @finalizing
      when "load"
        _status(@active ? :loading : (@finalizing ? :queued : nil))
      when "transcribe"
        # Preliminary passes report progress too, but they run while listening
        # and must not overwrite LISTENING with TRANSCRIBING.
        _status(:transcribing, fraction) if @finalizing && !@active
      end
      false
    end
  end

  # (main thread) The model finished loading, or failed to. Which state that
  # lands in depends on whether the user has stopped in the meantime: still
  # listening, or already stopped with a finalize queued behind the load. Once
  # the finalize has completed, neither holds and the slot is left alone.
  def _on_worker_ready(ok)
    if @active
      if ok
        _status(:listening)
        message("Dictation: model loaded — listening")
      else
        _status(:failed)
        message("Dictation: could not load speech model — #{dictation_worker.start_error}")
      end
    elsif @finalizing
      if ok
        _status(:transcribing)
        message("Dictation: model loaded — transcribing…")
      else
        _status(:failed)
        message("Dictation: could not load speech model — #{dictation_worker.start_error}")
      end
    end
  end

  def _chunk_secs
    (cnf.dictation.chunk_secs! || 4).to_f
  end

  # Require at least ~1s of new audio before transcribing a preliminary chunk.
  def _min_new_bytes
    DICT_RATE * DICT_FRAME
  end

  def _prelim_loop
    elapsed = 0.0
    while @running
      sleep 0.2
      elapsed += 0.2
      next if elapsed < _chunk_secs
      elapsed = 0.0
      _process_tail
    end
  rescue => e
    debug "Dictation prelim loop error: #{e}"
  end

  # Transcribe the not-yet-processed tail of the growing recording and append it.
  def _process_tail
    # Cold start: the model is still loading. Preliminary passes are best-effort,
    # so skip rather than block — a blocked pass holds the worker mutex, which is
    # what the final pass then has to wait on, turning a slow start into a stall
    # with the editor sitting on "finalizing…". The audio isn't lost: @pcm_off
    # only advances on a pass that actually runs, so the next tick picks up the
    # whole tail.
    return unless dictation_worker.ready?

    path = @recorder.wav_path
    return unless path && File.exist?(path)

    if @pcm_off.nil?
      head = File.binread(path, 4096)
      doff = vma_wav_data_offset(head) or return
      @pcm_off = doff
    end

    fsize = File.size(path)
    endpos = fsize - ((fsize - @pcm_off) % DICT_FRAME)  # frame-align
    newlen = endpos - @pcm_off
    return if newlen < _min_new_bytes

    pcm = File.open(path, "rb") { |f| f.seek(@pcm_off); f.read(newlen) }
    return if pcm.nil? || pcm.bytesize < newlen  # short read; retry next tick
    @pcm_off = endpos

    tmp = File.join(Dir.tmpdir, "vma_dict_chunk_#{Process.pid}_#{(Time.now.to_f * 1000).to_i}.wav")
    vma_write_wav(tmp, pcm)
    res = dictation_worker.transcribe(tmp, _prelim_opts)
    File.delete(tmp) if File.exist?(tmp)

    return unless res[:ok] && res[:text] && !res[:text].empty?
    text = res[:text]
    GLib::Idle.add { _append_prelim(text); false }
  end

  # Fast, low-context settings for the live preliminary passes. Carry the tail of
  # the accumulated text forward as a prompt to improve cross-chunk continuity.
  def _prelim_opts
    ctx = [@prompt, @prelim_text[-200..]].compact.join(" ").strip
    opts = { beam_size: 1, normalize: false, vad: false }
    opts[:initial_prompt] = ctx unless ctx.empty?
    opts
  end

  # High-quality settings for the final pass.
  def _final_opts
    opts = { beam_size: 5, vad: true, normalize: cnf.dictation.normalize! != false }
    opts[:initial_prompt] = @prompt if @prompt
    opts
  end

  # True once the target buffer has been closed out from under an async pass:
  # `Buffer#view` returns nil (gui_close_buffer removed it), so any GTK sync
  # would crash. Text mutation would also be pointless once the buffer is gone.
  def _target_gone?
    @buf.nil? || @buf.view.nil?
  end

  # (main thread) Append a preliminary phrase to the tracked span.
  def _append_prelim(text)
    return if _target_gone?
    t = (@dict_len > 0 ? " " : "") + text
    @buf.insert_txt_at(t, @dict_start + @dict_len)
    @dict_len += t.size
    @prelim_text = (@prelim_text + " " + text).strip
    @buf.view.handle_deltas
  end

  # (main thread) Replace the preliminary span with the final transcript.
  def _finalize_replace(res)
    # Transcription is done however this turns out; clear the slot up front so
    # every path below (including the early returns) leaves it empty. A restart
    # at the end re-populates it via start.
    @finalizing = false
    _status(nil)
    if !res[:ok]
      message("Dictation: transcription failed — #{res[:error]}")
      return
    end
    if _target_gone?
      message("Dictation: target buffer closed — transcript discarded")
      return
    end
    final = res[:text].to_s
    @buf.delete_range(@dict_start, @dict_start + @dict_len - 1) if @dict_len > 0
    @dict_len = 0

    if final.empty?
      # Nothing recognized: still honor an explicit newline request (e.g. Enter)
      # so the caret moves to the next line, then optionally continue dictating.
      if @finalize_newline
        @buf.insert_txt_at("\n", @dict_start)
        @buf.view.handle_deltas
        @buf.set_pos(@dict_start + 1)
      else
        @buf.view.handle_deltas
      end
      @buf.new_undo_group
      message("Dictation: no speech recognized")
      start(@prompt) if @restart_after
      return
    end

    # Optionally append a newline so the dictation ends a line; leave the cursor
    # after the inserted text (start of the next line when a newline was added).
    text = final + (@finalize_newline ? "\n" : "")
    @buf.insert_txt_at(text, @dict_start)
    @buf.view.handle_deltas
    @buf.set_pos(@dict_start + text.size)
    @buf.new_undo_group
    message("Dictation: done (#{final.length} chars)")

    # Enter continues the dictation on the new line: begin a fresh segment now that
    # the span replace is done (main thread, @active already false — span tracking
    # for the new segment starts clean at the new caret position).
    start(@prompt) if @restart_after
  end
end

def dictation_session
  $vma_dict_session ||= VmaDictationSession.new
end

# ── Saved prompts ───────────────────────────────────────────────────────────────

def vma_dict_prompts_path
  get_dot_path("dictation_prompts.json")
end

def vma_dict_load_prompts
  path = vma_dict_prompts_path
  if File.exist?(path)
    (JSON.parse(File.read(path)) rescue nil) || { "prompts" => [], "last" => "" }
  else
    { "prompts" => [], "last" => "" }
  end
end

def vma_dict_save_prompts(data)
  File.write(vma_dict_prompts_path, JSON.pretty_generate(data))
rescue => e
  debug "Dictation: could not save prompts: #{e}"
end

# Modal dialog shown when starting a dictation: pick a saved prompt, edit it, or
# add a new one. Calls `on_start` with the chosen prompt (or nil) on Start.
# ── Model selection ─────────────────────────────────────────────────────────────

# Presets offered by Modules ▸ "Select Dictation Model…", as
# [model id, label, language]. All are CTranslate2 format, which faster-whisper
# loads straight from the HuggingFace id with no conversion step.
#
# The language travels with the model on purpose: a Finnish fine-tune transcribes
# badly while the language stays "en", and nothing in the UI would show that
# mismatch, so choosing a preset sets both.
VMA_DICT_MODELS = [
  ["large-v3",                                  "large-v3 — multilingual, general purpose (default)", "en"],
  ["Finnish-NLP/whisper-large-finnish-v3-ct2",  "Finnish — large-v3 fine-tune (best Finnish accuracy)", "fi"],
  ["RASMUS/whisper-large-v3-turbo-finnish-ct2", "Finnish — large-v3-turbo fine-tune (faster)", "fi"],
  ["mpasila/faster-whisper-large-finnish-v3",   "Finnish — large-v3 fine-tune (alternate packaging)", "fi"],
  ["tiny.en",                                   "tiny.en — English only, fast and low quality", "en"],
].freeze

# Apply a model choice: update the live config, remember it, and retire the
# running worker so the next dictation loads the new weights (the worker holds
# one model for its whole life).
def vma_dict_apply_model(model, language)
  return if model.nil? || model.to_s.strip.empty?
  cnf.dictation.model = model
  cnf.dictation.language = language unless language.nil? || language.to_s.empty?

  data = ($vma_dict_prompts ||= vma_dict_load_prompts)
  data["model"] = model
  data["language"] = cnf.dictation.language!
  vma_dict_save_prompts(data)

  $vma_dictation_worker&.stop
  message("Dictation model: #{model} (#{cnf.dictation.language!}) — loads on next dictation")
end

# Restore the stored model choice at init, so it survives a restart without the
# user having to hand-edit settings.rb.
def vma_dict_restore_model
  data = ($vma_dict_prompts ||= vma_dict_load_prompts)
  return if data["model"].nil? || data["model"].to_s.empty?
  cnf.dictation.model = data["model"]
  cnf.dictation.language = data["language"] if data["language"]
end

# Pick the speech model (and its language). Presets in a dropdown, plus a free
# text field for any other CTranslate2 model id or local path.
def vma_dictation_model_dialog
  current = cnf.dictation.model! || "large-v3"

  window = Gtk::Window.new
  window.set_transient_for($vmag.window) if $vmag&.window
  window.modal = true
  window.title = "Select dictation model"

  frame = Gtk::Frame.new
  window.set_child(frame)
  vbox = Gtk::Box.new(:vertical, 8)
  vbox.margin = 12
  frame.set_child(vbox)

  vbox.append(Gtk::Label.new("Speech recognition model:"))

  labels = VMA_DICT_MODELS.map { |_id, label, _lang| label }
  dropdown = Gtk::DropDown.new(Gtk::StringList.new(labels), nil)
  vbox.append(dropdown)

  entry = Gtk::Entry.new
  entry.text = current
  entry.hexpand = true
  vbox.append(entry)

  lang_box = Gtk::Box.new(:horizontal, 8)
  lang_box.append(Gtk::Label.new("Language code:"))
  lang_entry = Gtk::Entry.new
  lang_entry.text = (cnf.dictation.language! || "en").to_s
  lang_box.append(lang_entry)
  vbox.append(lang_box)

  note = Gtk::Label.new("Any CTranslate2 model id or local path works. " \
                        "A model not yet downloaded is fetched on first use.")
  note.wrap = true
  note.xalign = 0
  vbox.append(note)

  sel = VMA_DICT_MODELS.index { |id, _l, _lang| id == current }
  dropdown.selected = sel if sel
  dropdown.signal_connect("notify::selected") do
    id, _label, lang = VMA_DICT_MODELS[dropdown.selected]
    if id
      entry.text = id
      lang_entry.text = lang.to_s
    end
  end

  hbox = Gtk::Box.new(:horizontal, 8)
  hbox.halign = :end
  cancel_btn = Gtk::Button.new(:label => "Cancel")
  ok_btn = Gtk::Button.new(:label => "Use model")
  hbox.append(cancel_btn)
  hbox.append(ok_btn)
  vbox.append(hbox)

  apply = proc do
    vma_dict_apply_model(entry.text.to_s.strip, lang_entry.text.to_s.strip)
    window.destroy
  end
  ok_btn.signal_connect("clicked") { apply.call }
  cancel_btn.signal_connect("clicked") { window.destroy }

  press = Gtk::EventControllerKey.new
  press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
  window.add_controller(press)
  press.signal_connect "key-pressed" do |_g, keyval, _kc, _y|
    if keyval == Gdk::Keyval::KEY_Return
      apply.call
      true
    elsif keyval == Gdk::Keyval::KEY_Escape
      window.destroy
      true
    else
      false
    end
  end

  window.show
end

def vma_dictation_prompt_dialog(&on_start)
  data = ($vma_dict_prompts ||= vma_dict_load_prompts)
  prompts = data["prompts"] || []
  last = data["last"] || ""

  window = Gtk::Window.new
  window.set_transient_for($vmag.window) if $vmag&.window
  window.modal = true
  window.title = "Start dictation"

  frame = Gtk::Frame.new
  window.set_child(frame)
  vbox = Gtk::Box.new(:vertical, 8)
  vbox.margin = 12
  frame.set_child(vbox)

  vbox.append(Gtk::Label.new("Initial prompt (biases recognition toward these words):"))

  items = ["(none)"] + prompts
  strlist = Gtk::StringList.new(items)
  dropdown = Gtk::DropDown.new(strlist, nil)
  vbox.append(dropdown)

  entry = Gtk::Entry.new
  entry.text = last
  entry.hexpand = true
  vbox.append(entry)

  sel = items.index(last)
  dropdown.selected = sel if sel
  dropdown.signal_connect("notify::selected") do
    i = dropdown.selected
    entry.text = (i && i > 0) ? items[i] : ""
  end

  hbox = Gtk::Box.new(:horizontal, 8)
  hbox.halign = :end
  save_btn = Gtk::Button.new(:label => "Save as new")
  cancel_btn = Gtk::Button.new(:label => "Cancel")
  start_btn = Gtk::Button.new(:label => "Start")
  hbox.append(save_btn)
  hbox.append(cancel_btn)
  hbox.append(start_btn)
  vbox.append(hbox)

  do_start = proc do
    prompt = entry.text.to_s
    data["last"] = prompt
    vma_dict_save_prompts(data)
    window.destroy
    on_start.call(prompt.empty? ? nil : prompt)
  end

  save_btn.signal_connect("clicked") do
    t = entry.text.to_s.strip
    unless t.empty? || prompts.include?(t)
      prompts << t
      data["prompts"] = prompts
      vma_dict_save_prompts(data)
      strlist.append(t)
      items << t
    end
  end
  start_btn.signal_connect("clicked") { do_start.call }
  cancel_btn.signal_connect("clicked") { window.destroy }

  press = Gtk::EventControllerKey.new
  press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
  window.add_controller(press)
  press.signal_connect "key-pressed" do |_g, keyval, _kc, _y|
    if keyval == Gdk::Keyval::KEY_Return
      do_start.call
      true
    elsif keyval == Gdk::Keyval::KEY_Escape
      window.destroy
      true
    else
      false
    end
  end

  window.show
end

# ── Toggle / lifecycle ──────────────────────────────────────────────────────────

# Fast toggle: start immediately (no dialog) reusing the last-used prompt, or stop.
def dictation_toggle
  s = dictation_session
  if s.active?
    s.stop
  else
    s.start(dictation_last_prompt)
  end
end

# The last-used whisper prompt (nil when unset/blank).
def dictation_last_prompt
  last = $vma_dict_prompts && $vma_dict_prompts["last"]
  (last.nil? || last.to_s.strip.empty?) ? nil : last
end

# `, k`: switch into the dedicated dictation keyboard mode and start listening.
def dictation_enter_mode
  vma.kbd.set_mode(:dictation)
  s = dictation_session
  s.start(dictation_last_prompt) unless s.active?
end

# Dictation mode Space: toggle listening on/off without leaving the mode and
# without ending the line (so a pause doesn't insert a newline).
def dictation_toggle_stay
  s = dictation_session
  if s.active?
    s.stop(add_newline: false)
  else
    s.start(dictation_last_prompt)
  end
end

# Dictation mode Enter: start a new line. If listening, finalize the current
# segment with a newline and resume on the next line; otherwise just insert one.
def dictation_newline
  s = dictation_session
  if s.active?
    s.stop(add_newline: true, restart: true)
  else
    b = vma.buf
    b.insert_txt_at("\n", b.pos)
    b.set_pos(b.pos + 1)
    b.view.handle_deltas
  end
end

# Dictation mode Esc / Ctrl-tap / `, k`: finalize any listening (with a trailing
# newline) and return to the previous mode.
def dictation_exit_mode
  s = dictation_session
  s.stop(add_newline: true) if s.active?
  vma.kbd.to_previous_mode
end

# Toggle with the prompt-selection dialog, or stop.
def dictation_toggle_dialog
  s = dictation_session
  if s.active?
    s.stop
  else
    vma_dictation_prompt_dialog { |prompt| s.start(prompt) }
  end
end

# Stop the worker now to free its VRAM. It respawns automatically on the next
# dictation. Refuses while a dictation is in progress.
def dictation_release_vram
  if $vma_dict_session&.active?
    message("Dictation: stop the current dictation first")
    return
  end
  if $vma_dictation_worker
    $vma_dictation_worker.stop
    message("Dictation: model unloaded (VRAM released)")
  else
    message("Dictation: worker not running")
  end
end

def dictation_init
  $vma_dict_prompts = vma_dict_load_prompts
  vma_dict_restore_model
  reg_act(:dictation_select_model, proc { vma_dictation_model_dialog },
          "Voice dictation: choose speech model")
  reg_act(:dictation_toggle, proc { dictation_toggle },
          "Voice dictation: start/stop (fast, last prompt)")
  reg_act(:dictation_toggle_dialog, proc { dictation_toggle_dialog },
          "Voice dictation: start/stop (choose prompt)")
  reg_act(:dictation_release_vram, proc { dictation_release_vram },
          "Voice dictation: unload model to free VRAM")
  reg_act(:dictation_enter_mode, proc { dictation_enter_mode },
          "Voice dictation: enter dictation mode")
  reg_act(:dictation_toggle_stay, proc { dictation_toggle_stay },
          "Dictation mode: toggle listening (stay in mode)")
  reg_act(:dictation_newline, proc { dictation_newline },
          "Dictation mode: new line")
  reg_act(:dictation_exit_mode, proc { dictation_exit_mode },
          "Dictation mode: exit")

  # A dedicated dictation input mode that inherits command mode (like `audio`),
  # so unoverridden command chords stay available while dictating.
  vma.kbd.add_minor_mode("dictation", :dictation, :command)
  add_keys "dictation", {
    "C , k" => :dictation_enter_mode,        # start + enter dictation mode
    "C , ; k" => :dictation_toggle_dialog,   # plain toggle (choose prompt), no mode
    "dictation space" => :dictation_toggle_stay,
    "dictation enter || dictation return" => :dictation_newline,
    "dictation esc || dictation ctrl! || dictation , k" => :dictation_exit_mode,
  }
  vma.gui.menu.add_module_action(:dictation_toggle, "Start/Stop Dictation")
  vma.gui.menu.add_module_action(:dictation_toggle_dialog, "Start Dictation (choose prompt)")
  vma.gui.menu.add_module_action(:dictation_release_vram, "Release Dictation VRAM")
  vma.gui.menu.add_module_action(:dictation_select_model, "Select Dictation Model…")
end

def dictation_disable
  dictation_session.stop if $vma_dict_session&.active?
  $vma_dictation_worker&.stop
  # The module is going away; don't leave a stale indicator behind. (stop above
  # only queues the finalize that would normally clear it.)
  vma.gui&.set_status_indicator(VmaDictationSession::STATUS_KEY, nil)
  unreg_act(:dictation_toggle)
  unreg_act(:dictation_toggle_dialog)
  unreg_act(:dictation_release_vram)
  unreg_act(:dictation_enter_mode)
  unreg_act(:dictation_toggle_stay)
  unreg_act(:dictation_newline)
  unreg_act(:dictation_exit_mode)
  unreg_act(:dictation_select_model)
  unbindkey "C , k"
  unbindkey "C , ; k"
  unbindkey "dictation", include_child_nodes: true
  vma.gui.menu.remove_module_action(:dictation_toggle)
  vma.gui.menu.remove_module_action(:dictation_toggle_dialog)
  vma.gui.menu.remove_module_action(:dictation_release_vram)
  vma.gui.menu.remove_module_action(:dictation_select_model)
end
