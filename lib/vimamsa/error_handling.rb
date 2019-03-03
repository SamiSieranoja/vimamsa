require 'fileutils'

def log_error(message)
  puts "====== ERROR ====="
  puts caller[0]
  puts message
  puts "=================="
  $errors << [message, caller]
  #TODO
end

def crash(message,e=nil)
  puts "FATAL ERROR:#{message}"
  puts caller().join("\n")
  savedebug(message,e)
  _quit()
end

def savedebug(message,e)
  FileUtils.mkdir_p('debug')
  puts "savedebug()"
  dbginfo = {}
  dbginfo["message"] = message
  dbginfo["debuginfo"] = $debuginfo
  dbginfo["trace"] = caller()
  dbginfo["trace"] = e.backtrace() if e
  dbginfo["trace_str"] = dbginfo["trace"].join("\n")
  dbginfo["edit_history"] = $buffer.edit_history
  dbginfo["cnf"] = $cnf
  dbginfo["register"] = $register
  dbginfo["clipboard"] = $clipboard
  dbginfo["last_event"] = $last_event
  dbginfo["buffer"] = {}
  dbginfo["buffer"]["str"] = $buffer.to_s
  dbginfo["buffer"]["lpos"] = $buffer.lpos
  dbginfo["buffer"]["cpos"] = $buffer.cpos
  dbginfo["buffer"]["pos"] = $buffer.pos

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
