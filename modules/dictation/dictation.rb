require "gstreamer"
require "open3"
require "tmpdir"
require "json"

# Voice Dictation module
#
# Records from the microphone with GStreamer and transcribes with a persistent
# faster-whisper worker, inserting text at the cursor.
#
# Real-time (hybrid) flow, driven by one toggle action:
#   1st press  -> prompt dialog -> start recording. While you speak, a *preliminary*
#                 transcript is inserted incrementally (every few seconds, only the
#                 new audio is transcribed, so it scales to long dictations).
#   2nd press  -> stop. The whole recording is re-transcribed once at best quality
#                 and replaces the preliminary text in place (a single undo step).
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

  # Stop recording, finalize the WAV header, and return its path (or nil).
  def stop
    return nil unless @recording
    @pipeline.set_state(:null)
    @pipeline = nil
    @recording = false

    return nil unless @wav_path && File.exist?(@wav_path)
    vma_wav_fix_header!(@wav_path)
    @wav_path
  end
end

# Persistent faster-whisper worker.
#
# Spawns whisper_worker.py once and keeps it alive, so the model is loaded a
# single time and reused. Communication is line-based JSON over stdin/stdout (see
# whisper_worker.py). Requests are serialized with a mutex; a dead worker is
# restarted on the next request.
class VmaWhisperWorker
  def initialize
    @mutex = Mutex.new
    @stdin = nil
    @stdout = nil
    @wait = nil
    @ready = false
    @start_error = nil
  end

  # Start the worker if not already running. Non-blocking: the model loads in the
  # worker; readiness is awaited in #transcribe. Safe to call repeatedly (used to
  # warm the model when recording starts).
  def ensure_started
    @mutex.synchronize { _spawn unless _alive? }
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
    ip = cnf.dictation.initial_prompt!
    cmd += ["--initial-prompt", ip.to_s] if ip && !ip.to_s.empty?

    @stdin, @stdout, @wait = Open3.popen2(*cmd)
  rescue => e
    @start_error = "could not start worker (#{e.class}: #{e.message})"
    @stdin = @stdout = @wait = nil
  end

  # Block until the worker prints its readiness line (model loaded). Cached.
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

# Drives one real-time dictation: recording + incremental preliminary inserts +
# final high-quality replacement.
class VmaDictationSession
  def initialize
    @active = false
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

    Thread.new { dictation_worker.ensure_started }
    @running = true
    @prelim_thread = Thread.new { _prelim_loop }
    message("Dictation: listening… (toggle again to stop)")
    true
  end

  # Stop recording and produce the final high-quality transcript, replacing the
  # preliminary text. Runs the heavy work off the main thread.
  def stop
    return unless @active
    @active = false
    @running = false
    message("Dictation: finalizing…")

    Thread.new do
      @prelim_thread&.join          # no more preliminary file reads / inserts
      wav = @recorder.stop          # finalize header (safe: no concurrent reader)
      if wav.nil?
        GLib::Idle.add { message("Dictation: nothing recorded"); false }
      else
        res = dictation_worker.transcribe(wav, _final_opts)
        File.delete(wav) if wav && File.exist?(wav)
        GLib::Idle.add { _finalize_replace(res); false }
      end
    end
  end

  private

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

  # (main thread) Append a preliminary phrase to the tracked span.
  def _append_prelim(text)
    t = (@dict_len > 0 ? " " : "") + text
    @buf.insert_txt_at(t, @dict_start + @dict_len)
    @dict_len += t.size
    @prelim_text = (@prelim_text + " " + text).strip
    @buf.view.handle_deltas
  end

  # (main thread) Replace the preliminary span with the final transcript.
  def _finalize_replace(res)
    if !res[:ok]
      message("Dictation: transcription failed — #{res[:error]}")
      return
    end
    final = res[:text].to_s
    @buf.delete_range(@dict_start, @dict_start + @dict_len - 1) if @dict_len > 0
    @buf.insert_txt_at(final, @dict_start) unless final.empty?
    @buf.view.handle_deltas
    @buf.new_undo_group
    @dict_len = 0
    if final.empty?
      message("Dictation: no speech recognized")
    else
      message("Dictation: done (#{final.length} chars)")
    end
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

def dictation_toggle
  s = dictation_session
  if s.active?
    s.stop
  else
    vma_dictation_prompt_dialog { |prompt| s.start(prompt) }
  end
end

def dictation_init
  $vma_dict_prompts = vma_dict_load_prompts
  reg_act(:dictation_toggle, proc { dictation_toggle },
          "Voice dictation: start/stop real-time dictation")
  add_keys "dictation", { "C , k" => :dictation_toggle }
  vma.gui.menu.add_module_action(:dictation_toggle, "Start/Stop Dictation")
end

def dictation_disable
  dictation_session.stop if $vma_dict_session&.active?
  $vma_dictation_worker&.stop
  unreg_act(:dictation_toggle)
  unbindkey "C , k"
  vma.gui.menu.remove_module_action(:dictation_toggle)
end
