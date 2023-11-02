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


