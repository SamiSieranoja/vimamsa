
class VSourceView < GtkSource::View
  def initialize(title = nil)
    # super(:toplevel)
    super()
    puts "vsource init"
    @last_keyval = nil
    @last_event = [nil, nil]

    signal_connect "button-press-event" do |_widget, event|
      if event.button == Gdk::BUTTON_PRIMARY
        # puts "Gdk::BUTTON_PRIMARY"
        false
      elsif event.button == Gdk::BUTTON_SECONDARY
        # puts "Gdk::BUTTON_SECONDARY"
        true
      else
        true
      end
    end

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
      $buffer.set_pos(buffer.cursor_position)
      false
    end
    @curpos_mark = nil
  end

  def handle_key_event(event, sig)
    if $update_cursor
      curpos = buffer.cursor_position
      puts "MOVE CURSOR: #{curpos}"
      buf.set_pos(curpos)
      $update_cursor = false
    end
    puts $view.visible_rect.inspect

    puts "key event"
    puts event

    key_name = event.string
    if event.state.control_mask?
      key_name = Gdk::Keyval.to_name(event.keyval)
      # Gdk::Keyval.to_name()
    end

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
    tk = keyval_trans[event.keyval]
    key_name = tk if !tk.nil?

    key_str_parts = []
    key_str_parts << "ctrl" if event.state.control_mask? and key_name != "ctrl"
    key_str_parts << "alt" if event.state.mod1_mask? and key_name != "alt"

    key_str_parts << key_name
    key_str = key_str_parts.join("-")
    keynfo = { :key_str => key_str, :key_name => key_name, :keyval => event.keyval }
    puts keynfo.inspect
    # $kbd.match_key_conf(key_str, nil, :key_press)
    # puts "key_str=#{key_str} key_"

    if key_str != "" # or prefixed_key_str != ""
      if sig == :key_release_event and event.keyval == @last_keyval
        $kbd.match_key_conf(key_str + "!", nil, :key_release)
        @last_event = [event, :key_release]
      elsif sig == :key_press_event
        $kbd.match_key_conf(key_str, nil, :key_press)
        @last_event = [event, key_str, :key_press]
      end
      @last_keyval = event.keyval #TODO: outside if?
    end

    handle_deltas

    # set_focus(5)
    # false

  end

  def pos_to_coord(i)
    b = buffer
    iter = b.get_iter_at(:offset => i)
    iterxy = get_iter_location(iter)
    winw = parent_window.width
    view_width = visible_rect.width
    gutter_width = winw - view_width

    x = iterxy.x + gutter_width
    y = iterxy.y

    # buffer_to_window_coords(Gtk::TextWindowType::TEXT, iterxy.x, iterxy.y).inspect
    # puts buffer_to_window_coords(Gtk::TextWindowType::TEXT, x, y).inspect
    (x, y) = buffer_to_window_coords(Gtk::TextWindowType::TEXT, x, y)
    # Ripl.start :binding => binding

    return [x, y]
  end

  def handle_deltas()
    any_change = false
    while d = buf.deltas.shift
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
      gui_set_cursor_pos($buffer.id, $buffer.pos) #TODO: only when necessary
    end

    # sanity_check #TODO
  end

  def sanity_check()
    a = buffer.text
    b = buf.to_s
    # puts "===================="
    # puts a.lines[0..10].join()
    # puts "===================="
    # puts b.lines[0..10].join()
    # puts "===================="
    if a == b
      puts "Buffers match"
    else
      puts "ERROR: Buffer's don't match."
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
    # Ripl.start :binding => binding
    draw_cursor

    return true
  end

  def cursor_visible_idle_func
    puts "cursor_visible_idle_func"
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
      puts iterxy.inspect
      puts vr.inspect
      # Ripl.start :binding => binding

      # exit!
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
      itr = buffer.get_iter_at(:offset => buf.pos)
      itr2 = buffer.get_iter_at(:offset => buf.pos + 1)
      $view.buffer.select_range(itr, itr2)
    elsif buf.visual_mode?
      puts "VISUAL MODE"
      (_start, _end) = buf.get_visual_mode_range2
      puts "#{_start}, #{_end}"
      itr = buffer.get_iter_at(:offset => _start)
      itr2 = buffer.get_iter_at(:offset => _end + 1)
      $view.buffer.select_range(itr, itr2)
    else # Insert mode
      itr = buffer.get_iter_at(:offset => buf.pos)
      $view.buffer.select_range(itr, itr)
      puts "INSERT MODE"
    end
  end

  # def quit
  # destroy
  # true
  # end
end

