
def exec_in_terminal(cmd, autoclose = false)
  # debug "CMD:#{cmd}"

  # global to prevent garbage collect unlink
  $initf = Tempfile.new("bashinit")
  # debug $initf.path
  $initf.write(cmd)
  if autoclose
    $initf.write("\nsleep 10; exit;\n")
    $initf.write("rm #{$initf.path}\n")
  else
    $initf.write("rm #{$initf.path}\n")
    $initf.write("\nexec bash\n")
  end
  $initf.close
  # PTY.spawn("gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash")
  # fork { exec "gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash" }
  # Just another execution
  fork { exec "gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash" }
end

def command_to_buf_callback(cmd)
  require "open3"
  stdout, stderr, status = Open3.capture3(cmd)
  b = create_new_buffer(stdout, cmd)
end


load "terminal_extra.rb" if File.exist?("terminal_extra.rb")
def command_to_buf
  callback = method("command_to_buf_callback")
  gui_one_input_action("Execute command in shell, output to buffer", "Command:", "Execute", callback)
end
