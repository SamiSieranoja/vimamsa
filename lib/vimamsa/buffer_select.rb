
def gui_select_buffer()
  buffer_list = []
  for buffer in $buffers
    if buffer.pathname
      #fpath = buffer.pathname
      #fpath = fpath[-50..-1] if fpath.size > 50
      fpath = buffer.get_short_path
      puts "bufpath:#{buffer.pathname}"
      list_item = [fpath,
                   buffer.pathname.dirname.realpath.to_s, ""]
      buffer_list << list_item
    else
      # list_item = ["unnamed", "unnamed"]
    end
  end
  puts buffer_list.inspect
  #$select_keys = ['h', 'l', 'f', 'd', 's', 'a', 'g', 'z']
  $select_keys = "sdflkjabceghimnopqrtuvxyz".split("")
  show_keys = $select_keys.collect { |x| x.upcase }
  if buffer_list.size > show_keys.size
    message("More buffers than can handle")
    # TODO: find a better fix
    buffer_list = buffer_list[0..(show_keys.size - 1)]
  end

  qt_select_window(buffer_list, show_keys, method(:gui_select_buffer_callback), 0)
end

def gui_select_buffer_callback(buffer_id)
  puts "BUFFER ID: #{buffer_id}"
  $buffers.set_current_buffer(buffer_id)
  $kbd.set_mode(COMMAND); qt_select_window_close(0)
  render_buffer($buffer)
end

def gui_select_buffer_handle_char(c)
  puts "BUFFER SELECTOR INPUT CHAR: #{c}"
  #Ripl.start :binding => binding
  buffer_i = $select_keys.index(c)
  if buffer_i != nil and $buffers[buffer_i] != nil
    gui_select_buffer_callback(buffer_i)
  end
end

def gui_select_buffer_init()
  $kbd.add_mode("S")
  bindkey "S enter", "$kbd.set_mode(COMMAND);qt_select_window_close(0)"
  bindkey "S return", "$kbd.set_mode(COMMAND);qt_select_window_close(0)"
  bindkey "S esc", "$kbd.set_mode(COMMAND);qt_select_window_close(0)"
  bindkey "S <char>", "gui_select_buffer_handle_char(<char>)"
end
