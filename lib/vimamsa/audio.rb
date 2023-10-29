require "gstreamer"

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
  end
end
