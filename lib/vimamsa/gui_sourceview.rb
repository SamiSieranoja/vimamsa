# class VSourceView < Gtk::TextView
class VSourceView < GtkSource::View
  attr_accessor :bufo
  # :highlight_matching_brackets

  # def set_highlight_current_line(vbool)
  # end

  # def set_show_line_numbers(vbool)
  # end

  # def highlight_matching_brackets=(vbool)
  # end

  # def initialize(title = nil,bufo=nil)
  def initialize(title, bufo)
    # super(:toplevel)
    @highlight_matching_brackets = true
    super()
    @bufo = bufo #object of Buffer class buffer.rb
    debug "vsource init"
    @last_keyval = nil
    @last_event = [nil, nil]
    self.highlight_current_line = true

    #    self.drag_dest_add_image_targets #TODO:gtk4
    #    self.drag_dest_add_uri_targets #TODO:gtk4

    #    signal_connect "button-press-event" do |_widget, event| #TODO:gtk4
    # if event.button == Gdk::BUTTON_PRIMARY
    # # debug "Gdk::BUTTON_PRIMARY"
    # false
    # elsif event.button == Gdk::BUTTON_SECONDARY
    # # debug "Gdk::BUTTON_SECONDARY"
    # true
    # else
    # true
    # end
    # end

    #    signal_connect("drag-data-received") do |widget, event, x, y, data, info, time| #TODO:gtk4
    # puts "drag-data-received"
    # puts
    # if data.uris.size >= 1
    # imgpath = CGI.unescape(data.uris[0])
    # m = imgpath.match(/^file:\/\/(.*)/)
    # if m
    # fp = m[1]
    # handle_drag_and_drop(fp)
    # end
    # end
    # true
    # end

    return
    signal_connect("key_press_event") do |widget, event|
      handle_key_event(event, :key_press_event)
      true
    end

    signal_connect("key_release_event") do |widget, event|
      handle_key_event(event, :key_release_event)
      true
    end

    signal_connect("move-cursor") do |widget, event|
      $update_cursor = true
      false
    end

    signal_connect "button-release-event" do |widget, event|
      vma.buf.set_pos(buffer.cursor_position)
      false
    end
    @curpos_mark = nil
  end

  # def handle_key_event(event, sig)
  def handle_key_event(keyval, keyname, sig)
    if $update_cursor
      curpos = buffer.cursor_position
      debug "MOVE CURSOR: #{curpos}"
      buf.set_pos(curpos)
      $update_cursor = false
    end
    debug $view.visible_rect.inspect

    debug "key event"
    # debug event

    # key_name = event.string
    #TODO:??
    # if event.state.control_mask?
    # key_name = Gdk::Keyval.to_name(event.keyval)
    # Gdk::Keyval.to_name()
    # end

    keyval_trans = {}
    keyval_trans[Gdk::Keyval::KEY_Control_L] = "ctrl"
    keyval_trans[Gdk::Keyval::KEY_Control_R] = "ctrl"

    keyval_trans[Gdk::Keyval::KEY_Escape] = "esc"

    keyval_trans[Gdk::Keyval::KEY_Return] = "enter"
    keyval_trans[Gdk::Keyval::KEY_ISO_Enter] = "enter"
    keyval_trans[Gdk::Keyval::KEY_KP_Enter] = "enter"
    keyval_trans[Gdk::Keyval::KEY_Alt_L] = "alt"
    keyval_trans[Gdk::Keyval::KEY_Alt_R] = "alt"

    keyval_trans[Gdk::Keyval::KEY_BackSpace] = "backspace"
    keyval_trans[Gdk::Keyval::KEY_KP_Page_Down] = "pagedown"
    keyval_trans[Gdk::Keyval::KEY_KP_Page_Up] = "pageup"
    keyval_trans[Gdk::Keyval::KEY_Page_Down] = "pagedown"
    keyval_trans[Gdk::Keyval::KEY_Page_Up] = "pageup"
    keyval_trans[Gdk::Keyval::KEY_Left] = "left"
    keyval_trans[Gdk::Keyval::KEY_Right] = "right"
    keyval_trans[Gdk::Keyval::KEY_Down] = "down"
    keyval_trans[Gdk::Keyval::KEY_Up] = "up"
    keyval_trans[Gdk::Keyval::KEY_space] = "space"

    keyval_trans[Gdk::Keyval::KEY_Shift_L] = "shift"
    keyval_trans[Gdk::Keyval::KEY_Shift_R] = "shift"
    keyval_trans[Gdk::Keyval::KEY_Tab] = "tab"

    key_trans = {}
    key_trans["\e"] = "esc"
    tk = keyval_trans[keyval]
    keyname = tk if !tk.nil?

    key_str_parts = []
    key_str_parts << "ctrl" if vma.kbd.modifiers[:ctrl]
    key_str_parts << "alt" if vma.kbd.modifiers[:alt]
    key_str_parts << "shift" if vma.kbd.modifiers[:shift]
    key_str_parts << "meta" if vma.kbd.modifiers[:meta]
    key_str_parts << "super" if vma.kbd.modifiers[:super]
    key_str_parts << keyname

    if key_str_parts[0] == key_str_parts[1]
      # We don't want "ctrl-ctrl" or "alt-alt"
      # TODO:There should be a better way to do this
      key_str_parts.delete_at(0)
    end
    
    if key_str_parts[0] == "shift" and key_str_parts[1].class == String
      #"shift-P" to just "P"
      # key_str_parts.delete_at(0) if key_str_parts[1].match(/^[[:upper:]]$/)
      key_str_parts.delete_at(0)
    end

    key_str = key_str_parts.join("-")
    keynfo = { :key_str => key_str, :key_name => keyname, :keyval => keyval }
    debug keynfo.inspect
    # $kbd.match_key_conf(key_str, nil, :key_press)
    # debug "key_str=#{key_str} key_"

    if key_str != "" # or prefixed_key_str != ""
      if sig == :key_release and keyval == @last_keyval
        $kbd.match_key_conf(key_str + "!", nil, :key_release)
        @last_event = [keynfo, :key_release]
      elsif sig == :key_press
        $kbd.match_key_conf(key_str, nil, :key_press)
        @last_event = [keynfo, key_str, :key_press]
      end
      @last_keyval = keyval #TODO: outside if?
    end

    handle_deltas

    # set_focus(5)
    # false

  end

  def pos_to_coord(i)
    b = buffer
    iter = b.get_iter_at(:offset => i)
    iterxy = get_iter_location(iter)
    # winw = parent_window.width #TODO:gtk4
    winw = width #TODO

    view_width = visible_rect.width
    gutter_width = winw - view_width

    x = iterxy.x + gutter_width
    y = iterxy.y

    # buffer_to_window_coords(Gtk::TextWindowType::TEXT, iterxy.x, iterxy.y).inspect
    # debug buffer_to_window_coords(Gtk::TextWindowType::TEXT, x, y).inspect
    (x, y) = buffer_to_window_coords(Gtk::TextWindowType::TEXT, x, y)

    return [x, y]
  end

  def handle_deltas()
    any_change = false
    while d = @bufo.deltas.shift
      any_change = true
      pos = d[0]
      op = d[1]
      num = d[2]
      txt = d[3]
      if op == DELETE
        startiter = buffer.get_iter_at(:offset => pos)
        enditer = buffer.get_iter_at(:offset => pos + num)
        buffer.delete(startiter, enditer)
      elsif op == INSERT
        startiter = buffer.get_iter_at(:offset => pos)
        buffer.insert(startiter, txt)
      end
    end
    if any_change
      gui_set_cursor_pos(@bufo.id, @bufo.pos) #TODO: only when necessary
    end

    # sanity_check #TODO
  end

  def sanity_check()
    a = buffer.text
    b = buf.to_s
    # debug "===================="
    # debug a.lines[0..10].join()
    # debug "===================="
    # debug b.lines[0..10].join()
    # debug "===================="
    if a == b
      debug "Buffers match"
    else
      debug "ERROR: Buffer's don't match."
    end
  end

  def set_cursor_pos(pos)
    # return
    itr = buffer.get_iter_at(:offset => pos)
    itr2 = buffer.get_iter_at(:offset => pos + 1)
    buffer.place_cursor(itr)

    # $view.signal_emit("extend-selection", Gtk::MovementStep.new(:PAGES), -1, false)

    within_margin = 0.075 #margin as a [0.0,0.5) fraction of screen size
    use_align = false
    xalign = 0.5 #0.0=top 1.0=bottom, 0.5=center
    yalign = 0.5

    if @curpos_mark.nil?
      @curpos_mark = buffer.create_mark("cursor", itr, false)
    else
      buffer.move_mark(@curpos_mark, itr)
    end
    scroll_to_mark(@curpos_mark, within_margin, use_align, xalign, yalign)
    $idle_scroll_to_mark = true
    ensure_cursor_visible

    # scroll_to_iter(itr, within_margin, use_align, xalign, yalign)

    # $view.signal_emit("extend-selection", Gtk::TextExtendSelection.new, itr,itr,itr2)
    draw_cursor

    return true
  end

  def cursor_visible_idle_func
    debug "cursor_visible_idle_func"
    # From https://picheta.me/articles/2013/08/gtk-plus--a-method-to-guarantee-scrolling.html
    # vr = visible_rect

    # b = $view.buffer
    # iter = buffer.get_iter_at(:offset => buffer.cursor_position)
    # iterxy = get_iter_location(iter)

    sleep(0.01)
    # intr = iterxy.intersect(vr)
    if is_cursor_visible == false
      # set_cursor_pos(buffer.cursor_position)

      itr = buffer.get_iter_at(:offset => buffer.cursor_position)

      within_margin = 0.075 #margin as a [0.0,0.5) fraction of screen size
      use_align = false
      xalign = 0.5 #0.0=top 1.0=bottom, 0.5=center
      yalign = 0.5

      scroll_to_iter(itr, within_margin, use_align, xalign, yalign)

      # return true # Call this func again
    else
      return false # Don't call this idle func again
    end
  end

  def is_cursor_visible
    vr = visible_rect
    iter = buffer.get_iter_at(:offset => buffer.cursor_position)
    iterxy = get_iter_location(iter)
    iterxy.width = 1 if iterxy.width == 0
    iterxy.height = 1 if iterxy.height == 0

    intr = iterxy.intersect(vr)
    if intr.nil?
      debug iterxy.inspect
      debug vr.inspect
      return false
    else
      return true
    end
  end

  def ensure_cursor_visible
    if is_cursor_visible == false
      Thread.new {
        sleep 0.01
        GLib::Idle.add(proc { cursor_visible_idle_func })
      }
    end
  end

  def draw_cursor
    if is_command_mode
      itr = buffer.get_iter_at(:offset => @bufo.pos)
      itr2 = buffer.get_iter_at(:offset => @bufo.pos + 1)
      $view.buffer.select_range(itr, itr2)
    elsif @bufo.visual_mode?
      debug "VISUAL MODE"
      (_start, _end) = @bufo.get_visual_mode_range2
      debug "#{_start}, #{_end}"
      itr = buffer.get_iter_at(:offset => _start)
      itr2 = buffer.get_iter_at(:offset => _end + 1)
      $view.buffer.select_range(itr, itr2)
    else # Insert mode
      itr = buffer.get_iter_at(:offset => @bufo.pos)
      $view.buffer.select_range(itr, itr)
      debug "INSERT MODE"
    end
  end
end
