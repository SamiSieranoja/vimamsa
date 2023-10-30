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
    @idle_func_running = false
    super()
    @bufo = bufo #object of Buffer class buffer.rb
    debug "vsource init"
    @last_keyval = nil
    @last_event = [nil, nil]
    @removed_controllers = []
    self.highlight_current_line = true

    @tt = nil

    #    self.drag_dest_add_image_targets #TODO:gtk4
    #    self.drag_dest_add_uri_targets #TODO:gtk4

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

    # Mainly after page-up or page-down
    signal_connect("move-cursor") do |widget, event|
      if event.name == "GTK_MOVEMENT_PAGES" and (last_action == "page_up" or last_action == "page_down")
        # Ripl.start :binding => binding

        debug("MOVE-CURSOR", 2)
        # $update_cursor = true
        handle_scrolling()
      end

      # handle_scrolling()
      # curpos = buffer.cursor_position
      # debug "MOVE CURSOR (sig): #{curpos}"

      # run_as_idle proc {
      # curpos = buffer.cursor_position
      # debug "MOVE CURSOR (sig2): #{curpos}"
      # }

      false
    end

    return

    #TODO:gtk4
    signal_connect "button-release-event" do |widget, event|
      vma.buf.set_pos(buffer.cursor_position)
      false
    end
    @curpos_mark = nil
  end

  def gutter_width()
    winwidth = width
    view_width = visible_rect.width
    gutter_width = winwidth - view_width
  end

  def show_controllers
    clist = self.observe_controllers
    (0..(clist.n_items - 1)).each { |x|
      ctr = clist.get_item(x)
      pp ctr
    }
  end

  def check_controllers
    clist = self.observe_controllers
    to_remove = []
    (0..(clist.n_items - 1)).each { |x|
      ctr = clist.get_item(x)
      # Sometimes a GestureClick EventController appears from somewhere
      # not initiated from this file.

      # if ctr.class == Gtk::EventControllerKey or ctr.class == Gtk::GestureClick
      if ctr != @click
        # to_remove << ctr if ctr.class != Gtk::GestureDrag
        to_remove << ctr
      end
    }
    if to_remove.size > 0
      debug "Removing controllers:"
      pp to_remove
      to_remove.each { |x|
        # To avoid GC. https://github.com/ruby-gnome/ruby-gnome/issues/15790
        @removed_controllers << x
        self.remove_controller(x)
      }
    end
  end

  def register_signals()
    check_controllers

    # Implement mouse selections using @cnt_mo and @cnt_drag
    @cnt_mo = Gtk::EventControllerMotion.new
    self.add_controller(@cnt_mo)
    @cnt_mo.signal_connect "motion" do |gesture, x, y|
      if !@range_start.nil? and !x.nil? and !y.nil? and buf.visual_mode?
        i = coord_to_iter(x, y, true)
        @bufo.set_pos(i) if !i.nil? and @last_iter != i
        @last_iter = i
      end
    end

    @last_coord = nil
    @cnt_drag = Gtk::GestureDrag.new
    self.add_controller(@cnt_drag)
    @cnt_drag.signal_connect "drag-begin" do |gesture, x, y|
      debug "drag-begin", 2
      i = coord_to_iter(x, y, true)
      pp i
      @range_start = i
      if !buf.visual_mode?
        buf.start_visual_mode
      end
    end

    @cnt_drag.signal_connect "drag-end" do |gesture, offsetx, offsety|
      debug "drag-end", 2

      # Not enough drag
      if offsetx.abs < 5 and offsety.abs < 5
        buf.end_visual_mode
      end
      @range_start = nil
    end

    click = Gtk::GestureClick.new
    click.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
    self.add_controller(click)
    # Detect mouse click
    @click = click

    @range_start = nil
    click.signal_connect "pressed" do |gesture, n_press, x, y, z|
      debug "SourceView, GestureClick released x=#{x} y=#{y}"

      if buf.visual_mode?
        buf.end_visual_mode
      end

      xloc = (x - gutter_width).to_i
      yloc = (y + visible_rect.y).to_i
      debug "xloc=#{xloc} yloc=#{yloc}"

      i = coord_to_iter(xloc, yloc)
      # @range_start = i

      # This needs to happen after xloc calculation, otherwise xloc gets a wrong value (around 200 bigger)
      if vma.gui.current_view != self
        vma.gui.set_current_view(self)
      end

      @bufo.set_pos(i) if !i.nil?
      true
    end

    click.signal_connect "released" do |gesture, n_press, x, y, z|
      debug "SourceView, GestureClick released x=#{x} y=#{y}"

      xloc = (x - gutter_width).to_i
      yloc = (y + visible_rect.y).to_i
      debug "xloc=#{xloc} yloc=#{yloc}"

      # This needs to happen after xloc calculation, otherwise xloc gets a wrong value (around 200 bigger)
      if vma.gui.current_view != self
        vma.gui.set_current_view(self)
      end

      i = coord_to_iter(xloc, yloc)

      # if i != @range_start
      # debug "RANGE #{[@range_start, i]}", 2
      # end

      @bufo.set_pos(i) if !i.nil?
      # @range_start = nil
      true
    end
  end

  def coord_to_iter(xloc, yloc, transform_coord = false)
    if transform_coord
      xloc = (xloc - gutter_width).to_i
      yloc = (yloc + visible_rect.y).to_i
    end

    # Try to get exact character position
    i = get_iter_at_location(xloc, yloc)

    # If doesn't work, at least get the start of correct line
    # TODO: sometimes end of line is better choice
    if i.nil?
      r = get_line_at_y(yloc)
      i = r[0] if !r.nil?
    end

    return i.offset if !i.nil?
    return nil
  end

  def handle_scrolling()
    delete_cursorchar
    # curpos = buffer.cursor_position
    # debug "MOVE CURSOR: #{curpos}"
    return nil if vma.gui.nil?
    return nil if @bufo.nil?
    vma.gui.run_after_scrolling proc {
      debug "START UPDATE POS AFTER SCROLLING", 2
      delete_cursorchar
      bc = window_to_buffer_coords(Gtk::TextWindowType::WIDGET, gutter_width + 2, 60)
      if !bc.nil?
        i = coord_to_iter(bc[0], bc[1])
        if !i.nil?
          @bufo.set_pos(i)
        end
      end
      $update_cursor = false
    }
  end

  # def handle_key_event(event, sig)
  def handle_key_event(keyval, keyname, sig)
    delete_cursorchar
    if $update_cursor
      handle_scrolling
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
    keyval_trans[Gdk::Keyval::GDK_KEY_ISO_Left_Tab] = "tab"

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

    if key_str_parts[0] == "shift" and key_str_parts.size == 2
      if key_str_parts[1].size == 1 and key_str_parts[1].match(/^[[:upper:]]$/)
        #"shift-P" to just "P" etc.
        # but keep shift-tab as is
        key_str_parts.delete_at(0)
      end
    end

    key_str = key_str_parts.join("-")
    if key_str == "\u0000"
      key_str = ""
    end

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

    draw_cursor #TODO: only when needed
  end

  def pos_to_coord(i)
    b = buffer
    iter = b.get_iter_at(:offset => i)
    iterxy = get_iter_location(iter)
    winw = width #TODO

    view_width = visible_rect.width
    gutter_width = winw - view_width #TODO

    x = iterxy.x + gutter_width
    y = iterxy.y

    # buffer_to_window_coords(Gtk::TextWindowType::TEXT, iterxy.x, iterxy.y).inspect
    # debug buffer_to_window_coords(Gtk::TextWindowType::TEXT, x, y).inspect
    (x, y) = buffer_to_window_coords(Gtk::TextWindowType::TEXT, x, y)

    return [x, y]
  end

  def handle_deltas()
    delete_cursorchar
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
      #TODO: only when necessary
      self.set_cursor_pos(pos)
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
    delete_cursorchar
    # return
    itr = buffer.get_iter_at(:offset => pos)
    itr2 = buffer.get_iter_at(:offset => pos + 1)
    buffer.place_cursor(itr)

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

    # This is not the current buffer
    return false if vma.gui.view != self

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

      return true # Call this func again
    else
      @idle_func_running = false
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
    return #TODO:gtk4
    debug "@idle_func_running=#{@idle_func_running}"
    return if @idle_func_running
    if is_cursor_visible == false
      @idle_func_running = true
      debug "Starting idle func"
      Thread.new {
        sleep 0.01
        GLib::Idle.add(proc { cursor_visible_idle_func })
      }
    end
  end

  # Delete the extra char added to buffer to represent the cursor
  def delete_cursorchar
    if !@cursorchar.nil?
      itr = buffer.get_iter_at(:offset => @cursorchar)
      itr2 = buffer.get_iter_at(:offset => @cursorchar + 1)
      buffer.delete(itr, itr2)
      @cursorchar = nil
    end
  end

  def draw_cursor
    # if @tt.nil?
    # @tt = buffer.create_tag("font_tag")
    # @tt.font = "Arial"
    # end

    mode = vma.kbd.get_mode
    ctype = vma.kbd.get_cursor_type
    delete_cursorchar
    vma.gui.remove_overlay_cursor
    if ctype == :command
      if @bufo[@bufo.pos] == "\n"
        # If we are at end of line, it's not possible to draw the cursor by making a selection. I tried to do this by drawing an overlay, but that generates issues. If moving the cursor causes the ScrolledWindow to be scrolled, these errors randomly appear and the whole view shows blank:
        # (ruby:21016): Gtk-WARNING **: 19:52:23.181: Trying to snapshot GtkSourceView 0x55a97524c8c0 without a current allocation
        # (ruby:21016): Gtk-WARNING **: 19:52:23.181: Trying to snapshot GtkGizmo 0x55a9727d2580 without a current allocation
        # (ruby:21016): Gtk-WARNING **: 19:52:23.243: Trying to snapshot GtkSourceView 0x55a97524c8c0 without a current allocation
        # vma.gui.overlay_draw_cursor(@bufo.pos)

        # Current workaround is to add an empty space to the place where the cursor is and then remove this whenever we get any kind of event that might cause this class to be accessed.
        itr = buffer.get_iter_at(:offset => @bufo.pos)
        buffer.insert(itr, " ") # normal space
        # buffer.insert(itr, " ") # thin space (U+2009)
        # buffer.insert(itr, "l")
        @cursorchar = @bufo.pos

        # Apparently we need to redo this after buffer.insert:
        itr = buffer.get_iter_at(:offset => @bufo.pos)
        itr2 = buffer.get_iter_at(:offset => @bufo.pos + 1)
        # buffer.apply_tag(@tt, itr, itr2)
        buffer.select_range(itr, itr2)
      else
        itr = buffer.get_iter_at(:offset => @bufo.pos)
        itr2 = buffer.get_iter_at(:offset => @bufo.pos + 1)
        buffer.select_range(itr, itr2)
      end
      # elsif @bufo.visual_mode?
    elsif ctype == :visual
      # debug "VISUAL MODE"
      (_start, _end) = @bufo.get_visual_mode_range2
      # debug "#{_start}, #{_end}"
      itr = buffer.get_iter_at(:offset => _start)
      itr2 = buffer.get_iter_at(:offset => _end + 1)
      # Pango-CRITICAL **: pango_layout_get_cursor_pos: assertion 'index >= 0 && index <= layout->length' failed
      buffer.select_range(itr, itr2)
    elsif ctype == :insert
      # Not sure why this is needed
      itr = buffer.get_iter_at(:offset => @bufo.pos)
      buffer.select_range(itr, itr)

      # Via trial and error, this combination is only thing that seems to work:
      vma.gui.sw.child.toggle_cursor_visible
      vma.gui.sw.child.cursor_visible = true

      debug "INSERT MODE"
    else # TODO
    end
  end
end
