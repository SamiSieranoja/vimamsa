$idle_scroll_to_mark = false

def gui_open_file_dialog(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Open file",
                                      :action => :open,
                                      :buttons => [["Open", :accept],
                                                   ["Cancel", :cancel]])
  dialog.set_current_folder(Gio::File.new_for_path(dirpath))
  # dialog.set_current_folder(Gio::File.new_for_path("/tmp"))

  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT
      open_new_file(dialog.file.parse_name)
    end
    dialog.destroy
  end

  dialog.modal = true
  dialog.show
end

def gui_file_saveas(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Save as",
                                      :action => :save,
                                      :buttons => [["Save", :accept],
                                                   ["Cancel", :cancel]])
  # dialog.set_current_folder(dirpath) #TODO:gtk4
  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT

      # dialog.file.uri
      file_saveas(dialog.file.parse_name)
    end
    dialog.destroy
  end

  dialog.modal = true
  dialog.show
  # dialog.run
  # 'Gtk::Dialog#run' has been deprecated. Use Gtk::Window#set_modal and 'response' signal instead.>

end

def idle_func
  # debug "IDLEFUNC"
  if $idle_scroll_to_mark
    # $view.get_visible_rect
    vr = $view.visible_rect

    # iter = b.get_iter_at(:offset => i)

    b = $view.buffer
    iter = b.get_iter_at(:offset => b.cursor_position)
    iterxy = $view.get_iter_location(iter)
    # debug "ITERXY" + iterxy.inspect

    intr = iterxy.intersect(vr)
    if intr.nil?
      $view.set_cursor_pos($view.buffer.cursor_position)
    else
      $idle_scroll_to_mark = false
    end

    sleep(0.1)
  end
  sleep(0.01)
  return true
end

def center_on_current_line()
  b = $view.buffer
  iter = b.get_iter_at(:offset => b.cursor_position)
  within_margin = 0.0 #margin as a [0.0,0.5) fraction of screen size
  use_align = true
  xalign = 0.0 #0.0=top 1.0=bottom, 0.5=center
  yalign = 0.5
  $view.scroll_to_iter(iter, within_margin, use_align, xalign, yalign)
end

def get_visible_area()
  view = $view
  vr = view.visible_rect
  startpos = view.get_iter_at_position_raw(vr.x, vr.y)[1].offset
  endpos = view.get_iter_at_position_raw(vr.x + vr.width, vr.y + vr.height)[1].offset
  return [startpos, endpos]
end

def page_up
  $view.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), -1, false)
  return true
end

def page_down
  $view.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), 1, false)
  return true
end

def paste_system_clipboard()

  #TODO: Check if something useful in this old GTK3 code.
  utf8_string = Gdk::Atom.intern("UTF8_STRING")

  clipboard = Gtk::Clipboard.get_default($vmag.window.display)
  received_text = ""

  target_string = Gdk::Selection::TARGET_STRING
  ti = clipboard.request_contents(target_string)

  if clipboard.wait_is_text_available?
    received_text = clipboard.wait_for_text
  end

  if received_text != "" and !received_text.nil?
    max_clipboard_items = 100
    if received_text != $clipboard[-1]
      #TODO: HACK
      $paste_lines = false
    end
    $clipboard << received_text
    # debug $clipboard[-1]
    $clipboard = $clipboard[-([$clipboard.size, max_clipboard_items].min)..-1]
  end
  return received_text
end

def set_system_clipboard(arg)
  vma.gui.window.display.clipboard.set(arg)
end

def gui_create_buffer(id, bufo)
  debug "gui_create_buffer(#{id})"
  buf1 = GtkSource::Buffer.new()
  view = VSourceView.new(nil, bufo)

  view.register_signals()
  $debug = true

  ssm = GtkSource::StyleSchemeManager.new
  ssm.set_search_path(ssm.search_path << ppath("styles/"))
  sty = ssm.get_scheme("molokai_edit")

  buf1.highlight_matching_brackets = true
  buf1.style_scheme = sty

  view.set_highlight_current_line(true)
  view.set_show_line_numbers(true)
  view.set_buffer(buf1)

  provider = Gtk::CssProvider.new
  provider.load(data: "textview { font-family: Monospace; font-size: 11pt; }")
  view.style_context.add_provider(provider)
  view.wrap_mode = :char
  view.set_tab_width(conf(:tab_width))

  $vmag.buffers[id] = view
end

def gui_set_file_lang(id, lname)
  view = $vmag.buffers[id]
  lm = GtkSource::LanguageManager.new
  lang = nil
  lm.set_search_path(lm.search_path << ppath("lang/"))
  lang = lm.get_language(lname)

  view.buffer.language = lang
  view.buffer.highlight_syntax = true
end

def gui_add_image(imgpath, pos)
end

# TODO:?
def gui_select_window_close(arg = nil)
end

def gui_set_buffer_contents(id, txt)
  debug "gui_set_buffer_contents(#{id}, txt)"
  vma.gui.buffers[id].buffer.set_text(txt)
end

def gui_set_cursor_pos(id, pos)
  vma.buf.view.set_cursor_pos(pos)
end

def gui_set_active_window(winid)
  sw = vma.gui.sw
  if winid == 2
    sw = vma.gui.sw2
  end

  sw.set_child(view)
  view.grab_focus

  vma.gui.view = view
  vma.gui.buf1 = view.buffer
  $view = view
  $vbuf = view.buffer
end

#TODO:delete?
def gui_attach_buf_to_window(id, winid)
  view = vma.gui.buffers[id]
  sw = vma.gui.sw
  if winid == 2
    sw = vma.gui.sw2
  end

  sw.set_child(view)
  view.grab_focus

  vma.gui.view = view
  vma.gui.buf1 = view.buffer
  $view = view
  $vbuf = view.buffer
end

def gui_set_current_buffer(id)
  vma.gui.set_current_buffer(id)
  return
end

def gui_set_window_title(wtitle, subtitle = "")
  $vmag.window.title = wtitle
  #  $vmag.window.titlebar.subtitle = subtitle #TODO:gtk4
end

class VMAgui
  attr_accessor :buffers, :sw, :sw1, :sw2, :view, :buf1, :window, :delex, :statnfo, :overlay, :overlay1, :overlay2, :sws, :two_c
  attr_reader :two_column, :windows

  def initialize()
    @two_column = false
    @active_column = 1
    @show_overlay = true
    @da = nil
    @sws = []
    @buffers = {}
    @view = nil
    @buf1 = nil
    @img_resizer_active = false
    @windows = {}
    # imgproc = proc {
    # GLib::Idle.add(proc {
    # if !buf.images.empty?
    # vma.gui.scale_all_images

    # w = Gtk::Window.new(:toplevel)
    # w.set_default_size(1, 1)
    # w.show_all
    # Thread.new { sleep 0.1; w.destroy }
    # end

    # false
    # })
    # }
    # @delex = DelayExecutioner.new(1, imgproc)
  end

  def run
    init_window
    # init_rtext
  end

  def quit
    @window.destroy
    @shutdown = true
    for t in Thread.list
      if t != Thread.current
        t.exit
      end
    end
  end

  def delay_scale()
    if Time.now - @dtime > 2.0
    end
  end

  def scale_all_images
    # puts "scale all"
    for img in buf.images
      if !img[:obj].destroyed?
        img[:obj].scale_image
      end
    end
  end

  def handle_image_resize #TODO:gtk4
    return if @img_resizer_active == true
    @dtime = Time.now

    $gcrw = 0
    vma.gui.window.signal_connect "configure-event" do |widget, cr|
      if $gcrw != cr.width
        @delex.run
      end
      $gcrw = cr.width
      false
    end

    @img_resizer_active = true
  end

  def start_overlay_draw()
    @da = Gtk::Fixed.new
    @overlay.add_overlay(@da)

    # @overlay.set_overlay_pass_through(@da, true) #TODO:gtk4
  end

  def clear_overlay()
    if @da != nil
      # @overlay.remove(@da)
      @overlay.remove_overlay(@da)
    end
  end

  def overlay_draw_text(text, textpos)
    # debug "overlay_draw_text #{[x,y]}"
    (x, y) = @view.pos_to_coord(textpos)
    # debug "overlay_draw_text #{[x,y]}"
    label = Gtk::Label.new("<span background='#000000ff' foreground='#ff0000' weight='ultrabold'>#{text}</span>")
    label.use_markup = true
    @da.put(label, x, y)
  end

  def end_overlay_draw()
    @da.show
  end

  def toggle_overlay
    @show_overlay = @show_overlay ^ 1
    if !@show_overlay
      if @da != nil
        @overlay.remove(@da)
      end
      return
    else
      @da = Gtk::Fixed.new
      @overlay.add_overlay(@da)
      @overlay.set_overlay_pass_through(@da, true)
    end

    (startpos, endpos) = get_visible_area
    s = @view.buffer.text
    wpos = s.enum_for(:scan, /\W(\w)/).map { Regexp.last_match.begin(0) + 1 }
    wpos = wpos[0..130]

    # vr =  @view.visible_rect
    # # gtk_text_view_get_line_at_y
    # # gtk_text_view_get_iter_at_position
    # gtk_text_view_get_iter_at_position(vr.
    # istart = @view.get_iter_at_position(vr.x,vr.y)
    # istart = @view.get_iter_at_y(vr.y)
    # startpos = @view.get_iter_at_position_raw(vr.x,vr.y)[1].offset
    # endpos = @view.get_iter_at_position_raw(vr.x+vr.width,vr.y+vr.height)[1].offset
    # debug "startpos,endpos:#{[startpos, endpos]}"

    da = @da
    if false
      da.signal_connect "draw" do |widget, cr|
        cr.save
        for pos in wpos
          (x, y) = @view.pos_to_coord(pos)

          layout = da.create_pango_layout("XY")
          desc = Pango::FontDescription.new("sans bold 11")
          layout.font_description = desc

          cr.move_to(x, y)
          # cr.move_to(gutter_width, 300)
          cr.pango_layout_path(layout)

          cr.set_source_rgb(1.0, 0.0, 0.0)
          cr.fill_preserve
        end
        cr.restore
        false # = draw other
        # true # = Don't draw others
      end
    end

    for pos in wpos
      (x, y) = @view.pos_to_coord(pos)
      # da.put(Gtk::Label.new("AB"), x, y)
      label = Gtk::Label.new("<span background='#00000088' foreground='#ff0000' weight='ultrabold'>AB</span>")
      label.use_markup = true
      da.put(label, x, y)
    end

    # debug @view.pos_to_coord(300).inspect

    @da.show
  end

  def handle_deltas()
    while d = buf.deltas.shift
      pos = d[0]
      op = d[1]
      num = d[2]
      txt = d[3]
      if op == DELETE
        startiter = @buf1.get_iter_at(:offset => pos)
        enditer = @buf1.get_iter_at(:offset => pos + num)
        @buf1.delete(startiter, enditer)
      elsif op == INSERT
        startiter = @buf1.get_iter_at(:offset => pos)
        @buf1.insert(startiter, txt)
      end
    end
  end

  def add_to_minibuf(msg)
    # return #TODO:gtk4
    startiter = @minibuf.buffer.get_iter_at(:offset => 0)
    @minibuf.buffer.insert(startiter, "#{msg}\n")
    @minibuf.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), -1, false)
  end

  def init_minibuffer()
    # Init minibuffer
    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    overlay = Gtk::Overlay.new
    overlay.set_child(sw) #TODO:gtk4
    @vbox.attach(overlay, 0, 2, 2, 1) #TODO:gtk4
    $sw2 = sw
    sw.set_size_request(-1, 12)

    view = VSourceView.new(nil, nil)
    view.set_highlight_current_line(false)
    view.set_show_line_numbers(false)
    # view.set_buffer(buf1)
    ssm = GtkSource::StyleSchemeManager.new
    ssm.set_search_path(ssm.search_path << ppath("styles/"))
    sty = ssm.get_scheme("molokai_edit")
    view.buffer.highlight_matching_brackets = false #TODO
    view.buffer.style_scheme = sty
    provider = Gtk::CssProvider.new
    # provider.load(data: "textview { font-family: Monospace; font-size: 11pt; }")
    provider.load(data: "textview { font-family: Arial; font-size: 10pt; color:#eeeeee}")
    view.style_context.add_provider(provider)
    view.wrap_mode = :char
    @minibuf = view
    # startiter = view.buffer.get_iter_at(:offset => 0)
    message("STARTUP")
    sw.set_child(view)
  end

  def init_header_bar()
    header = Gtk::HeaderBar.new
    @header = header
    header.show_close_button = true
    # header.title = ""#TODO:gtk4
    # header.has_subtitle = true#TODO:gtk4
    header.subtitle = ""

    # icon = Gio::ThemedIcon.new("mail-send-receive-symbolic")
    # icon = Gio::ThemedIcon.new("document-open-symbolic")
    # icon = Gio::ThemedIcon.new("dialog-password")

    #edit-redo edit-paste edit-find-replace edit-undo edit-find edit-cut edit-copy
    #document-open document-save document-save-as document-properties document-new
    # document-revert-symbolic
    #

    #TODO:
    # button = Gtk::Button.new
    # icon = Gio::ThemedIcon.new("open-menu-symbolic")
    # image = Gtk::Image.new(:icon => icon, :size => :button)
    # button.add(image)
    # header.pack_end(button)

    button = Gtk::Button.new
    icon = Gio::ThemedIcon.new("document-open-symbolic")
    image = Gtk::Image.new(:icon => icon, :size => :button)
    button.add(image)
    header.pack_end(button)

    button.signal_connect "clicked" do |_widget|
      open_file_dialog
    end

    button = Gtk::Button.new
    icon = Gio::ThemedIcon.new("document-save-symbolic")
    image = Gtk::Image.new(:icon => icon, :size => :button)
    button.add(image)
    header.pack_end(button)
    button.signal_connect "clicked" do |_widget|
      buf.save
    end

    button = Gtk::Button.new
    icon = Gio::ThemedIcon.new("document-new-symbolic")
    image = Gtk::Image.new(:icon => icon, :size => :button)
    button.add(image)
    header.pack_end(button)
    button.signal_connect "clicked" do |_widget|
      create_new_file
    end

    box = Gtk::Box.new(:horizontal, 0)
    box.style_context.add_class("linked")

    button = Gtk::Button.new
    image = Gtk::Image.new(:icon_name => "pan-start-symbolic", :size => :button)
    button.add(image)
    box.add(button)
    button.signal_connect "clicked" do |_widget|
      history_switch_backwards
    end

    button = Gtk::Button.new
    image = Gtk::Image.new(:icon_name => "pan-end-symbolic", :size => :button)
    button.add(image)
    box.add(button)
    button.signal_connect "clicked" do |_widget|
      history_switch_forwards
    end

    button = Gtk::Button.new
    icon = Gio::ThemedIcon.new("window-close-symbolic")
    image = Gtk::Image.new(:icon => icon, :size => :button)
    button.add(image)
    box.add(button)
    button.signal_connect "clicked" do |_widget|
      bufs.close_current_buffer
    end

    header.pack_start(box)
    @window.titlebar = header
    # @window.add(Gtk::TextView.new)
  end

  def debug_idle_func
    return false if @shutdown == true
    if Time.now - @last_debug_idle > 1
      @last_debug_idle = Time.now
      # puts "DEBUG IDLE #{Time.now}"
      # @view.check_controllers
    end

    ctrl_fn = File.expand_path("~/.vimamsa/ripl_ctrl")
    # Allows to debug in case keyboard handling is lost
    if File.exist?(ctrl_fn)
      File.delete(ctrl_fn)
      start_ripl
    end

    sleep 0.02
    return true
  end

  def reset_controllers
    clist = @window.observe_controllers
    to_remove = []
    (0..(clist.n_items - 1)).each { |x|
      ctr = clist.get_item(x)
      if ctr.class == Gtk::EventControllerKey
        to_remove << ctr
      end
    }
    if to_remove.size > 0
      puts "Removing controllers:"
      pp to_remove
      to_remove.each { |x| @window.remove_controller(x) }
    end

    press = Gtk::EventControllerKey.new
    @press = press
    # to prevent SourceView key handler capturing any keypresses
    press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
    @window.add_controller(press)

    press.signal_connect "key-pressed" do |gesture, keyval, keycode, y|
      name = Gdk::Keyval.to_name(keyval)
      uki = Gdk::Keyval.to_unicode(keyval)
      keystr = uki.chr("UTF-8")
      puts "key-pressed #{keyval} #{keycode} name:#{name} str:#{keystr} unicode:#{uki}"
      buf.view.handle_key_event(keyval, keystr, :key_press)
      true
    end

    press.signal_connect "modifiers" do |eventctr, modtype|
      # eventctr: Gtk::EventControllerKey
      # modtype: Gdk::ModifierType
      debug "modifier change"
      vma.kbd.modifiers[:ctrl] = modtype.control_mask?
      vma.kbd.modifiers[:alt] = modtype.alt_mask?
      vma.kbd.modifiers[:hyper] = modtype.hyper_mask?
      vma.kbd.modifiers[:lock] = modtype.lock_mask?
      vma.kbd.modifiers[:meta] = modtype.meta_mask?
      vma.kbd.modifiers[:shift] = modtype.shift_mask?
      vma.kbd.modifiers[:super] = modtype.super_mask?

      #TODO:?
      # button1_mask?
      # ...
      # button5_mask?
      true
    end

    press.signal_connect "key-released" do |gesture, keyval, keycode, y|
      name = Gdk::Keyval.to_name(keyval)
      uki = Gdk::Keyval.to_unicode(keyval)
      keystr = uki.chr("UTF-8")
      puts "key released #{keyval} #{keycode} name:#{name} str:#{keystr} unicode:#{uki}"
      buf.view.handle_key_event(keyval, keystr, :key_release)
      # vma.kbd.match_key_conf(keystr, nil, :key_press)
      # buf.view.handle_deltas
      # buf.view.handle_key_event(keyval, keystr, :key_press)
      true
    end
  end

  def remove_extra_controllers
    clist = vma.gui.window.observe_controllers
    to_remove = []
    (0..(clist.n_items - 1)).each { |x|
      ctr = clist.get_item(x)
      if ctr.class == Gtk::EventControllerKey and ctr != @press
        to_remove << ctr
      end
    }
    if to_remove.size > 0
      puts "Removing controllers:"
      pp to_remove
      to_remove.each { |x| vma.gui.window.remove_controller(x) }
    end
  end

  def init_window
    @last_debug_idle = Time.now
    app = Gtk::Application.new("net.samiddhi.vimamsa.r#{rand(1000)}", :flags_none)

    app.signal_connect "activate" do

      # @window = Gtk::Window.new(:toplevel)
      @window = Gtk::Window.new()
      @window.set_application(app)

      #    sh = @window.screen.height #TODO:gtk4
      #    sw = @window.screen.width #TODO:gtk4
      # TODO:Maximise vertically
      #    @window.set_default_size((sw * 0.45).to_i, sh - 20) #TODO:gtk4
      @window.set_default_size(800, 600) #TODO:gtk4

      @window.title = "Multiple Views"
      @vpaned = Gtk::Paned.new(:vertical)

      @vbox = Gtk::Grid.new()
      @window.add(@vbox)

      Thread.new {
        GLib::Idle.add(proc { debug_idle_func })
      }

      reset_controllers

      # @window.signal_connect("key-pressed") { puts "Hello World!" }
      # @window.signal_connect("clicked") { puts "Hello World!" }

      # @menubar = Gtk::PopoverMenuBar.new #TODO:gtk4
      #    @menubar.expand = false #TODO:gtk4

      @sw = Gtk::ScrolledWindow.new
      @sw.set_policy(:automatic, :automatic)

      # @sw.signal_connect("clicked") { puts "Hello World!" }
      # @sw.signal_connect("key-pressed") { puts "Hello World!" }
      @overlay = Gtk::Overlay.new
      # @overlay.add(@sw) #TODO:gtk4
      @overlay.add_overlay(@sw) #TODO:gtk4
      @overlay1 = @overlay

      # init_header_bar #TODO:gtk4

      @statnfo = Gtk::Label.new
      provider = Gtk::CssProvider.new
      # Ripl.start :binding => binding
      @statnfo.add_css_class("statnfo")

      provider.load(data: "label.statnfo {   background-color:#353535; font-size: 10pt; margin-top:2px; margin-bottom:2px; align:right;}")
      @statnfo.style_context.add_provider(provider)

      # numbers: left, top, width, height
      @vbox.attach(@overlay, 0, 1, 2, 1) #TODO:gtk4
      @sw.vexpand = true
      @sw.hexpand = true

      # column, row, width height
      # @vbox.attach(@menubar, 0, 0, 1, 1) #TODO:gtk4
      @vbox.attach(@statnfo, 1, 0, 1, 1)
      @overlay.vexpand = true #TODO:gtk4
      @overlay.hexpand = true #TODO:gtk4

      #    @menubar.vexpand = false #TODO:gtk4
      #    @menubar.hexpand = false #TODO:gtk4

      init_minibuffer

      @windows[1] = { :sw => @sw, :overlay => @overlay, :id => 1 }
      @active_window = @windows[1]

      # @window.show_all
      @window.show

      press = Gtk::GestureClick.new
      press.button = Gdk::BUTTON_SECONDARY
      @window.add_controller(press)
      press.signal_connect "pressed" do |gesture, n_press, x, y|
        puts "FOOBARpressed"
        # clear_surface(surface)
        # drawing_area.queue_draw
      end
      @sw1 = @sw

      vma.start
    end

    # Vimamsa::Menu.new(@menubar) #TODO:gtk4
    app.run

    # @window.show_all
    # @window.show
  end

  def set_two_column
    # @window.set_default_size(800, 600) #TODO:gtk4
    # @vpaned = Gtk::Paned.new(:vertical)
    # @vbox = Gtk::Grid.new()
    # @window.add(@vbox)

    @sw2 = Gtk::ScrolledWindow.new
    @sw2.set_policy(:automatic, :automatic)
    @overlay2 = Gtk::Overlay.new
    @overlay2.add_overlay(@sw2)
    @pane = Gtk::Paned.new(:horizontal)

    @windows[2] = { :sw => @sw2, :overlay => @overlay2, :id => 2 }

    @vbox.remove(@overlay)

    # numbers: left, top, width, height
    # @vbox.attach(@overlay2, 0, 1, 1, 1)
    # @vbox.attach(@overlay, 1, 1, 1, 1)

    @pane.set_start_child(@overlay)
    @pane.set_end_child(@overlay2)

    @vbox.attach(@pane, 0, 1, 2, 1)

    @sw2.vexpand = true
    @sw2.hexpand = true

    @overlay2.vexpand = true
    @overlay2.hexpand = true

    @sw2.show
    @two_column = true

    if vma.buffers.size > 1
      last = vma.buffers.get_last_visited_id
      set_buffer_to_window(last, 2)
    else
      bf = create_new_buffer "\n\n"
      set_buffer_to_window(bf.id, 2)
    end
  end

  def is_buffer_open(bufid)
    openbufids = @windows.keys.collect { |x| @windows[x][:sw].child.bufo.id }
    return openbufids.include?(bufid)
  end

  def toggle_active_window()
    return if !@two_column
    if @active_column == 1
      set_active_window(2)
    else
      set_active_window(1)
    end

    vma.buffers.set_current_buffer_by_id(@sw.child.bufo.id)
  end

  def set_active_window(id)
    return if !@two_column
    return if id == @active_column
    return if id == @active_window[:id]

    if @windows[id].nil?
      debug "No such window #{id}", 2
      return
    end

    @active_window = @windows[id]
    @active_column = id #TODO: remove

    @sw = @windows[id][:sw]
    @overlay = @windows[id][:overlay]

    #TODO: set buf & view of active window??

  end

  def set_buffer_to_window(bufid, winid)
    view = @buffers[bufid]
    debug "vma.gui.set_buffer_to_window(#{bufid}), winid=#{winid}"
    buf1 = view.buffer

    @windows[winid][:sw].set_child(view)

    #TODO:???
    # @view = view
    # @buf1 = buf1
    # $view = view ???
    # $vbuf = buf1

  end

  def set_current_buffer(id)
    view = @buffers[id]
    debug "vma.gui.set_current_buffer(#{id}), view=#{view}"
    buf1 = view.buffer
    @view = view
    @buf1 = buf1
    $view = view
    $vbuf = buf1

    # If already open in another column

    if @two_column and @active_column == 2 and id == @sw1.child.bufo.id
      toggle_active_window
    elsif @two_column and @active_column == 1 and id == @sw2.child.bufo.id
      toggle_active_window
    else
      @sw.set_child(view)
    end
    view.grab_focus
    # TODO:needed?
    # view.set_cursor_visible(true)
    # view.place_cursor_onscreen
    @sw.show
  end
end
