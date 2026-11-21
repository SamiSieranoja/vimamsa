# Helpers shared by the project's Ruby scripts (run_tests_vm.rb, ...).
# Standard library only: the scripts run before any gems are installed.
require "open3"

module ScriptHelpers
  module_function

  # Print a step, as ">> msg"
  def step(msg)
    puts ">> #{msg}"
    $stdout.flush
  end

  # Print an error, as "!! msg" (more lines indented), and exit with code
  def fail!(msg, code = 1)
    lines = msg.to_s.lines.map(&:chomp)
    warn "!! #{lines.first}"
    lines.drop(1).each { |l| warn "   #{l}" }
    exit code
  end

  # Run a command; on failure, exit with a message. label: what to call the
  # command in the message (never the arguments, which may hold secrets).
  def run!(*cmd, label: cmd.first, code: 1, **opts)
    system(*cmd, **opts) || fail!("#{label} failed (exit #{$?.exitstatus})", code)
  end

  # Run a command, printing its output (stdout and stderr) as it comes, and
  # return [output, Process::Status]
  def run_streaming(*cmd)
    out = +""
    status = nil
    Open3.popen2e(*cmd) { |stdin, oe, thr|
      stdin.close
      begin
        loop {
          chunk = oe.readpartial(4096)
          $stdout.write(chunk)
          $stdout.flush
          out << chunk
        }
      rescue EOFError
      end
      status = thr.value
    }
    [out, status]
  end

  # The names of the environment variables that are unset or empty
  def missing_env(*names)
    names.select { |n| ENV[n].to_s.empty? }
  end
end
