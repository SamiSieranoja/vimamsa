#!/usr/bin/env ruby
# Records the README demo animation (img/demo.gif) on this machine:
# runs the editor from this checkout on a hidden X display (Xvfb, so the
# desktop isn't disturbed), types the keys in demo_steps.txt with xdotool
# (real key events, so the key log panel shows them), records the window with
# ffmpeg and converts the video to an optimized GIF.
#
#   ruby scripts/demo/record_demo.rb [--speed 0.7] [--out img/demo.gif] [--keep] [--frame]
#     --speed  playback speed: every delay and wait in demo_steps.txt is
#              divided by it (1 = as written, 0.5 = twice as slow).
#              Default 0.7.
#     --keep   also keep the lossless video (build/demo/demo.mkv)
#     --frame  run the steps up to the easy jump label without recording and
#              save that moment as build/demo/frame.png, to pick the label
#
# Needs: Xvfb, xdotool, ffmpeg, gifsicle.
require "fileutils"
require "tmpdir"
require "optparse"

ROOT = File.expand_path("../..", __dir__)
DIR = __dir__
WIDTH, HEIGHT = 960, 600
FPS = 15
GIF_FPS = 12
# The label easy jump gives the line to jump to (find it with --frame)
JUMP_LABEL = %w[f s]

opts = { out: File.join(ROOT, "img/demo.gif"), keep: false, frame: false, speed: 0.7 }
OptionParser.new { |o|
  o.on("--speed FACTOR", Float) { |v| opts[:speed] = v }
  o.on("--out PATH") { |v| opts[:out] = File.expand_path(v) }
  o.on("--keep") { opts[:keep] = true }
  o.on("--frame") { opts[:frame] = true }
}.parse!
abort "--speed must be > 0" unless opts[:speed] > 0
SPEED = opts[:speed]

%w[Xvfb xdotool ffmpeg gifsicle].each { |t|
  abort "#{t} not found (sudo apt install xvfb xdotool ffmpeg gifsicle)" unless system("which #{t} >/dev/null")
}

WORK = File.join(ROOT, "build/demo")
FileUtils.mkdir_p(WORK)
pids = []
at_exit { pids.reverse_each { |pid| Process.kill("TERM", pid) rescue nil; Process.wait(pid) rescue nil } }

def sh!(*cmd)
  system(*cmd) or abort "failed: #{cmd.join(" ")}"
end

# ── Hidden X display. The editor's first-start size is 90% of the screen, so
# this screen gives a WIDTH x HEIGHT window. ──
display = (90..99).find { |n| !File.exist?("/tmp/.X#{n}-lock") } or abort "no free X display"
disp = ":#{display}"
screen = "#{(WIDTH / 0.9).ceil}x#{(HEIGHT / 0.9).ceil}x24"
pids << spawn("Xvfb", disp, "-screen", "0", screen, "-nolisten", "tcp", out: File::NULL, err: File::NULL)
sleep 0.2 until File.exist?("/tmp/.X11-unix/X#{display}")

env = { "DISPLAY" => disp, "GDK_BACKEND" => "x11", "WAYLAND_DISPLAY" => nil,
        "GTK_THEME" => nil, "NO_AT_BRIDGE" => "1" }

# ── The editor, with a throwaway config dir: default settings plus the key
# log panel, and nothing read from or written to the user's own config ──
ud = Dir.mktmpdir("vma-demo")
at_exit { FileUtils.rm_rf(ud) }
File.write(File.join(ud, "custom.rb"), <<~RUBY)
  cnf.lsp.enabled = false
  def hook_custom_after_init
    vma.gui.toggle_keylog_panel
  end
RUBY
# A short path for the title bar
demo_dir = "/tmp/vimamsa-demo"
FileUtils.rm_rf(demo_dir)
FileUtils.mkdir_p(demo_dir)
at_exit { FileUtils.rm_rf(demo_dir) }
file = File.join(demo_dir, "shapes.rb")
FileUtils.cp(File.join(DIR, "shapes.rb"), file)
pids << spawn(env, RbConfig.ruby, File.join(ROOT, "exe/vimamsa"), "--user-dir", ud, file,
              chdir: demo_dir, out: File.join(WORK, "editor.log"), err: [:child, :out])

def xdo(env, *args)
  out = IO.popen(env, ["xdotool", *args], err: File::NULL, &:read)
  $?.success? ? out : nil
end

win = nil
60.times {
  win = xdo(env, "search", "--onlyvisible", "--name", "^Vimamsa")&.split&.last
  break if win
  sleep 0.5
}
abort "editor window did not appear (log: #{WORK}/editor.log)" unless win
sleep 3 # first layout, highlighting, key log panel
xdo(env, "windowfocus", "--sync", win)
geo = xdo(env, "getwindowgeometry", "--shell", win).scan(/(\w+)=(\d+)/).to_h.transform_values(&:to_i)
x, y = geo["X"], geo["Y"]
w, h = geo["WIDTH"] & ~1, geo["HEIGHT"] & ~1 # even sizes for the encoder
puts "window #{w}x#{h} at #{x},#{y}"

# Editor key names to xdotool keysyms
KEYSYMS = { "ctrl" => "Control_L", "esc" => "Escape", "enter" => "Return", "space" => "space", "tab" => "Tab",
            "backspace" => "BackSpace", "$" => "dollar", "0" => "0" }
def press(env, key)
  k = key.sub(/\Actrl-/, "ctrl+").sub(/\Ashift-/, "shift+")
  k = KEYSYMS.fetch(k, k)
  xdo(env, "key", "--clearmodifiers", k) or abort "xdotool key #{k} failed"
end

def grab_png(disp, x, y, w, h, png)
  sh!("ffmpeg", "-loglevel", "error", "-y", "-f", "x11grab", "-video_size", "#{w}x#{h}",
      "-draw_mouse", "0", "-i", "#{disp}+#{x},#{y}", "-frames:v", "1", png)
end

# Runs demo_steps.txt. With stop_at_label, returns just before the easy
# jump label would be typed.
def run_steps(env, stop_at_label: false)
  delay = 0.4 / SPEED
  File.readlines(File.join(DIR, "demo_steps.txt"), chomp: true).each { |line|
    line = line.sub(/\s+#\s.*\z/, "") unless line.start_with?("type ")
    next if line.strip.empty? || line.start_with?("#")
    cmd, arg = line.split(" ", 2)
    case cmd
    when "wait" then sleep arg.to_f / SPEED
    when "delay" then delay = arg.to_f / SPEED
    when "keys"
      keys = arg.split
      return if stop_at_label && keys.include?("@JUMP_LABEL@")
      keys = keys.flat_map { |k| k == "@JUMP_LABEL@" ? JUMP_LABEL : [k] }
      keys.each { |k| press(env, k); sleep delay }
    when "type"
      arg.each_char { |c|
        xdo(env, "type", "--delay", "0", c) or abort "xdotool type failed"
        sleep delay
      }
    else abort "demo_steps.txt: unknown command #{line.inspect}"
    end
  }
end

if opts[:frame]
  run_steps(env, stop_at_label: true)
  png = File.join(WORK, "frame.png")
  grab_png(disp, x, y, w, h, png)
  puts "saved #{png}"
  exit
end

# ── Record ──
video = File.join(WORK, "demo.mkv")
rec = spawn("ffmpeg", "-loglevel", "warning", "-nostdin", "-y", "-f", "x11grab", "-framerate", FPS.to_s,
            "-video_size", "#{w}x#{h}", "-draw_mouse", "0", "-i", "#{disp}+#{x},#{y}",
            "-c:v", "libx264rgb", "-crf", "0", "-preset", "ultrafast", video)
sleep 0.5
run_steps(env)
Process.kill("INT", rec)
Process.wait(rec)
# ffmpeg exits 255 when stopped with INT; anything else is an error
abort "recording failed (ffmpeg exit #{$?.exitstatus})" unless [0, 255].include?($?.exitstatus)
system("ffmpeg", "-v", "error", "-i", video, "-f", "null", "-", err: File.join(WORK, "decode.log"))
abort "the recorded video is damaged: #{File.read(File.join(WORK, "decode.log"))[0, 300]}" unless File.size(File.join(WORK, "decode.log")).zero?

# ── GIF: one palette for the whole clip, only changed rectangles stored ──
palette = File.join(WORK, "palette.png")
filters = "fps=#{GIF_FPS}"
sh!("ffmpeg", "-loglevel", "error", "-y", "-i", video,
    "-vf", "#{filters},palettegen=max_colors=128:stats_mode=diff", palette)
raw_gif = File.join(WORK, "demo_raw.gif")
sh!("ffmpeg", "-loglevel", "error", "-y", "-i", video, "-i", palette, "-lavfi",
    "#{filters}[v];[v][1:v]paletteuse=dither=none:diff_mode=rectangle", raw_gif)
FileUtils.mkdir_p(File.dirname(opts[:out]))
sh!("gifsicle", "-O3", "--lossy=30", "-o", opts[:out], raw_gif)
FileUtils.rm_f([palette, raw_gif])
FileUtils.rm_f(video) unless opts[:keep]
dur = IO.popen(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", opts[:out]], &:read).to_f
puts "wrote #{opts[:out]} at speed #{SPEED} (#{(File.size(opts[:out]) / 1024.0 / 1024).round(2)} MB, #{dur.round(1)} s)"
