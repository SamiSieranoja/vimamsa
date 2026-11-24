require "gstreamer"

# Audio playback module
#
# Plays audio files linked from hyper plaintext (.txt) files as ⟦audio:path⟧:
# following the link (as with other ⟦…⟧ links) plays it with GStreamer.
# Disabled by default: enable it in Settings ▸ Modules ▸ "Audio Playback" or
# with `cnf.modules.audio.enabled = true` (the old `cnf.audio.enabled` also works).
#
#   C , m a   -> audio mode:  f / right  seek forward 5 s,  left  back 5 s,
#                              space / s  stop,  q / esc  leave the mode
#   C , u s   -> stop playback

module Vimamsa

# following the example gstreamer-4.2.0/sample/helloworld_e.rb
class Audio
  @@playbin = nil

  def self.stop
    @@playbin.stop if !@@playbin.nil?
  end

  def self.play(fn)
    playbin = @@playbin
    if playbin.nil?
      playbin = Gst::ElementFactory.make("playbin")
      if playbin.nil?
        puts "'playbin' gstreamer plugin missing"
        return
      end
    else
      if playbin.current_state == "playing"
        playbin.stop # Stop previous play
      end
    end

    # playbin.seek(10.0)

    # playbin.volume
    # playbin.volume=1.0
    # playbin.stream_time
    # playbin.current_state

    # take the commandline argument and ensure that it is a uri
    if Gst.valid_uri?(fn)
      uri = fn
    else
      uri = Gst.filename_to_uri(fn)
    end
    playbin.uri = uri
    @@playbin = playbin
    $pb = playbin

    bus = playbin.bus
    bus.add_watch do |bus, message|
      case message.type
      when Gst::MessageType::EOS
        puts "End-of-stream"
      when Gst::MessageType::ERROR
        error, debug = message.parse_error
        puts "Debugging info: #{debug || "none"}"
        puts "Error: #{error.message}"
      end
      true
    end

    message("Start playing audio: #{fn}")

    # start play back and listed to events
    playbin.play
    playbin.seek_simple(Gst::Format::TIME, Gst::SeekFlags::NONE, 10.0)
  end

  def self.seek_forward(secs = 5.0)
    return if @@playbin.nil?
    if @@playbin.current_state == "playing"
      duration = @@playbin.query_duration(Gst::Format::TIME)[1]
      curpos = @@playbin.query_position(Gst::Format::TIME)[1]
      newpos = curpos + secs * 1.0e9
      newpos = 0.0 if newpos < 0
      return if newpos > duration
      @@playbin.seek_simple(Gst::Format::TIME, Gst::SeekFlags::FLUSH, newpos)
      message("New audio pos: #{(newpos / 1.0e9).round(1)}/#{(duration / 1.0e9).round(1)}")
      # $pb.query_position(Gst::Format::TIME)[1]/1.0e9
    end
  end
end

# False when GTK has no media backend: Gtk::MediaFile.new then makes a
# GtkNoMediaFile
def audio_playback_available?(mf)
  mf.class.gtype.name != "GtkNoMediaFile"
rescue StandardError
  true
end

# Inline media controls for ⟦audio:…⟧ links (hpt_scan_audio)
class Buffer < String
  # Replace char at pos with audio widget for
  def add_audio(afpath, pos)
    return if !is_legal_pos(pos)
    afpath = File.expand_path(afpath)
    return if !File.exist?(afpath)

    # GTK built without a media backend (the optional gtk-new AppImage,
    # doc/appimage_old_base_plan.md) gives a GtkNoMediaFile, which plays nothing
    mf = Gtk::MediaFile.new(afpath)
    if !audio_playback_available?(mf)
      if !$vma_audio_no_backend_told
        message("Audio playback isn't available in this build (GTK has no media backend)")
        $vma_audio_no_backend_told = true
      end
      return
    end

    vbuf = view.buffer
    itr = vbuf.get_iter_at(:offset => pos)
    itr2 = vbuf.get_iter_at(:offset => pos + 1)
    vbuf.delete(itr, itr2)
    anchor = vbuf.create_child_anchor(itr)

    mc = Gtk::MediaControls.new(mf)
    # mc = Gtk::MediaControls.new(Gtk::MediaFile.new)
    # Thread.new{mf.play;sleep 0.01; mf.pause}
    (@audiofiles ||= []) << mc

    view.add_child_at_anchor(mc, anchor)
    mc.set_size_request(500, 20)
    mc.set_margin_start(view.gutter_width + 10)

    provider = Gtk::CssProvider.new
    mc.add_css_class("medctr")

    provider.load(data: ".medctr {   background-color:#{theme_color(:medctr_bg)}; }")
    mc.style_context.add_provider(provider)

    pp mf.set_prepared(true)
    # pp mf.pause
    pp mf.duration
    pp mf.has_audio?

    # >> Gtk::MediaControls.signals
    # => ["direction-changed", "destroy", "show", "hide", "map", "unmap", "realize", "unrealize", "state-flags-changed", "mnemonic-activate", "move-focus", "keynav-failed", "query-tooltip", "notify"]

    # If this is done too early, the gutter is not yet drawn which
    # will result in wrong position
    if @audiofiles.size == 1
      run_as_idle proc { self.reset_audio_widget_positions }
    end
    $audiof = mf
  end

  #TODO: remove?
  def reset_audio_widget_positions
    debug "reset_audio_widget_positions", 2
    for mc in (@audiofiles || [])
      mc.set_size_request(500, 20)
      mc.set_margin_start(view.gutter_width + 10)
    end
    return false
  end
end

# Scan audio files inserted with ⟦audio:filepath⟧ syntax
#TODO: merge code with hpt_scan_images
def hpt_scan_audio(bf = nil)
  bf = buf() if bf.nil?
  return if bf.nil?
  return if !bf.fname
  return if !bf.fname.match(/.*txt$/)
  imgpos = scan_indexes(bf, /⟦audio:.+?⟧/)
  imgtags = bf.scan(/(⟦audio:(.+?)⟧)/)
  c = 0
  imgpos.each.with_index { |x, i|
    a = imgpos[i]
    t = imgtags[i]
    insert_pos = a + t[0].size + c
    fn = t[1]
    imgfn = translate_path(fn, bf)
    next if !File.exist?(imgfn)
    # Show as image in gui, handle as empty space in txt file

    if bf[insert_pos..(insert_pos + 2)] != "\n \n"
      bf.insert_txt_at("\n \n", insert_pos)
      bf.view.handle_deltas
      c += 3
    end
    bf.add_audio(imgfn, insert_pos + 1)
  }
  # vma.gui.delex.run #TODO:gtk4
end

def audio_init
  # Inherits command mode, like the dictation mode
  vma.kbd.add_minor_mode("audio", :audio, :command)
  reg_act("audio.stop", proc { Audio.stop }, "Stop audio playback")
  reg_act("audio.forward", proc { Audio.seek_forward }, "Seek forward in audio stream")
  reg_act("audio.backward", proc { Audio.seek_forward(-5.0) }, "Seek backward in audio stream")
  reg_act("mode.audio", proc { vma.kbd.set_mode(:audio) }, "Switch to audio playback mode")
  add_keys "audio", {
    "C , u s" => "audio.stop",
    "C , m a" => "mode.audio",
    "audio s || audio space" => "audio.stop",
    "audio f || audio right" => "audio.forward",
    "audio left" => "audio.backward",
    "audio q || audio esc" => "mode.prev",
  }
end

def audio_disable
  Audio.stop
  vma.kbd.to_previous_mode if vma.kbd.get_mode == :audio
  %w[audio.stop audio.forward audio.backward mode.audio].each { |a| unreg_act(a) }
  unbindkey "C , u s"
  unbindkey "C , m a"
  unbindkey "audio", include_child_nodes: true
end

end # module Vimamsa
