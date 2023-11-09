$idle_scroll_to_mark = false

def gui_open_file_dialog(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Open file",
                                      :action => :open,
                                      :buttons => [["Open", :accept],
                                                   ["Cancel", :cancel]])
  dialog.set_current_folder(Gio::File.new_for_path(dirpath))

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
  dialog.set_current_folder(Gio::File.new_for_path(dirpath))
  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT
      file_saveas(dialog.file.parse_name)
    end
    dialog.destroy
  end

  dialog.modal = true
  dialog.show
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

def gui_create_buffer(id, bufo)
  debug "gui_create_buffer(#{id})"
  buf1 = GtkSource::Buffer.new()
  view = VSourceView.new(nil, bufo)

  view.register_signals()
  cnf.debug = true

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
  pp $cnf
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
  # vma.gui.buffers[id].buffer.set_text(txt)
  vma.gui.buffers[id].set_content(txt)
end

#TODO: remove
def gui_set_cursor_pos(id, pos)
  vma.buf.view.set_cursor_pos(pos)
end

def gui_set_current_buffer(id)
  vma.gui.set_current_buffer(id)
  return
end

def gui_set_window_title(wtitle, subtitle = "")
  $vmag.window.title = wtitle
  # $vmag.subtitle.markup = "<span weight='ultrabold'>#{subtitle}</span>"
  $vmag.subtitle.markup = "<span weight='light' size='small'>#{subtitle}</span>"
  #  $vmag.window.titlebar.subtitle = subtitle #TODO:gtk4
end

class VMAgui
  attr_accessor :buffers, :sw, :sw1, :sw2, :view, :buf1, :window, :delex, :statnfo, :overlay, :overlay1, :overlay2, :sws, :two_c
  attr_reader :two_column, :windows, :subtitle, :app

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
    @app = nil
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
    debug "scale all", 2
    for img in buf.images
      if !img[:obj].destroyed?
        img[:obj].scale_image
      end
    end
    false
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

  def remove_overlay_cursor()
    if !@cursorov.nil?
      @overlay.remove_overlay(@cursorov)
      @cursorov = nil
    end
  end

  def overlay_draw_cursor(textpos)
    # return
    remove_overlay_cursor
    GLib::Idle.add(proc { self.overlay_draw_cursor_(textpos) })
    # overlay_draw_cursor_(textpos)
  end

  # Run proc after animated scrolling has stopped (e.g. after page down)
  def run_after_scrolling(p)
    Thread.new {
      # After running
      #   view.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES)
      # have to wait for animated page down scrolling to actually start
      # Then have to wait determine that it has stopped if scrolling adjustment stops changing. There should be a better way to do this.
      sleep 0.1
      while Time.now - @last_adj_time < 0.1
        sleep 0.1
      end
      debug "SCROLLING ENDED", 2
      run_as_idle p
    }
  end

  # To draw on empty lines and line-ends (where select_range doesn't work)
  def overlay_draw_cursor_(textpos)
    # Thread.new {
    # GLib::Idle.add(proc { p.call; false })
    # }

    # while Time.now - @last_adj_time < 0.3
    # return true
    # end

    remove_overlay_cursor
    @cursorov = Gtk::Fixed.new
    @overlay.add_overlay(@cursorov)

    (x, y) = @view.pos_to_coord(textpos)
    pp [x, y]

    # Trying to draw only background of character "I"
    label = Gtk::Label.new("<span background='#00ffaaff' foreground='#00ffaaff' weight='ultrabold'>I</span>")
    label.use_markup = true
    @cursorov.put(label, x, y)
    @cursorov.show
    return false
  end

  def handle_deltas()
    view.delete_cursor_char
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
    overlay.set_child(sw)
    @vbox.attach(overlay, 0, 3, 2, 1)
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

  # Remove widget event controllers added by gtk, and add our own.
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

  def idle_set_size()
    # Need to wait for a while to window to be maximized to get correct @window.width
    sleep 0.1
    width = @window.width / 2
    height = @window.height - 5
    # Ripl.start :binding => binding
    @window.unmaximize
    @window.set_default_size(width, height)
    return false
  end

  def init_window
    @last_debug_idle = Time.now
    app = Gtk::Application.new("net.samiddhi.vimamsa.r#{rand(1000)}", :flags_none)
    @app = app

    Gtk::Settings.default.gtk_application_prefer_dark_theme = true
    Gtk::Settings.default.gtk_theme_name = "Adwaita"

    app.signal_connect "activate" do
      @window = Gtk::ApplicationWindow.new(app)
      @window.set_application(app)

      @window.maximize
      # Need to let Gtk process after maximize
      run_as_idle proc { idle_set_size }

      @window.title = "Multiple Views"
      @vpaned = Gtk::Paned.new(:vertical)

      @vbox = Gtk::Grid.new()
      @window.add(@vbox)

      Thread.new {
        GLib::Idle.add(proc { debug_idle_func })
      }

      reset_controllers

      @sw = Gtk::ScrolledWindow.new
      @sw.set_policy(:automatic, :automatic)

      @last_adj_time = Time.now
      @sw.vadjustment.signal_connect("value-changed") { |x|
        # pp x.page_increment
        # pp x.page_size
        # pp x.step_increment
        # pp x.upper
        # pp x.value
        # pp x
        @last_adj_time = Time.now
        # puts "@sw.vadjustment"
      }

      # @sw.signal_connect("clicked") { puts "Hello World!" }
      # @sw.signal_connect("key-pressed") { puts "Hello World!" }
      @overlay = Gtk::Overlay.new
      # @overlay.add(@sw) #TODO:gtk4
      @overlay.add_overlay(@sw) #TODO:gtk4
      @overlay1 = @overlay

      # init_header_bar #TODO:gtk4

      @statnfo = Gtk::Label.new
      @subtitle = Gtk::Label.new("")
      @statbox = Gtk::Box.new(:horizontal, 2)
      @statnfo.set_size_request(150, 10)
      @statbox.pack_end(@subtitle, :expand => true, :fill => true, :padding => 0)
      @statbox.pack_end(@statnfo, :expand => false, :fill => false, :padding => 0)
      provider = Gtk::CssProvider.new
      @statnfo.add_css_class("statnfo")
      provider.load(data: "label.statnfo {   background-color:#353535; font-size: 10pt; margin-top:2px; margin-bottom:2px; align:right;}")

      provider = Gtk::CssProvider.new
      @statnfo.style_context.add_provider(provider)

      # numbers: left, top, width, height
      @vbox.attach(@overlay, 0, 2, 2, 1)
      @sw.vexpand = true
      @sw.hexpand = true

      # column, row, width height
      @vbox.attach(@statbox, 1, 1, 1, 1)

      @overlay.vexpand = true
      @overlay.hexpand = true

      init_minibuffer

      # p = Gtk::Popover.new

      name = "save"
      window = @window
      action = Gio::SimpleAction.new(name)
      action.signal_connect "activate" do |_simple_action, _parameter|
        dialog = Gtk::MessageDialog.new(:parent => window,
                                        :flags => :destroy_with_parent,
                                        :buttons => :close,
                                        :message => "Action FOOBAR activated.")
        dialog.signal_connect(:response) do
          dialog.destroy
        end
        dialog.show
      end

      @window.add_action(action)
      doc_actions = Gio::SimpleActionGroup.new
      doc_actions.add_action(action)

      act_quit = Gio::SimpleAction.new("quit")
      app.add_action(act_quit)
      act_quit.signal_connect "activate" do |_simple_action, _parameter|
        window.destroy
        exit!
      end

      menubar = Gio::Menu.new
      app.menubar = menubar
      @window.show_menubar = true

      @menubar = menubar

      @windows[1] = { :sw => @sw, :overlay => @overlay, :id => 1 }
      @active_window = @windows[1]

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

      prov = Gtk::CssProvider.new
      # See gtk-4.9.4/gtk/theme/Default/_common.scss  on how to theme
      # gtksourceview/gtksourcestyleschemepreview.c
      # gtksourceview/gtksourcestylescheme.c
      prov.load(data: " headerbar { padding: 0 0px; min-height: 16px; border-width: 0 0 0px; border-style: solid; }
      
      textview border.left gutter { color: #8aa; font-size:8pt; }     
      
      textview border.left gutter { padding: 0px 0px 0px 0px; margin: 0px 0px 0px 0px; color: #8aa; font-size:9pt; }     
      
         headerbar .title {
      font-weight: bold;
      font-size: 11pt;
      color: #cdffee;
  }
  
 headerbar > windowhandle > box .start {
      border-spacing: 6px;
  }
 
 headerbar windowcontrols button {
        min-height: 15px;
        min-width: 15px;
      }
  
         ")
      @window.style_context.add_provider(prov)

      sc = Gtk::StyleContext.add_provider_for_display(Gdk::Display.default, prov)

      vma.start
    end

    # Vimamsa::Menu.new(@menubar) #TODO:gtk4
    app.run

    # @window.show_all
    # @window.show
  end

  def init_menu
    Vimamsa::Menu.new(@menubar, @app)
  end

  def toggle_two_column
    if @two_column
      set_one_column
    else
      set_two_column
    end
  end

  def set_one_column
    return if !@two_column
    @windows[2][:sw].set_child(nil)
    @windows.delete(2)
    
    @pane.set_start_child(nil)
    @pane.set_end_child(nil)

    @vbox.remove(@pane)
    @vbox.attach(@overlay, 0, 2, 2, 1)
    @vbox.attach(@statbox, 1, 1, 1, 1)
    @two_column = false
  end

  def set_two_column
    return if @two_column
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

    @pane.set_start_child(@overlay2)
    @pane.set_end_child(@overlay)

    # numbers: left, top, width, height
    @vbox.attach(@pane, 0, 2, 2, 1)

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
      bf = create_new_buffer "\n\n", "buff", false
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
  end

  # activate that window which has the given view
  def set_current_view(view)
    w = @windows.find { |k, v| v[:sw].child == view }
    if !w.nil?
      set_active_window(w[0])
    end
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

    vma.buffers.set_current_buffer_by_id(@sw.child.bufo.id)

    #TODO: set buf & view of active window??

  end

  def current_view
    return @sw.child
  end

  def set_buffer_to_window(bufid, winid)
    view = @buffers[bufid]
    debug "vma.gui.set_buffer_to_window(#{bufid}), winid=#{winid}"
    buf1 = view.buffer

    @windows[winid][:sw].set_child(view)
    idle_ensure_cursor_drawn

    # @overlay = Gtk::Overlay.new
    # @overlay.add_overlay(view)

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

    # Check if buffer is already open in another column
    if @two_column and @active_column == 2 and id == @sw1.child.bufo.id
      toggle_active_window
    elsif @two_column && @active_column == 1 && !@sw2.child.nil? && id == @sw2.child.bufo.id
      #TODO: should not need !@sw2.child.nil? here. If this happens then other column is empty.
      toggle_active_window
    else
      @sw.set_child(view)
    end
    view.grab_focus

    idle_ensure_cursor_drawn
  end

  def idle_ensure_cursor_drawn
    run_as_idle proc { self.ensure_cursor_drawn }
  end

  def ensure_cursor_drawn
    # view.place_cursor_onscreen #TODO: needed?
    view.draw_cursor
  end
end
