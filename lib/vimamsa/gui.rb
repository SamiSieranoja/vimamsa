
module Vimamsa
$idle_scroll_to_mark = false

$removed_controllers = []

# Run one iteration of GMainLoop
# https://developer.gnome.org/documentation/tutorials/main-contexts.html
def iterate_gui_main_loop
  GLib::MainContext.default.iteration(true)
end

def start_profiler
  require "ruby-prof"
  RubyProf.start
end

def end_profiler
  result = RubyProf.stop
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT)
end

# Wait for window resize to take effect
# GTk3 had a resize notify event which got removed in gtk4
# https://discourse.gnome.org/t/gtk4-any-way-to-connect-to-a-window-resize-signal/14869/3
def wait_for_resize(window, tries = 200)
  i = 0
  widthold = @window.width
  heightold = @window.height
  while true
    iterate_gui_main_loop
    break if widthold != window.width
    break if heightold != window.height
    if i >= tries
      debug "i >= tries", 2
      break
    end
    i += 1
  end
end

def gui_remove_controllers(widget)
  clist = widget.observe_controllers
  to_remove = []
  (0..(clist.n_items - 1)).each { |x|
    ctr = clist.get_item(x)
    to_remove << ctr
  }
  if to_remove.size > 0
    # debug "Removing controllers:"
    # pp to_remove
    to_remove.each { |x|
      # To avoid GC. https://github.com/ruby-gnome/ruby-gnome/issues/15790
      $removed_controllers << x
      widget.remove_controller(x)
    }
  end
end

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

# def page_up
# $view.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), -1, false)
# return true
# end

# def page_down
# $view.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), 1, false)
# return true
# end

def gui_create_buffer(id, bufo)
  debug "gui_create_buffer(#{id})"
  buf1 = GtkSource::Buffer.new()
  view = VSourceView.new(nil, bufo)

  view.register_signals()

  sty = load_vimamsa_scheme

  buf1.highlight_matching_brackets = true
  buf1.style_scheme = sty
  gui_apply_color_mode(sty) if sty

  view.set_highlight_current_line(true)
  view.set_show_line_numbers(true)
  view.set_buffer(buf1)
  view.register_buffer_signals()

  provider = Gtk::CssProvider.new

  provider.load(data: "textview { font-family: #{cnf.font.family!}; font-size: #{cnf.font.size!}pt; }")
  view.style_context.add_provider(provider)
  view.wrap_mode = :char

  view.set_tab_width(cnf.tab.width!)

  $vmag.buffers[id] = view
end

def gui_close_buffer(id)
  view = vma.gui.buffers.delete(id)
  return if view.nil?
  view.unparent if view.parent
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

def gui_set_window_title(wtitle, subtitle = "", modified: false)
  wtitle = wtitle[0..150]
  $vmag.window.title = "Vimamsa - #{wtitle}"
  # Subtitle shows the file path: dim directory, bright basename,
  # amber dot when there are unsaved changes.
  subtitle = subtitle.to_s
  dir = File.dirname(subtitle)
  dir = (dir == ".") ? "" : (dir == "/" ? "/" : "#{dir}/")
  base = File.basename(subtitle)
  dot = modified ? "<span foreground='#fd971f' weight='bold'>● </span>" : ""
  $vmag.subtitle.markup = "<span size='small'>#{dot}" \
    "<span alpha='55%'>#{CGI.escapeHTML(dir)}</span>" \
    "<span weight='bold' alpha='92%'>#{CGI.escapeHTML(base)}</span></span>"
  #  $vmag.window.titlebar.subtitle = subtitle #TODO:gtk4
end

class VMAgui
  attr_accessor :buffers, :sw1, :sw2, :view, :buf1, :window, :delex, :statnfo, :overlay, :sws, :two_c, :scheme_is_light, :cyber_css_provider
  attr_reader :two_column, :windows, :subtitle, :app, :active_window, :action_trail_label, :file_panel, :func_panel, :keylog_panel, :keytrail, :cmd_line

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
    @entry_has_focus = false
  end

  # Called by embedded widgets (e.g. calculator entries) when a text entry
  # gains or loses focus, so the vimamsa key handler knows to step aside.
  def notify_entry_focus(active)
    @entry_has_focus = active
  end

  # True while a text entry (command line, calculator field, ...) owns the
  # keyboard focus and the editor view must not steal it back.
  def entry_focused?
    @entry_has_focus
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
    @app.quit
  end

  def scale_all_images
    for k, window in @windows
      bu = window[:sw].child.bufo
      for img in bu.images
        if !img[:obj].destroyed?
          img[:obj].scale_image
        end
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
    @active_window[:overlay].add_overlay(@da)

    # @overlay.set_overlay_pass_through(@da, true) #TODO:gtk4
  end

  def clear_overlay()
    if @da != nil
      # @overlay.remove(@da)
      @active_window[:overlay].remove_overlay(@da)
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
    @minibuf_messages ||= []
    @minibuf_messages.unshift(msg)
    @minibuf_messages = @minibuf_messages.first(50)

    @minibuf_label.label = msg
    @minibuf_textview.buffer.text = @minibuf_messages.join("\n")

    return if @minibuf_expanded

    @minibuf_stack.visible_child_name = "label"
    @minibuf_content.visible = true

    @minibuf_vpane.position = @minibuf_vpane.height - 26
    
    GLib::Source.remove(@minibuf_hide_source) if @minibuf_hide_source
    @minibuf_hide_source = GLib::Timeout.add(7000) do
      @minibuf_content.visible = false
      @minibuf_hide_source = nil
      false
    end
  end

  def minibuf_toggle_expanded
    @minibuf_expanded = !@minibuf_expanded
    if @minibuf_expanded
      GLib::Source.remove(@minibuf_hide_source) if @minibuf_hide_source
      @minibuf_hide_source = nil
      @minibuf_content.visible = true
      @minibuf_stack.visible_child_name = "history"
      run_as_idle proc {
        pos = @minibuf_vpane.max_position - (@minibuf_history_height || 120)
        @minibuf_vpane.position = [pos, 0].max
      }
    else
      # Save height before collapsing so next open restores it
      @minibuf_history_height = @minibuf_vpane.max_position - @minibuf_vpane.position
      @minibuf_stack.visible_child_name = "label"
      run_as_idle proc {
        #TODO: automatic way of resizing doesn't work:
        # h = [@minibuf_label.height, 24].max + 2
        # @minibuf_vpane.position = @minibuf_vpane.max_position - h
        @minibuf_vpane.position = @minibuf_vpane.height - 26
      }
      @minibuf_hide_source = GLib::Timeout.add(7000) do
        @minibuf_content.visible = false
        @minibuf_expanded = false
        @minibuf_stack.visible_child_name = "label"
        @minibuf_hide_source = nil
        false
      end
    end
  end

  def show_message_history
    minibuf_toggle_expanded
  end

  # ── editor-area helpers (delegates to @minibuf_vpane start child) ─────────

  def editor_area
    @minibuf_vpane.start_child
  end

  def set_editor_area(w)
    @minibuf_vpane.set_start_child(w)
  end

  def init_minibuffer
    @minibuf_messages = []
    @minibuf_expanded = false
    @minibuf_history_height = 120

    css = "label.minibuf, textview.minibuf, entry.minibuf { color: #cdd6f4; font-family: Monospace; font-size: 10pt; padding: 3px 8px; background-color: #1e1e2e; }"
    provider = Gtk::CssProvider.new
    provider.load(data: css)

    # Collapsed view: single line, latest message
    @minibuf_label = Gtk::Label.new("")
    @minibuf_label.xalign = 0.0
    @minibuf_label.hexpand = true
    @minibuf_label.ellipsize = Pango::EllipsizeMode::END
    @minibuf_label.add_css_class("minibuf")
    @minibuf_label.style_context.add_provider(provider)

    # Expanded view: scrollable history (fills whatever height the pane gives)
    @minibuf_textview = Gtk::TextView.new
    @minibuf_textview.editable = false
    @minibuf_textview.cursor_visible = false
    @minibuf_textview.wrap_mode = :word_char
    @minibuf_textview.add_css_class("minibuf")
    @minibuf_textview.style_context.add_provider(provider)
    @minibuf_textview.vexpand = true

    scroll = Gtk::ScrolledWindow.new
    scroll.set_policy(:never, :automatic)
    scroll.set_child(@minibuf_textview)
    scroll.vexpand = true

    @minibuf_stack = Gtk::Stack.new
    @minibuf_stack.vhomogeneous = false
    @minibuf_stack.transition_type = :crossfade
    @minibuf_stack.transition_duration = 100
    @minibuf_stack.add_named(@minibuf_label, "label")
    @minibuf_stack.add_named(scroll, "history")

    # Interactive command line (vim-style ":"), third stack child
    @cmd_line = CommandLine.new(provider)
    @minibuf_stack.add_named(@cmd_line.widget, "cmdline")

    @minibuf_content = Gtk::Box.new(:vertical, 0)
    @minibuf_content.append(Gtk::Separator.new(:horizontal))
    @minibuf_content.append(@minibuf_stack)
    @minibuf_content.visible = false  # hidden until first message

    # Vertical pane: editor fills top, minibuffer sits at bottom, draggable
    editor_w = @windows[1][:overlay]
    @vbox.remove(editor_w)

    @minibuf_vpane = Gtk::Paned.new(:vertical)
    @minibuf_vpane.vexpand = true
    @minibuf_vpane.hexpand = true
    @minibuf_vpane.resize_start_child = true   # editor absorbs window resize
    @minibuf_vpane.resize_end_child = false    # minibuffer keeps its height
    @minibuf_vpane.shrink_end_child = true     # allow fully collapsing minibuffer
    @minibuf_vpane.set_start_child(editor_w)
    @minibuf_vpane.set_end_child(@minibuf_content)

    @vbox.attach(@minibuf_vpane, 0, 2, 2, 1)
    @minibuf_hide_source = nil
  end

  # ── command line (vim-style ":", see gui_command_line.rb) ─────────────────

  def cmd_line_show
    GLib::Source.remove(@minibuf_hide_source) if @minibuf_hide_source
    @minibuf_hide_source = nil
    @minibuf_content.visible = true
    @minibuf_stack.visible_child_name = "cmdline"
    @minibuf_vpane.position = @minibuf_vpane.height - 34 unless @minibuf_expanded
    notify_entry_focus(true)
  end

  def cmd_line_hide
    notify_entry_focus(false)
    @minibuf_stack.visible_child_name = @minibuf_expanded ? "history" : "label"
    @minibuf_content.visible = false unless @minibuf_expanded
    vma.buf.view.grab_focus if vma.buf&.view
  end

  def make_header_button(action_id, icon, cb)
    act = Gio::SimpleAction.new(action_id)
    @app.add_action(act)
    act.signal_connect("activate") { |_a, _p| cb.call }
    btn = Gtk::Button.new
    btn.set_child(Gtk::Image.new(icon_name: icon))
    btn.action_name = "app.#{action_id}"
    btn
  end

  def init_header_bar()
    header = Gtk::HeaderBar.new
    @header = header

    file_box = Gtk::Box.new(:horizontal, 0)
    file_box.style_context.add_class("linked")
    file_box.append(make_header_button("hdr-open", "document-open-symbolic", proc { open_file_dialog }))
    file_box.append(make_header_button("hdr-save", "document-save-symbolic", proc { buf.save }))
    file_box.append(make_header_button("hdr-new", "document-new-symbolic", proc { create_new_file }))
    header.pack_start(file_box)

    nav_box = Gtk::Box.new(:horizontal, 0)
    nav_box.style_context.add_class("linked")
    nav_box.append(make_header_button("hdr-prev", "pan-start-symbolic", proc { history_switch_backwards }))
    nav_box.append(make_header_button("hdr-next", "pan-end-symbolic", proc { history_switch_forwards }))
    nav_box.append(make_header_button("hdr-close", "window-close-symbolic", proc { bufs.close_current_buffer }))
    header.pack_start(nav_box)

    # header.pack_end()

    @window.titlebar = header
  end

  def debug_idle_func
    return false if @shutdown == true
    if Time.now - @last_debug_idle > 1
      @last_debug_idle = Time.now
      # puts "DEBUG IDLE #{Time.now}"
      # @view.check_controllers
    end

    ctrl_fn = File.expand_path(get_dot_path("ripl_ctrl"))
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
      # debug "Removing controllers:"
      # pp to_remove
      to_remove.each { |x| @window.remove_controller(x) }
    end

    press = Gtk::EventControllerKey.new
    @press = press
    # to prevent SourceView key handler capturing any keypresses
    press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
    @window.add_controller(press)

    press.signal_connect "key-pressed" do |gesture, keyval, keycode, y|
      # Step aside when a text entry widget (e.g. calculator var field) has focus.
      # @entry_has_focus is set explicitly via notify_entry_focus by those widgets.
      next false if @entry_has_focus
      next false if @kbd_passthrough
      name = Gdk::Keyval.to_name(keyval)
      uki = Gdk::Keyval.to_unicode(keyval)
      keystr = uki.chr("UTF-8")
      debug "key pressed #{keyval} #{keycode} name:#{name} str:#{keystr} unicode:#{uki}"
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
      true # = handled, do not propagate further
    end

    press.signal_connect "key-released" do |gesture, keyval, keycode, y|
      next false if @entry_has_focus
      next false if @kbd_passthrough
      name = Gdk::Keyval.to_name(keyval)
      uki = Gdk::Keyval.to_unicode(keyval)
      keystr = uki.chr("UTF-8")
      debug "key released #{keyval} #{keycode} name:#{name} str:#{keystr} unicode:#{uki}"
      buf.view.handle_key_event(keyval, keystr, :key_release)
      true # = handled, do not propagate further
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
      # puts "Removing controllers:"
      # pp to_remove
      to_remove.each { |x| vma.gui.window.remove_controller(x) }
    end
  end

  def idle_set_size()
    # Need to wait for a while to window to be maximized to get correct @window.width
    @window.maximize
    wait_for_resize(@window)
    # Set new size as half of the screeen
    width = @window.width / 2
    height = @window.height - 5
    width = 600 if width < 600
    height = 600 if height < 600

    #Minimum size:
    @window.set_size_request(600, 600)
    @window.set_default_size(width, height)
    debug "size #{[width, height]}", 2
    @window.unmaximize

    #set_default_size doesn't always have effect if run immediately
    wait_for_resize(@window)
    @window.set_default_size(width, height)

    return false
  end

  def init_window
    @last_debug_idle = Time.now
    # Stable application id so desktop environments can match the running window
    # to its launcher entry / icon (see desktop_install.rb). :non_unique avoids
    # GTK's D-Bus single-instance enforcement (single-instance forwarding is
    # handled separately via the listen file in exe/vimamsa).
    app = Gtk::Application.new(VMA_APP_ID, :non_unique)
    @app = app
    Gtk::Window.set_default_icon_name("vimamsa")

    Gtk::Settings.default.gtk_application_prefer_dark_theme = true
    Gtk::Settings.default.gtk_theme_name = "Adwaita"
    Gtk::Settings.default.gtk_cursor_blink = false
    Gtk::Settings.default.gtk_cursor_blink_time = 4000

    app.signal_connect "activate" do
      @window = Gtk::ApplicationWindow.new(app)
      @window.set_application(app)

      @window.signal_connect("close-request") do
        vma.shutdown
        true  # prevent default destroy; shutdown->gui.quit handles it
      end

      @window.title = "Multiple Views"
      @vpaned = Gtk::Paned.new(:vertical)

      @vbox = Gtk::Grid.new()
      @window.set_child(@vbox)

      Thread.new {
        GLib::Idle.add(proc { debug_idle_func })
      }

      reset_controllers

      focus_controller = Gtk::EventControllerFocus.new

      focus_controller.signal_connect("enter") do
        debug "Gained focus"
        draw_cursor_bug_workaround
      end
      @window.add_controller(focus_controller)

      motion_controller = Gtk::EventControllerMotion.new
      motion_controller.signal_connect("motion") do |controller, x, y|
        # label.set_text("Mouse at: (%.1f, %.1f)" % [x, y])
        # puts "MOVE #{x} #{y}"

        # Cursor vanishes when hovering over menubar
        draw_cursor_bug_workaround if y < 30
        @last_cursor = [x, y]
        @cursor_move_time = Time.now
      end
      @window.add_controller(motion_controller)

      @windows[1] = new_window(1)

      @last_adj_time = Time.now

      # To show keyboard key binding state (mode badge, e.g. COMMAND)
      @statnfo = Gtk::Label.new
      @statnfo.add_css_class("mode-badge")

      # Pending key chord / repeat count next to the mode badge
      @keytrail = Gtk::Label.new("")
      @keytrail.add_css_class("keytrail")

      # To show e.g. current folder
      @subtitle = Gtk::Label.new("")

      @statbox = Gtk::Box.new(:horizontal, 6)
      @statbox.append(@subtitle)
      @subtitle.hexpand = true
      @statbox.append(@keytrail)
      @statbox.append(@statnfo)

      # numbers: left, top, width, height
      @vbox.attach(@windows[1][:overlay], 0, 2, 2, 1)

      # column, row, width height
      @vbox.attach(@statbox, 1, 1, 1, 1)

      init_minibuffer

      menubar = Gio::Menu.new
      @menubar = menubar

      # TODO: Doesn't work, why?:
      # menubar_bar = Gtk::PopoverMenuBar.new(menu_model: menubar)

      menubar_bar = Gtk::PopoverMenuBar.new()
      menubar_bar.set_menu_model(menubar)

      menubar_bar.hexpand = true
      @action_trail_label = Gtk::Label.new("")
      @action_trail_label.add_css_class("action-trail")
      menubar_row = Gtk::Box.new(:horizontal, 0)
      menubar_row.add_css_class("menubar-row")
      menubar_row.append(menubar_bar)
      menubar_row.append(@action_trail_label)
      @vbox.attach(menubar_row, 0, 0, 2, 1)

      @active_window = @windows[1]

      init_header_bar
      file_panel_init
      func_panel_init
      keylog_panel_init

      @window.show

      surface = @window.native.surface
      tt = Time.now
      surface.signal_connect("layout") do
        # puts "Window resized or moved, other redraw."
      end

      run_as_idle proc { idle_set_size }

      prov = Gtk::CssProvider.new
      # See gtk-4.9.4/gtk/theme/Default/_common.scss  on how to theme
      # gtksourceview/gtksourcestyleschemepreview.c
      # gtksourceview/gtksourcestylescheme.c
      prov.load(data: "
      /* Edge-lit panel: near-black chrome, neon-cyan bottom edge */
      headerbar { padding: 0 0px; min-height: 16px; border-width: 0 0 0px; border-style: solid; /*background: #0a0a12;*/ color: #d8e6ee; }

      menubar { background: transparent; }
      menubar > item { color: #b8ccd8; }

      box.menubar-row {
        /*background-color: #0a0a12;*/
        /*border-bottom: 1px solid #05d9e8;*/
      }
      
      /* Relative size so the gutter tracks the editor font setting
         (a fixed pt size left the gutter unchanged when the font changed). */
      textview border.left gutter { padding: 0px 0px 0px 0px; margin: 0px 0px 0px 0px; color: #8aa; font-size: 85%; }
      
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
  
 popover background > contents { padding: 8px; border-radius: 20px; }

 label.action-trail { font-family: monospace; font-size: 10pt; margin-right: 8px; color: #aaaaaa; }

 label.mode-badge {
   font-family: monospace; font-size: 9pt; font-weight: 800;
   padding: 1px 7px; margin: 2px 4px 2px 0;
   border-radius: 5px; min-width: 65px;
   color: #1b1d1e; background-color: #75715e;
   transition: background-color 120ms ease-out;
 }
 label.mode-badge.mode-command { background-color: #7c68f2; }
 label.mode-badge.mode-insert  { background-color: #78bf78; }
 label.mode-badge.mode-visual  { background-color: #d49e63; }
 label.mode-badge.mode-browse  { background-color: #a96bb0; }
 label.mode-badge.mode-replace { background-color: #d66d63; }
 label.mode-badge.mode-other   { background-color: #9670d6; }

 label.keytrail { font-family: monospace; font-size: 10pt; font-weight: bold; color: #e6db74; }
         ")
      @window.style_context.add_provider(prov)

      sc = Gtk::StyleContext.add_provider_for_display(Gdk::Display.default, prov)

      vma.start

      # After vma.start: user settings.rb (which may enable the theme) is
      # loaded during Editor#start.
      gui_refresh_theme
    end

    GLib::Idle.add(proc { self.monitor })

    app.run
  end

  # CSS class of mode badge label per mode key_name; others get "mode-other"
  MODE_BADGE_CSS = { "C" => "mode-command", "I" => "mode-insert", "V" => "mode-visual",
                     "B" => "mode-browse", "X" => "mode-replace" }.freeze

  # Render the mode badge and pending key chord in the status area.
  # Subscribed to KeyBindingTree's :state_trail_changed event.
  def update_mode_badge(badge, badge_key, trail)
    cls = MODE_BADGE_CSS.fetch(badge_key, "mode-other")
    if cls != @badge_css_class
      @statnfo.remove_css_class(@badge_css_class) if @badge_css_class
      @statnfo.add_css_class(cls)
      @badge_css_class = cls
    end
    @statnfo.text = badge if badge != @last_badge_text
    @keytrail.text = trail if trail != @last_trail_text
    @last_badge_text = badge
    @last_trail_text = trail
  end

  # Show the last executed key chord and action next to the menubar.
  # Subscribed to KeyBindingTree's :action_handled event.
  def show_action_trail(trail_str, action)
    return if !cnf.kbd.show_prev_action? or trail_str.class != String
    len_limit = 35
    if action.class == String && (m = action.match(/\Abuf\.insert_txt\((.+)\)\z/))
      action_desc = "insert #{m[1]}"
    else
      action_desc = vma.actions[action]&.method_name || action.to_s
      action_desc = action_desc[0..len_limit] if action_desc.size > len_limit
    end
    trail_esc = CGI.escapeHTML(trail_str)
    action_esc = CGI.escapeHTML(action_desc)
    # Completed key chord bright, executed action name dim
    @action_trail_label.markup = "<span alpha='70%'>#{trail_esc}  #{action_esc}</span>"
  end

  def monitor
    return true if @windows[1].nil?
    swa = @windows[1][:sw]
    @monitor_time ||= Time.now
    @sw_width ||= swa.width
    return true if Time.now - @monitor_time < 0.2
    # Detect element resize
    if swa.width != @sw_width
      debug "Width change sw_width #{@sw_width}"
      @sw_width = swa.width
      DelayExecutioner.exec(id: :scale_images, wait: 0.7, callable: proc { debug ":scale_images"; vma.gui.scale_all_images })
    end
    @monitor_time = Time.now
    return true
  end

  def init_menu
    @menu = Vimamsa::Menu.new(@menubar, @app)
  end

  def menu
    @menu
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
    #This always closes the leftmost column/window
    #TODO: close rightmost column if left active
    set_active_window(1)

    @windows[2][:sw].set_child(nil)
    @windows.delete(2)
    w1 = @windows[1]

    @pane.set_start_child(nil)
    @pane.set_end_child(nil)

    if @func_panel_shown
      @func_panel_pane.set_end_child(w1[:overlay])
    elsif @file_panel_shown
      @file_panel_pane.set_end_child(w1[:overlay])
    else
      set_editor_area(w1[:overlay])
    end
    @two_column = false
  end

  def new_window(win_id)
    n_sw = Gtk::ScrolledWindow.new
    n_sw.set_policy(:automatic, :automatic)
    n_sw.add_css_class("editor-frame")
    n_overlay = Gtk::Overlay.new
    n_overlay.add_overlay(n_sw)
    # @pane = Gtk::Paned.new(:horizontal)

    win = { :sw => n_sw, :overlay => n_overlay, :id => win_id }
    # @windows[2] = { :sw => @sw2, :overlay => @overlay2, :id => 2 }

    # @vbox.remove(@overlay)

    # @pane.set_start_child(@overlay2)
    # @pane.set_end_child(@overlay)

    # numbers: left, top, width, height
    # @vbox.attach(@pane, 0, 2, 2, 1)

    n_sw.vexpand = true
    n_sw.hexpand = true

    n_overlay.vexpand = true
    n_overlay.hexpand = true

    # TODO: remove??
    n_sw.vadjustment.signal_connect("value-changed") { |x|
 # pp x.page_increment
           # pp x.page_size
           # pp x.step_increment
           # pp x.upper
           # pp x.value
           # pp x
           # @last_adj_time = Time.now
      }

    # @sw2.show
    return win
  end

  def set_two_column
    return if @two_column
    @windows[2] = new_window(2)

    w1 = @windows[1]
    w2 = @windows[2]

    # Remove overlay from its current parent and add the Gtk::Paned instead
    @pane = Gtk::Paned.new(:horizontal)
    if @func_panel_shown
      @func_panel_pane.set_end_child(nil)
      @pane.set_start_child(w2[:overlay])
      @pane.set_end_child(w1[:overlay])
      @func_panel_pane.set_end_child(@pane)
    elsif @file_panel_shown
      @file_panel_pane.set_end_child(nil)
      @pane.set_start_child(w2[:overlay])
      @pane.set_end_child(w1[:overlay])
      @file_panel_pane.set_end_child(@pane)
    else
      @minibuf_vpane.set_start_child(nil)  # unparent w1[:overlay] before re-parenting
      @pane.set_start_child(w2[:overlay])
      @pane.set_end_child(w1[:overlay])
      set_editor_area(@pane)
    end

    w2[:sw].show
    @two_column = true

    last = vma.buffers.get_last_visited_id
    if !last.nil?
      set_buffer_to_window(last, 2)
    else
      # If there is only one buffer, create a new one and add to the new window/column
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

  # Activate that window which has the given view
  def set_current_view(view)
    # Window of current view:
    w = @windows.find { |k, v| v[:sw].child == view }
    # All other windows:
    otherw = @windows.find_all { |k, v| v[:sw].child != view }
    if !w.nil?
      set_active_window(w[0])
      for k, x in otherw
        x[:sw].child.focus_out()
      end
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
    @active_column = id

    @active_window[:sw].child.focus_in()
    for k, w in @windows
      if w != @active_window
        fochild = w[:sw].child
        run_as_idle proc { fochild.focus_out() }
      end
    end

    vma.buffers.set_current_buffer_by_id(@active_window[:sw].child.bufo.id)
  end

  def current_view
    return @active_window[:sw].child
  end

  def set_buffer_to_window(bufid, winid)
    view = @buffers[bufid]
    debug "vma.gui.set_buffer_to_window(#{bufid}), winid=#{winid}"
    buf1 = view.buffer

    @windows[winid][:sw].set_child(view)
    idle_ensure_cursor_drawn

    #TODO:???
    # @view = view
    # @buf1 = buf1
    # $view = view ???
    # $vbuf = buf1

  end

  def set_current_buffer(id)
    view2 = @buffers[id]
    debug "vma.gui.set_current_buffer(#{id}), view=#{view}"
    buf1 = view2.buffer
    @view = view2
    @buf1 = buf1
    $view = view
    $vbuf = buf1

    # Check if buffer is already open in another column
    if @two_column and @active_column == 2 and id == @windows[1][:sw].child.bufo.id
      toggle_active_window
    elsif @two_column && @active_column == 1 && !@windows[2][:sw].child.nil? && id == @windows[2][:sw].child.bufo.id
      #TODO: should not need !@sw2.child.nil? here. If this happens then other column is empty.
      toggle_active_window
    else
      #TODO: improve
      swa = @active_window[:sw]
      ol = @active_window[:overlay]
      ol.remove_overlay(swa)
      swa.set_child(nil)
      # Creating a new ScrolledWindow every time to avoid a layout bug
      # https://gitlab.gnome.org/GNOME/gtk/-/issues/6189
      swb = new_scrolled_window
      swb.set_child(view2)
      ol.add_overlay(swb)
      @active_window[:view] = view
      @active_window[:sw] = swb
    end
    view.grab_focus

    idle_ensure_cursor_drawn
  end

  def new_scrolled_window
    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    @last_adj_time = Time.now
    sw.vadjustment.signal_connect("value-changed") { |x|
      @last_adj_time = Time.now
      debug "@sw.vadjustment #{x.value}", 2
    }
    return sw
  end

  def page_down(multip: 1.0)
    sw = @active_window[:sw]
    va = sw.vadjustment
    newval = va.value + va.page_increment * multip
    va.value = newval
    sw.child.set_cursor_to_top
  end

  def page_up(multip: 1.0)
    sw = @active_window[:sw]
    va = sw.vadjustment
    newval = va.value - va.page_increment * multip
    newval = 0 if newval < 0
    va.value = newval
    sw.child.set_cursor_to_top
  end

  def idle_ensure_cursor_drawn
    run_as_idle proc { self.ensure_cursor_drawn }
  end

  def ensure_cursor_drawn
    # view.place_cursor_onscreen #TODO: needed?
    view.draw_cursor
  end

  def file_panel_init
    @file_panel = FileTreePanel.new
    @file_panel_shown = false
  end

  def file_panel_refresh
    return unless @file_panel_shown
    @file_panel.refresh
  end

  def show_file_panel
    return if @file_panel_shown
    # If func panel is shown it sits in minibuf_vpane; wrap it too
    inner = if @func_panel_shown
      @func_panel_pane
    elsif @two_column
      @pane
    else
      @windows[1][:overlay]
    end
    @minibuf_vpane.set_start_child(nil)  # unparent inner before re-parenting
    @file_panel_pane = Gtk::Paned.new(:horizontal)
    @file_panel_pane.hexpand = true
    @file_panel_pane.vexpand = true
    @file_panel_pane.set_start_child(@file_panel.widget)
    @file_panel_pane.set_end_child(inner)
    @file_panel_pane.set_position(180)
    set_editor_area(@file_panel_pane)
    @file_panel_shown = true
    @file_panel.refresh
  end

  def hide_file_panel
    return unless @file_panel_shown
    inner = @file_panel_pane.end_child
    @file_panel_pane.set_start_child(nil)
    @file_panel_pane.set_end_child(nil)
    set_editor_area(inner)
    @file_panel_shown = false
  end

  def toggle_file_panel
    @file_panel_shown ? hide_file_panel : show_file_panel
  end

  def func_panel_init
    @func_panel = FuncPanel.new
    @func_panel_shown = false
  end

  def func_panel_refresh
    return unless @func_panel_shown
    @func_panel.refresh
  end

  def show_func_panel
    return if @func_panel_shown
    if @file_panel_shown
      inner = @file_panel_pane.end_child
      @file_panel_pane.set_end_child(nil)
    elsif @two_column
      inner = @pane
      @minibuf_vpane.set_start_child(nil)
    else
      inner = @windows[1][:overlay]
      @minibuf_vpane.set_start_child(nil)
    end
    @func_panel_pane = Gtk::Paned.new(:horizontal)
    @func_panel_pane.hexpand = true
    @func_panel_pane.vexpand = true
    @func_panel_pane.set_start_child(@func_panel.widget)
    @func_panel_pane.set_end_child(inner)
    @func_panel_pane.set_position(160)
    if @file_panel_shown
      @file_panel_pane.set_end_child(@func_panel_pane)
    else
      set_editor_area(@func_panel_pane)
    end
    @func_panel_shown = true
    @func_panel.refresh
  end

  def hide_func_panel
    return unless @func_panel_shown
    inner = @func_panel_pane.end_child
    @func_panel_pane.set_start_child(nil)
    @func_panel_pane.set_end_child(nil)
    if @file_panel_shown
      @file_panel_pane.set_end_child(inner)
    else
      set_editor_area(inner)
    end
    @func_panel_shown = false
  end

  def toggle_func_panel
    @func_panel_shown ? hide_func_panel : show_func_panel
  end

  def keylog_panel_init
    @keylog_panel = KeyLogPanel.new
    @keylog_shown = false
  end

  # The key log wraps @minibuf_vpane at the grid level (right side), so it is
  # independent of the file/func panel and two-column nesting, which only
  # touch @minibuf_vpane's start child.
  def show_keylog_panel
    return if @keylog_shown
    @vbox.remove(@minibuf_vpane)
    @keylog_pane = Gtk::Paned.new(:horizontal)
    @keylog_pane.hexpand = true
    @keylog_pane.vexpand = true
    @keylog_pane.set_start_child(@minibuf_vpane)
    @keylog_pane.set_end_child(@keylog_panel.widget)
    @keylog_pane.resize_start_child = true   # editor absorbs window resize
    @keylog_pane.resize_end_child = false    # log keeps its width
    @keylog_pane.shrink_end_child = false
    @vbox.attach(@keylog_pane, 0, 2, 2, 1)
    @keylog_shown = true
    @keylog_panel.set_active(true)
  end

  def hide_keylog_panel
    return unless @keylog_shown
    @keylog_panel.set_active(false)
    @keylog_pane.set_start_child(nil)
    @keylog_pane.set_end_child(nil)
    @vbox.remove(@keylog_pane)
    @vbox.attach(@minibuf_vpane, 0, 2, 2, 1)
    @keylog_shown = false
  end

  def toggle_keylog_panel
    @keylog_shown ? hide_keylog_panel : show_keylog_panel
  end
end
end # module Vimamsa
