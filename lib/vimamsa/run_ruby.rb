require "open3"
require "tempfile"

module Vimamsa
# buf.run.ruby: runs the current file with Ruby and shows what it printed in
# a buffer. A separate process, not eval: a script can't hang, crash or
# change the editor, and it runs as it would from a terminal (its own
# __FILE__, require_relative, exit). Output and errors come in the order
# printed (stdout and stderr together), so a backtrace's file:line lines can
# be followed with enter. The file is saved first if it has changes; a buffer
# without a file runs from a temporary copy.

# The Ruby to run scripts with: `ruby` on the PATH (the user's, with their
# gems), else the editor's own
def script_ruby
  ENV["PATH"].to_s.split(File::PATH_SEPARATOR).map { |d| File.join(d, "ruby") }
    .find { |f| File.executable?(f) && !File.directory?(f) } || RbConfig.ruby
end

def run_buffer_as_ruby(b = vma.buf)
  return message("No buffer to run") if b.nil?
  tmp = nil
  if b.fname
    b.save if b.unsaved_changes?
    path = b.fname
  else
    tmp = Tempfile.new(["vimamsa-run", ".rb"])
    tmp.write(b.to_s)
    tmp.close
    path = tmp.path
  end
  dir = File.dirname(path)
  name = b.fname ? File.basename(path) : b.title.to_s
  message("Running #{name} with Ruby...")
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Thread.new {
    begin
      # stdout unbuffered (it is a pipe here), so output and errors come in
      # the order printed; load keeps the script's __FILE__ and $0
      out, st = Open3.capture2e(script_ruby, "-e", "STDOUT.sync = true; $0 = ARGV[0]; load ARGV.shift", path, chdir: dir)
    rescue => e
      out, st = "#{e.class}: #{e.message}\n", nil
    end
    secs = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
    tmp&.unlink
    GLib::Idle.add {
      show_ruby_output(b.fname || name, out, st, secs)
      false
    }
  }
end

# The output in a buffer (the previous output of the same file is replaced)
def show_ruby_output(name, out, status, secs)
  vma.buffers.list.select { |x| x.instance_variable_get(:@ruby_output_of) == name }
    .each { |x| vma.buffers.close_buffer(x.id) }
  code = status ? status.exitstatus : "-"
  head = "# ruby #{name} (exit #{code}, #{format("%.2f", secs)} s)\n\n"
  ob = create_new_buffer(head + (out.empty? ? "(no output)\n" : out), "ruby-output")
  ob.instance_variable_set(:@ruby_output_of, name)
  message(status&.success? ? "Ruby: done" : "Ruby: exit status #{code}")
  ob
end
end # module Vimamsa
