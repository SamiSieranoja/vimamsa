
def qt_signal(sgnname, param)
  debug "GOT QT-SIGNAL #{sgnname}: #{param}"
  if sgnname == "saveas"
    file_saveas(param)
  elsif sgnname == "filenew"
    create_new_file
    render_buffer
  elsif sgnname == "save"
    $buffer.save
  end
end

