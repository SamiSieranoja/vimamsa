require 'fileutils'

def debug_print_buffer(c)
  puts $buffer.inspect
  puts $buffer
end

def debug_dump_clipboard()
  puts $clipboard.inspect
end

def debug_dump_deltas()
  puts $buffer.edit_history.inspect
end

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
  # dbginfo["last_event"] = $last_event
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


def run_tests()
  run_test("01")
  run_test("02")
end

def run_test(test_id)
  target_results = read_file("", "tests/test_#{test_id}_output.txt")
  old_buffer = $buffer
  $buffer = Buffer.new("", "")
  load "tests/test_#{test_id}.rb"
  test_ok = $buffer.to_s.strip == target_results.strip
  puts "##################"
  puts target_results
  puts "##################"
  puts $buffer.to_s
  puts "##################"
  puts "TEST OK" if test_ok
  puts "TEST FAILED" if !test_ok
  puts "##################"
  $buffer = old_buffer
end

def start_ripl
  Ripl.start :binding => binding
end

