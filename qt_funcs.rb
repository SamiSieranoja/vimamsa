
def qt_signal(sgnname, param)
  debug "GOT QT-SIGNAL #{sgnname}: #{param}"
  if sgnname == "saveas"
    file_saveas(param)
  elsif sgnname == "filenew"
    create_new_file
    render_buffer
  elsif sgnname == "save"
    buf.save
  elsif sgnname == "mouse_move"
  elsif sgnname == "mouse_leftbtn_move"
    if !buf.visual_mode?
      buf.start_visual_mode
    end
  elsif sgnname == "mouse_leftbtn_press"
    if buf.visual_mode?
      buf.end_visual_mode
      qt_process_events
    end
  end
end
