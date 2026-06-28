require "open3"
require "json"

# Text-to-Speech module
#
# Select text (visual mode) and activate to hear it spoken aloud with Piper TTS.
# Mirrors ~/Drive/util/bin/speak.rb: piper --output-raw | aplay, with the sample
# rate auto-detected from the voice's .onnx.json. Playback runs in a background
# thread so the editor stays responsive, and can be stopped.
#
#   V , s   speak the current selection
#   C , q   stop speaking
#
# Configuration (set in ~/.vimamsa/settings.rb via cnf, all optional):
#   cnf.tts.voice      Piper voice name   (default "en_GB-alan-medium")
#   cnf.tts.data_dir   voices directory    (default "~/piper-voices")
#   cnf.tts.rate       sample rate (Hz)    (default: from <voice>.onnx.json, else 22050)
#
# Requires piper and aplay on PATH and a Piper voice installed in data_dir.

class VmaTts
  def initialize
    @mutex = Mutex.new
    @pids = []
  end

  # Speak `text` aloud. Cancels any current playback first. Non-blocking.
  def speak(text)
    return if text.nil? || text.strip.empty?
    unless which("piper") && which("aplay")
      message("TTS: need 'piper' and 'aplay' on PATH")
      return
    end
    stop  # one utterance at a time

    voice    = cnf.tts.voice! || "en_GB-alan-medium"
    data_dir = File.expand_path(cnf.tts.data_dir! || "~/piper-voices")
    rate     = (cnf.tts.rate! || detect_rate(data_dir, voice) || 22050).to_s

    piper  = ["piper", "-m", voice, "--data-dir", data_dir, "--output-raw"]
    player = ["aplay", "-q", "-r", rate, "-f", "S16_LE", "-t", "raw", "-"]

    Thread.new do
      begin
        stdin, threads = Open3.pipeline_w(piper, player)
        @mutex.synchronize { @pids = threads.map(&:pid) }
        stdin.write(text)
        stdin.close
        threads.each(&:join)
      rescue => e
        GLib::Idle.add { message("TTS error: #{e.message}"); false }
      ensure
        @mutex.synchronize { @pids = [] }
      end
    end
  end

  # Stop any in-progress playback.
  def stop
    @mutex.synchronize do
      @pids.each { |pid| Process.kill("TERM", pid) rescue nil }
      @pids = []
    end
  end

  private

  # Read the voice's preferred sample rate from <data_dir>/<voice>.onnx.json.
  def detect_rate(data_dir, voice)
    cfg = File.join(data_dir, "#{voice}.onnx.json")
    return nil unless File.exist?(cfg)
    JSON.parse(File.read(cfg)).dig("audio", "sample_rate")
  rescue
    nil
  end
end

def tts_engine
  $vma_tts ||= VmaTts.new
end

def tts_speak_selection
  unless vma.buf.visual_mode?
    message("TTS: select text first")
    return
  end
  r = vma.buf.get_visual_mode_range
  text = vma.buf[r]
  vma.buf.end_visual_mode
  if text.nil? || text.strip.empty?
    message("TTS: nothing selected")
    return
  end
  tts_engine.speak(text)
  message("TTS: speaking…")
end

def tts_stop
  $vma_tts&.stop
  message("TTS: stopped")
end

def tts_init
  reg_act(:tts_speak_selection, proc { tts_speak_selection }, "Speak selected text")
  reg_act(:tts_stop, proc { tts_stop }, "Stop speaking")
  add_keys "tts", { "V , s" => :tts_speak_selection, "C , q" => :tts_stop }
  vma.gui.menu.add_module_action(:tts_speak_selection, "Speak Selection")
  vma.gui.menu.add_module_action(:tts_stop, "Stop Speaking")
end

def tts_disable
  $vma_tts&.stop
  unreg_act(:tts_speak_selection)
  unreg_act(:tts_stop)
  unbindkey "V , s"
  unbindkey "C , q"
  vma.gui.menu.remove_module_action(:tts_speak_selection)
  vma.gui.menu.remove_module_action(:tts_stop)
end
