# class VSourceView < Gtk::TextView
class VSourceView < GtkSource::View
  attr_accessor :bufo, :autocp_active, :cpl_list


  # def initialize(title = nil,bufo=nil)
  def initialize(title, bufo)
    # super(:toplevel)
    @highlight_matching_brackets = true
    @idle_func_running = false
    super()
    @bufo = bufo #object of Buffer class (buffer.rb)
    debug "vsource init"
    @last_keyval = nil
    @last_event = [nil, nil]
    @removed_controllers = []
    self.highlight_current_line = true

    @tt = nil

    # Mainly after page-up or page-down
    signal_connect("move-cursor") do |widget, event|
      # if event.name == "GTK_MOVEMENT_PAGES" and (vma.actions.last_action == "page_up" or vma.actions.last_action == "page_down")
      # handle_scrolling()
      # end

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

    signal_connect "button-release-event" do |widget, event|
      vma.buf.set_pos(buffer.cursor_position)
      false
    end
    @curpos_mark = nil
  end

  def set_content(str)
    self.buffer.set_text(str)
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

      # TODO: Check which of these are needed:
      # puts ctr.class
      # Gtk::DropTarget
      # Gtk::EventControllerFocus
      # Gtk::EventControllerKey
      # Gtk::EventControllerMotion
      # Gtk::EventControllerScroll
      # Gtk::GestureClick
      # Gtk::GestureDrag
      # Gtk::ShortcutController

      if ![@click, @dt].include?(ctr) and [Gtk::DropControllerMotion, Gtk::DropTarget, Gtk::GestureDrag, Gtk::GestureClick, Gtk::EventControllerKey].include?(ctr.class)
        to_remove << ctr
      end
    }
    if to_remove.size > 0
      to_remove.each { |x|
        # To avoid GC. https://github.com/ruby-gnome/ruby-gnome/issues/15790
        @removed_controllers << x
        self.remove_controller(x)
      }
    end
  end

  def focus_out()
    set_cursor_color(:inactive)

    # This does not seem to work: (TODO:why?)
    # self.cursor_visible = false
  end

  def focus_in()
    set_cursor_color(@ctype)
    self.cursor_visible = false
    self.cursor_visible = true
    self.grab_focus
  end

  def register_signals()
    check_controllers

    # TODO: accept GLib::Type::STRING also?
    @dt = Gtk::DropTarget.new(GLib::Type["GFile"], [Gdk::DragAction::COPY, Gdk::DragAction::MOVE])
    # GLib::Type::INVALID

    self.add_controller(@dt)
    @dt.signal_connect "drop" do |obj, v, x, y|
      if v.value.gtype == GLib::Type["GLocalFile"]
        uri = v.value.uri
      elsif v.value.class == String
        uri = v.value.gsub(/\r\n$/, "")
      end
      debug "dt,drop #{v.value},#{x},#{y}", 2
      fp = uri_to_path(uri)
      buf.handle_drag_and_drop(fp) if !fp.nil?
      true
    end

    @dt.signal_connect "enter" do |gesture, x, y, z, m|
      debug "dt,enter", 2
      Gdk::DragAction::COPY
    end

    @dt.signal_connect "motion" do |obj, x, y|
      debug "dt,move", 2

      Gdk::DragAction::COPY
    end

    # dc = Gtk::DropControllerMotion.new
    # self.add_controller(dc)
    # dc.signal_connect "enter" do |gesture, x, y|
    # debug "enter", 2
    # debug [x, y]
    # # Ripl.start :binding => binding
    # true
    # end

    # dc.signal_connect "motion" do |gesture, x, y|
    # debug "move", 2
    # debug [x, y]
    # true
    # end

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
      buf.start_selection
    end

    @cnt_drag.signal_connect "drag-end" do |gesture, offsetx, offsety|
      debug "drag-end", 2
      if offsetx.abs < 5 and offsety.abs < 5
        debug "Not enough drag", 2
        buf.end_selection
        # elsif !buf.visual_mode? and vma.kbd.get_scope != :editor
      elsif vma.kbd.get_scope != :editor
        # Can't transition from editor wide mode to buffer specific mode
        vma.kbd.set_mode(:visual)
      else
        buf.end_selection
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
    return # TODO
    # curpos = buffer.cursor_position
    # debug "MOVE CURSOR: #{curpos}"
    return nil if vma.gui.nil?
    return nil if @bufo.nil?
    vma.gui.run_after_scrolling proc {
      debug "START UPDATE POS AFTER SCROLLING", 2
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

  def set_cursor_to_top
    debug "set_cursor_to_top", 2
    bc = window_to_buffer_coords(Gtk::TextWindowType::WIDGET, gutter_width + 2, 60)
    if !bc.nil?
      i = coord_to_iter(bc[0], bc[1])
      if !i.nil?
        @bufo.set_pos(i)
        set_cursor_pos(i)
      end
    end
  end

  # def handle_key_event(event, sig)
  def handle_key_event(keyval, keyname, sig)
    if $update_cursor
      handle_scrolling
    end
    debug $view.visible_rect.inspect

    debug "key event" + [keyval, @last_keyval, keyname, sig].to_s
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
    keyval_trans[Gdk::Keyval::KEY_Caps_Lock] = "caps"

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
    keyval_trans[Gdk::Keyval::KEY_ISO_Left_Tab] = "tab"

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

    # After remapping capslock to control in gnome-tweak tool,
    # if pressing and immediately releasing the capslock (control) key,
    # we get first "caps" on keydown and ctrl-"caps" on keyup (keyval 65509, Gdk::Keyval::KEY_Caps_Lock)
    # If mapping capslock to ctrl in hardware, we get keyval 65507 (Gdk::Keyval::KEY_Control_L) instead
    if key_str_parts[0] == "ctrl" and key_str_parts[1] == "caps"
      # Replace ctrl-caps with ctrl
      key_str_parts.delete_at(1)
    end

    if key_str_parts[0] == key_str_parts[1]
      # We don't want "ctrl-ctrl" or "alt-alt"
      # TODO:There should be a better way to do this
      key_str_parts.delete_at(0)
    end

    if key_str_parts[0] == "shift" and key_str_parts.size == 2
      if key_str_parts[1].size == 1 # and key_str_parts[1].match(/^[[:upper:]]$/)
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
    # vma.kbd.match_key_conf(key_str, nil, :key_press)
    # debug "key_str=#{key_str} key_"

    if key_str != "" # or prefixed_key_str != ""
      if sig == :key_release and keyval == @last_keyval
        vma.kbd.match_key_conf(key_str + "!", nil, :key_release)
        @last_event = [keynfo, :key_release]
      elsif sig == :key_press
        vma.kbd.match_key_conf(key_str, nil, :key_press)
        @last_event = [keynfo, key_str, :key_press]
      end
    end
    @last_keyval = keyval

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

  def cur_pos_xy
    return pos_to_coord(buffer.cursor_position)
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

    # draw_cursor

    return true
  end

  def cursor_visible_idle_func
    # return false
    debug "cursor_visible_idle_func"
    # From https://picheta.me/articles/2013/08/gtk-plus--a-method-to-guarantee-scrolling.html

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
    # return
    debug "@idle_func_running=#{@idle_func_running}"
    return if @idle_func_running
    if is_cursor_visible == false
      @idle_func_running = true
      debug "Starting idle func"
      GLib::Idle.add(proc { cursor_visible_idle_func })
    end
  end

  def after_action
    iterate_gui_main_loop
    handle_deltas
    iterate_gui_main_loop
    draw_cursor
    iterate_gui_main_loop
  end

  def set_cursor_color(ctype)
    if @ctype != ctype
      bg = $confh[:mode][ctype][:cursor][:background]
      if bg.class == String
        if !@cursor_prov.nil?
          self.style_context.remove_provider(@cursor_prov)
        end
        prov = Gtk::CssProvider.new
        # prov.load(data: ".view text selection { background-color: #{bg}; color: #ffffff; }")
        prov.load(data: ".view text selection { background-color: #{bg}; color: #ffffff; } .view { caret-color: #{bg};  }")
        self.style_context.add_provider(prov)
        @cursor_prov = prov
      end
      @ctype == ctype
    end
  end

  def draw_cursor
    sv = vma.gui.active_window[:sw].child
    return if sv.nil?
    if sv != self # if we are not the current buffer
      sv.draw_cursor
      return
    end

    mode = vma.kbd.get_mode
    ctype = vma.kbd.get_cursor_type
    ctype = :visual if vma.buf.selection_active?

    if [:command, :replace, :browse].include?(ctype)
      set_cursor_color(ctype)

      if !self.overwrite?
        self.overwrite = true

        # (Via trial and error) This combination is needed to make cursor visible:
        # TODO: determine why "self.cursor_visible = true" is not enough
        self.cursor_visible = false
        self.cursor_visible = true
      end
    elsif ctype == :visual
      set_cursor_color(ctype)
      # debug "VISUAL MODE"
      (_start, _end) = @bufo.get_visual_mode_range2
      # debug "#{_start}, #{_end}"
      itr = buffer.get_iter_at(:offset => _start)
      itr2 = buffer.get_iter_at(:offset => _end + 1)
      # Pango-CRITICAL **: pango_layout_get_cursor_pos: assertion 'index >= 0 && index <= layout->length' failed
      buffer.select_range(itr, itr2)
    elsif ctype == :insert
      set_cursor_color(ctype)
      self.overwrite = false
      debug "INSERT MODE"
    else # TODO
    end

    if [:insert, :command, :replace, :browse].include?(ctype)
      # Place cursor where it already is
      # Without this hack, the cursor doesn't always get drawn
      pos = @bufo.pos
      itr = buffer.get_iter_at(:offset => pos)
      buffer.place_cursor(itr)
    end

    # Sometimes we lose focus and the cursor vanishes because of that
    # TODO: determine why&when
    if !self.has_focus?
      self.grab_focus
      self.cursor_visible = false
      self.cursor_visible = true
    end
  end #end draw_cursor
end

