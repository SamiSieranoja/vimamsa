require "securerandom"
require "fileutils"

module Vimamsa
# vimamsa --wait FILE: open FILE and don't return until its buffer is closed,
# so the editor works as $GIT_EDITOR / core.editor ("vimamsa --wait").
#
# The launcher (exe/vimamsa) makes a marker file in the data dir's "wait" dir
# and waits for it to go away. The editor deletes the marker when the buffer is
# closed, or when the editor quits. Two ways the editor learns of the marker:
#  - an editor is already running: the listen request (see
#    Editor#open_file_listener) starts with a "#vma-wait MARKER" line, and the
#    file paths after it are waited on.
#  - no editor running: the launcher starts one in the background with
#    "--wait-marker MARKER FILE", and the ARGV file is waited on.
# Once it has the marker, the editor writes its pid into it, so the launcher
# can stop waiting (with an error) if the editor dies.
#
# Loaded by exe/vimamsa before the rest (launcher side), and from rbvma.rb.
module WaitFiles
  HEADER = "#vma-wait "

  module_function

  # ── Launcher side ────────────────────────────────────────────────────────

  def create_marker(data_dir)
    dir = File.join(data_dir, "wait")
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "wait_#{Process.pid}_#{SecureRandom.hex(6)}")
    File.write(path, "")
    path
  end

  # Text for a listen request that opens paths and waits on them
  def request_text(paths, marker)
    "#{HEADER}#{marker}\n" + paths.map { |p| "#{p}\n" }.join
  end

  # Block while the marker exists. Returns true when the editor released it,
  # false when the editor that took it is no longer running.
  def wait_for_release(marker, poll: 0.1)
    while File.exist?(marker)
      pid = (File.read(marker).strip rescue "")
      return false if pid =~ /\A\d+\z/ && !pid_alive?(pid.to_i)
      sleep poll
    end
    true
  end

  def pid_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true
  end

  # ── Editor side ──────────────────────────────────────────────────────────

  # Split a listen request into [[path, marker or nil], ...]. Paths after a
  # "#vma-wait MARKER" line are waited on with that marker.
  def parse_request(text)
    marker = nil
    out = []
    text.each_line do |l|
      l = l.chomp
      next if l.empty?
      if l.start_with?(HEADER)
        marker = l[HEADER.size..].strip
        marker = nil if marker.empty?
      else
        out << [l, marker]
      end
    end
    out
  end

  # buffer id => [marker, ...]
  def waiting
    @waiting ||= {}
  end

  # Wait on marker until buffer bu is closed
  def watch(bu, marker)
    return if bu.nil? || marker.nil?
    File.write(marker, Process.pid.to_s) if File.exist?(marker)
    (waiting[bu.id] ||= []) << marker unless waiting[bu.id]&.include?(marker)
    message("Close the buffer when done (another program is waiting for it)")
  end

  # The launcher is told the editor is done with this file
  def release(marker)
    File.delete(marker) if File.exist?(marker)
  rescue SystemCallError
    nil
  end

  # hook :buffer_closed
  def buffer_closed(bu)
    return if bu.nil?
    (waiting.delete(bu.id) || []).each { |m| release(m) }
  end

  # hook :shutdown: nothing is waited on past the editor's life
  def release_all
    waiting.each_value { |ms| ms.each { |m| release(m) } }
    waiting.clear
  end

  def init
    vma.hook.register(:buffer_closed, method(:buffer_closed))
    vma.hook.register(:shutdown, method(:release_all))
  end
end
end
