#!/usr/bin/env ruby
# Records a demo as an animation (default: the README's img/demo.gif) on
# this machine: runs the editor from this checkout on a hidden X display
# (Xvfb, so the desktop isn't disturbed), lets the editor's own demo player
# (lib/vimamsa/demo_player.rb) play the steps file, records the window with
# ffmpeg and converts the video to an optimized GIF. The player feeds the
# keys to the key bindings as if typed (the key log panel shows them), finds
# easy jump labels for this window, and types into forms and list windows.
#
#   ruby scripts/demo/record_demo.rb [STEPS] [--speed 0.7] [--out img/demo.gif] [--keep]
#     STEPS    the steps file (default scripts/demo/demo_steps.txt), e.g.
#              scripts/demo/square/steps.txt or a recorded demo in
#              ~/.config/vimamsa/demos/<name>/steps.txt. Its files ("file"
#              lines, default shapes.rb) are taken from its folder.
#     --speed  playback speed: every delay and wait in the steps file is
#              divided by it (1 = as written, 0.5 = twice as slow).
#              Default 0.7, as the editor's Help > Demos at 1x.
#     --size   the editor window's size, WIDTHxHEIGHT (default 960x600). A
#              smaller window shows fewer lines: easy jump targets off
#              screen are reached without a label.
#     --keep   also keep the lossless video (build/demo/demo.mkv)
#
# Needs: Xvfb, xdotool, ffmpeg, gifsicle.
require "fileutils"
require "tmpdir"
require "optparse"

ROOT = File.expand_path("../..", __dir__)
DIR = __dir__
FPS = 15
GIF_FPS = 12
opts = { out: File.join(ROOT, "img/demo.gif"), keep: false, speed: 0.7, size: "960x600" }
OptionParser.new { |o|
  o.on("--speed FACTOR", Float) { |v| opts[:speed] = v }
  o.on("--size WxH") { |v| opts[:size] = v }
  o.on("--out PATH") { |v| opts[:out] = File.expand_path(v) }
  o.on("--keep") { opts[:keep] = true }
}.parse!
abort "--speed must be > 0" unless opts[:speed] > 0
SPEED = opts[:speed]
WIDTH, HEIGHT = opts[:size].split("x").map(&:to_i)
abort "--size must be WIDTHxHEIGHT, e.g. 960x600" unless WIDTH.to_i > 0 && HEIGHT.to_i > 0
STEPS = File.expand_path(ARGV[0] || File.join(DIR, "demo_steps.txt"))
abort "steps file not found: #{STEPS}" unless File.file?(STEPS)
SRC = File.dirname(STEPS)
FILES = File.readlines(STEPS, chomp: true).filter_map { |l| l[/\Afile\s+(\S+)/, 1] }
FILES << "shapes.rb" if FILES.empty?
FILES.each { |f| abort "#{f} (a file of the demo) not found in #{SRC}" unless File.file?(File.join(SRC, f)) }

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

# ── The editor, with a throwaway config dir: default settings, no intro
# page, nothing read from or written to the user's own config. Its
# custom.rb plays the demo once ready + go (files in the config dir), then
# writes done and quits. ──
ud = Dir.mktmpdir("vma-demo")
at_exit { FileUtils.rm_rf(ud) }
ready, go, done = %w[ready go done].map { |f| File.join(ud, f) }
demo = { steps: STEPS, files: FILES, src: SRC }
File.write(File.join(ud, "custom.rb"), <<~RUBY)
  cnf.lsp.enabled = false
  cnf.intro.show_on_startup = false
  def hook_custom_after_init
    vma.gui.show_keylog_panel
    File.write(#{ready.inspect}, "1")
    GLib::Timeout.add(100) {
      next true if !File.exist?(#{go.inspect})
      DemoPlayer.new(:recording, demo: #{demo.inspect}, speed: #{SPEED}, rate: 1, loop: false, controls: false,
                     on_finish: proc { |msg|
                       # written whole, then renamed: the script never reads it half done
                       File.write(#{(done + ".tmp").inspect}, msg.to_s)
                       File.rename(#{(done + ".tmp").inspect}, #{done.inspect})
                       GLib::Timeout.add(1000) { vma.shutdown; false }
                     }).start
      false
    }
  end
RUBY
editor = spawn(env, RbConfig.ruby, File.join(ROOT, "exe/vimamsa"), "--user-dir", ud,
               chdir: "/tmp", out: File.join(WORK, "editor.log"), err: [:child, :out])
pids << editor

def xdo(env, *args)
  out = IO.popen(env, ["xdotool", *args], err: File::NULL, &:read)
  $?.success? ? out : nil
end

win = nil
60.times {
  win = xdo(env, "search", "--onlyvisible", "--name", "^Vimamsa")&.split&.last
  break if win && File.exist?(ready)
  sleep 0.5
}
abort "editor window did not appear (log: #{WORK}/editor.log)" unless win && File.exist?(ready)
sleep 2 # first layout, highlighting, key log panel
xdo(env, "windowfocus", "--sync", win)
geo = xdo(env, "getwindowgeometry", "--shell", win).scan(/(\w+)=(\d+)/).to_h.transform_values(&:to_i)
x, y = geo["X"], geo["Y"]
w, h = geo["WIDTH"] & ~1, geo["HEIGHT"] & ~1 # even sizes for the encoder
puts "window #{w}x#{h} at #{x},#{y}; playing #{STEPS}"

# ── Record ──
video = File.join(WORK, "demo.mkv")
rec = spawn("ffmpeg", "-loglevel", "warning", "-nostdin", "-y", "-f", "x11grab", "-framerate", FPS.to_s,
            "-video_size", "#{w}x#{h}", "-draw_mouse", "0", "-i", "#{disp}+#{x},#{y}",
            "-c:v", "libx264rgb", "-crf", "0", "-preset", "ultrafast", video)
sleep 0.5
File.write(go, "1")
t = Time.now
sleep 0.2 until File.exist?(done) || Process.waitpid(editor, Process::WNOHANG) || Time.now - t > 1800
msg = File.exist?(done) ? File.read(done) : "editor quit or timed out (log: #{WORK}/editor.log)"
sleep 0.8 # the end state on screen for a moment
Process.kill("INT", rec)
Process.wait(rec)
abort "the demo didn't finish: #{msg}" unless msg == "Demo finished"
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
