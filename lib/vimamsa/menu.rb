def generate_context_menu()
  $menu = {}
  m = buf.context_menu_items()
  i = 0
  qt_menu = []
  for item in m
    i += 1
    item << i
    $menu[i] = item
    qt_menu << item
  end
  return qt_menu
end

def context_menu_callback(id)
  puts "context_menu_callback(#{id})"
  item = $menu[id]
  puts item.inspect
  if item
    mthod = item[1]
    param = item[2]
    mthod.call(param)
  end
  if buf.visual_mode?
    buf.end_visual_mode
  end
  
  #TODO: all of these needed?
  qt_process_deltas
  qt_process_events
  qt_update_cursor_pos
end
