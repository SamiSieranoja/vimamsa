require "fileutils"

module Vimamsa

def debug(message, severity = 1)
  if cnf.debug?
    if severity > 1
      # Add red colour and bold for attention
      # https://en.wikipedia.org/wiki/ANSI_escape_code
      message = "\033[1;31m!!! \033[0m#{message}"
    end
    puts "[#{DateTime.now().strftime("%H:%M:%S")}] #{message}"
    $stdout.flush
  end
end

def debug_print_buffer(_c = nil)
  puts buf.inspect
  puts buf
end

def debug_dump_clipboard()
  puts vma.clipboard.inspect
end

def debug_dump_deltas()
  puts buf.edit_history.inspect
end

$log_messages = []

def log_message(message, vlevel = 1)
  puts message if conf("log.verbose") >= vlevel
  $log_messages << message
end

def log_error(message)
  puts "====== ERROR ====="
  puts caller[0]
  puts message
  puts "=================="
  $errors << [message, caller]
end

def show_caller
  puts caller().join("\n")
end


def crash(message, e = nil)
  puts "FATAL ERROR:#{message}"
  puts caller().join("\n")
  CrashHandler.report("fatal", e, message)
  _quit()
end

def savedebug(message, e)
  FileUtils.mkdir_p("debug")
  puts "savedebug()"
  dbginfo = {}
  dbginfo["message"] = message
  dbginfo["debuginfo"] = $debuginfo
  dbginfo["trace"] = caller()
  dbginfo["trace"] = e.backtrace() if e
  dbginfo["trace_str"] = dbginfo["trace"].join("\n")
  dbginfo["edit_history"] = buf.edit_history
  dbginfo["cnf"] = $vimamsa_conf
  dbginfo["register"] = vma.registers.to_h
  dbginfo["clipboard"] = vma.clipboard
  # dbginfo["last_event"] = $last_event
  dbginfo["buffer"] = {}
  dbginfo["buffer"]["str"] = buf.to_s
  dbginfo["buffer"]["lpos"] = buf.lpos
  dbginfo["buffer"]["cpos"] = buf.cpos
  dbginfo["buffer"]["pos"] = buf.pos

  pfxs = DateTime.now().strftime("%d%m%Y_%H%M%S")
  save_fn_dump = sprintf("debug/crash_%s.marshal", pfxs)
  save_fn_json = sprintf("debug/crash_%s.json", pfxs)
  mdump = Marshal.dump(dbginfo)
  IO.binwrite(save_fn_dump, mdump)
  IO.write(save_fn_json, dbginfo.to_json)
  puts "SAVED CRASH INFO TO:"
  puts save_fn_dump
  puts save_fn_json
end


def start_ripl
  Ripl.start :binding => binding
end
end # module Vimamsa
