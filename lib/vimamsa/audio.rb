require "gstreamer"

class File
  def self.exists?(fn)
    File.exist?(fn)
  end
end

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

