require "fileutils"
require "json"

module Vimamsa

# Captures debug information when the editor crashes.
#
# Two kinds of crash are handled:
#   * Ruby exceptions that reach the top level (uncaught) — a structured
#     report (backtrace + editor state snapshot) is written.
#   * Native crashes / segfaults (from the C extension, GTK, etc.) — these
#     kill the process before any Ruby handler can run, so we tee the process
#     stderr (where Ruby prints its native crash dump) into a persistent log.
#
# Reports go to ~/.config/vimamsa/crash/ .
module CrashHandler
  @installed = false

  def self.crash_dir
    dir = get_dot_path("crash")
    FileUtils.mkdir_p(dir)
    dir
  end

  # Install stderr capture + at_exit hook. Safe to call once, early in startup.
  def self.setup
    return if @installed
    @installed = true
    capture_stderr
    install_at_exit
  rescue => e
    # Never let crash-handler setup itself take down startup.
    warn "CrashHandler.setup failed: #{e}"
  end

  # Redirect the real stderr fd through `tee` so native crash dumps (which are
  # written to fd 2 by Ruby's own SIGSEGV handler) are saved to a file while
  # still showing on the console.
  def self.capture_stderr
    log = File.join(crash_dir, "stderr.log")
    return unless which("tee")
    tee = IO.popen(["tee", "-a", log], "w")
    banner = "\n===== vimamsa session start #{Time.now.strftime("%Y-%m-%d %H:%M:%S")} (pid #{Process.pid}) =====\n"
    tee.write(banner)
    tee.flush
    $stderr.reopen(tee)
    $stderr.sync = true
  rescue => e
    warn "CrashHandler.capture_stderr failed: #{e}"
  end

  def self.install_at_exit
    at_exit do
      e = $!
      # Only report abnormal termination (an unhandled exception), not a
      # clean quit or a plain SystemExit(0).
      if e && !(e.is_a?(SystemExit) && e.success?)
        report("exception", e)
      end
    end
  end

  # Write a structured crash report. Every field is best-effort: a failure to
  # collect one part must not prevent writing the rest.
  def self.report(kind, exception = nil, extra = nil)
    info = {}
    info["kind"] = kind
    info["time"] = Time.now.strftime("%Y-%m-%d %H:%M:%S")
    info["pid"] = Process.pid
    info["ruby"] = RUBY_DESCRIPTION
    info["extra"] = extra if extra

    if exception
      info["exception"] = "#{exception.class}: #{exception.message}"
      info["backtrace"] = (exception.backtrace || [])
    else
      info["backtrace"] = caller
    end

    add(info, "last_action") { vma.actions.last_action }
    add(info, "log_messages") { $log_messages.last(50) }
    add(info, "errors") { $errors.last(20) }
    add(info, "buffer") {
      b = buf
      { "fname" => b.fname, "pos" => b.pos, "lpos" => b.lpos, "cpos" => b.cpos,
        "size" => b.size, "str_head" => b.to_s[0, 4000] }
    }
    add(info, "open_files") { vma.buffers.list.map { |b| b.fname }.compact }

    ts = Time.now.strftime("%Y%m%d_%H%M%S")
    base = File.join(crash_dir, "crash_#{ts}_#{Process.pid}")
    write_file("#{base}.txt", format_text(info))
    write_file("#{base}.json", safe_json(info))

    warn "vimamsa: crash report saved to #{base}.txt"
    base
  rescue => e
    warn "CrashHandler.report failed: #{e}"
    nil
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  def self.add(info, key)
    info[key] = yield
  rescue => e
    info[key] = "<unavailable: #{e.class}>"
  end

  def self.format_text(info)
    out = []
    out << "kind:      #{info["kind"]}"
    out << "time:      #{info["time"]}"
    out << "pid:       #{info["pid"]}"
    out << "ruby:      #{info["ruby"]}"
    out << "exception: #{info["exception"]}" if info["exception"]
    out << "last_action: #{info["last_action"].inspect}"
    out << ""
    out << "--- backtrace ---"
    out.concat(Array(info["backtrace"]))
    out << ""
    out << "--- open files ---"
    out.concat(Array(info["open_files"]))
    out << ""
    out << "--- current buffer ---"
    out << info["buffer"].inspect
    out << ""
    out << "--- recent log messages ---"
    out.concat(Array(info["log_messages"]).map(&:to_s))
    out << ""
    out << "--- recent errors ---"
    out.concat(Array(info["errors"]).map(&:inspect))
    out.join("\n") + "\n"
  end

  def self.safe_json(info)
    JSON.pretty_generate(info)
  rescue
    # Fall back to inspecting values that can't be serialized cleanly.
    JSON.pretty_generate(info.transform_values { |v| v.is_a?(String) ? v : v.inspect })
  end

  def self.write_file(path, content)
    IO.write(path, content)
  rescue => e
    warn "CrashHandler: could not write #{path}: #{e}"
  end
end
end # module Vimamsa
