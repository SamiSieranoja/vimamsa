require "fileutils"

def debug(message, severity = 1)
  if $debug
    if severity > 1
      # Add red colour and bold for attention
      # https://en.wikipedia.org/wiki/ANSI_escape_code
      message = "\033[1;31m!!! \033[0m#{message}"
    end
    puts "[#{DateTime.now().strftime("%H:%M:%S")}] #{message}"
    $stdout.flush
  end
end

def debug_print_buffer(c)
  puts buf.inspect
  puts buf
end

def debug_dump_clipboard()
  puts $clipboard.inspect
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
  #TODO
end

def crash(message, e = nil)
  puts "FATAL ERROR:#{message}"
  puts caller().join("\n")
  # savedebug(message, e)
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
  dbginfo["cnf"] = $cnf
  dbginfo["register"] = $register
  dbginfo["clipboard"] = $clipboard
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

def run_tests()
  run_test("01")
  run_test("02")
end

def run_test(test_id)
  target_results = read_file("", "tests/test_#{test_id}_output.txt")
  old_buffer = vma.buf
  vma.buf = Buffer.new("", "")
  load "tests/test_#{test_id}.rb"
  test_ok = vma.buf.to_s.strip == target_results.strip
  puts "##################"
  puts target_results
  puts "##################"
  puts vma.buf.to_s
  puts "##################"
  puts "TEST OK" if test_ok
  puts "TEST FAILED" if !test_ok
  puts "##################"
  vma.buf = old_buffer
end

#TODO: remove?
def gui_sleep(t2)
  t1 = Time.now()
  while Time.now < t1 + t2
    sleep(0.02)
  end
end

def run_random_jump_test__tmpl(test_time = 60 * 60 * 10)
  open_new_file("TODO"); gui_sleep(0.1)

  ttstart = Time.now
  Kernel.srand(1231)
  step = 0
  while Time.now < ttstart + test_time
    debug "step=#{step}"
    buf.jump_to_random_pos
    buf.insert_txt("Z") if rand() > 0.25
    buf.reset_highlight() if rand() > 0.1
    gui_trigger_event

    # puts "========line:========="
    # puts buf.current_line()
    # puts "======================"

    render_buffer(vma.buf)

    gui_sleep(rand() / 2)
    if rand() < (1 / 40.0)
      buf.revert
    end

    gui_trigger_event
    buf.insert_txt("X") if rand() > 0.25
    render_buffer(vma.buf)

    vma.buffers.set_current_buffer(rand(vma.buffers.size)) if rand > 0.25
    step += 1
  end
end

def start_ripl
  Ripl.start :binding => binding
end
