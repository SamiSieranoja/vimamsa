
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
  dialog.add_css_class("vma-dialog")
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
  dialog.add_css_class("vma-dialog")
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
  attr_accessor :buffers, :sw1, :sw2, :view, :buf1, :window, :delex, :statnfo, :overlay, :sws, :two_c, :scheme_is_light, :cyber_css_provider, :chrome_css_provider, :minibuf_css_provider, :orig_icon_theme
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

    provider = Gtk::CssProvider.new
    provider.load(data: minibuf_css)   # colors from gui_theme.rb (cnf-backed)
    self.minibuf_css_provider = provider

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

      # Periodic timeouts, not idles that always return true: an idle that is
      # always ready keeps GLib from ever dispatching lower-priority sources,
      # e.g. GtkSourceView's matching-bracket highlight never ran.
      GLib::Timeout.add(200) { debug_idle_func }

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

      # Persistent status slots for long-running work that outlives a minibuf
      # line — e.g. dictation reporting that its speech model is still loading.
      # Modules claim a slot by key via #set_status_indicator; core attaches no
      # meaning to the keys.
      @status_indicators = {}
      @status_indicator_css = {}
      @status_indicator_box = Gtk::Box.new(:horizontal, 6)

      @statbox = Gtk::Box.new(:horizontal, 6)
      @statbox.append(@subtitle)
      @subtitle.hexpand = true
      @statbox.append(@status_indicator_box)
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

      # Size the window before it is first shown (see apply_startup_window_size)
      apply_startup_window_size
      @window.signal_connect("map") { layout_recheck_monitor }
      @window.show

      surface = @window.native.surface
      tt = Time.now
      surface.signal_connect("layout") do
        # puts "Window resized or moved, other redraw."
      end


      # Baseline chrome CSS + all its colors live in gui_theme.rb (cnf-backed).
      # See gtk-4.9.4/gtk/theme/Default/_common.scss  on how to theme
      # gtksourceview/gtksourcestyleschemepreview.c
      # gtksourceview/gtksourcestylescheme.c
      prov = Gtk::CssProvider.new
      prov.load(data: base_chrome_css)
      self.chrome_css_provider = prov
      @window.style_context.add_provider(prov)

      sc = Gtk::StyleContext.add_provider_for_display(Gdk::Display.default, prov)

      vma.start

      # After vma.start: user settings.rb (which may enable the theme) is
      # loaded during Editor#start. Refresh reads any cnf color overrides and
      # installs the cyberpunk provider if enabled.
      gui_refresh_colors
    end

    GLib::Timeout.add(200) { self.monitor }

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

  # Show a persistent status message in its own slot in the status area, for
  # work that takes long enough that the user needs to see it is still going —
  # a minibuf line scrolls away and is easy to miss. `key` namespaces the slot
  # (one per module/feature), `text` nil or empty removes it, `css_class` styles
  # the label. Call from the main thread (GLib::Idle.add from a worker thread).
  def set_status_indicator(key, text, css_class: nil)
    return if @status_indicator_box.nil? # GUI not built yet
    label = @status_indicators[key]

    if text.nil? || text.to_s.empty?
      return if label.nil?
      @status_indicator_box.remove(label)
      @status_indicators.delete(key)
      @status_indicator_css.delete(key)
      return
    end

    if label.nil?
      label = Gtk::Label.new("")
      label.add_css_class("status-indicator")
      @status_indicators[key] = label
      @status_indicator_box.append(label)
    end

    if css_class != @status_indicator_css[key]
      prev = @status_indicator_css[key]
      label.remove_css_class(prev) if prev
      label.add_css_class(css_class) if css_class
      @status_indicator_css[key] = css_class
    end
    label.text = text.to_s
  end

  # Text currently shown in a status slot, nil when the slot is empty.
  def status_indicator(key)
    @status_indicators[key]&.text
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
    @sw_width ||= swa.width
    # Detect element resize
    if swa.width != @sw_width
      debug "Width change sw_width #{@sw_width}"
      @sw_width = swa.width
      DelayExecutioner.exec(id: :scale_images, wait: 0.7, callable: proc { debug ":scale_images"; vma.gui.scale_all_images })
    end
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
    save_window_layout
  end

  def set_one_column
    return if !@two_column
    #This always closes the leftmost column/window
    #TODO: close rightmost column if left active
    set_active_window(1)
    @column_split = @pane.position # kept for the next set_two_column

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
    @pane.set_position(@column_split) if @column_split.to_i > 0
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

  # Wrap a side panel widget and the current editor content in a horizontal
  # Paned with the panel on the left at the given divider position.
  def make_side_pane(panel_widget, inner, pos)
    pane = Gtk::Paned.new(:horizontal)
    pane.hexpand = true
    pane.vexpand = true
    pane.set_start_child(panel_widget)
    pane.set_end_child(inner)
    # The panel keeps its width when the window is resized (or maximized
    # during startup); the editor takes the difference
    pane.resize_start_child = false
    pane.set_position(pos)
    pane
  end

  def file_panel_init
    @file_panel = FileTreePanel.new
    @file_panel_shown = false
  end

  def file_panel_refresh
    return unless @file_panel_shown
    @file_panel.refresh
  end

  # Marks of the current buffer changed (set, or shifted by an edit): update
  # the panel's marks section, coalescing bursts (typing) into one update.
  def file_panel_marks_changed
    return unless @file_panel_shown
    return if @file_panel_marks_pending
    @file_panel_marks_pending = true
    GLib::Timeout.add(300) do
      @file_panel_marks_pending = false
      @file_panel.refresh_marks if @file_panel_shown
      false
    end
  end

  def file_panel_shown?
    @file_panel_shown
  end

  # alt-h / alt-l: previous/next file in the panel's display order.
  # A no-op while the panel is hidden.
  def file_panel_select_adjacent(delta)
    return unless @file_panel_shown
    @file_panel.select_adjacent(delta)
  end

  # g s: label the panel's file rows and switch to the file whose label is
  # typed (see FileTreePanel#easy_jump_start). A no-op while the panel is hidden.
  def file_panel_easy_jump
    return unless @file_panel_shown
    @file_panel.easy_jump_start
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
    @file_panel_pane = make_side_pane(@file_panel.widget, inner, @file_panel_width || PANEL_DEFAULT_WIDTH[:file_panel])
    set_editor_area(@file_panel_pane)
    @file_panel_shown = true
    @file_panel.refresh
  end

  def hide_file_panel
    return unless @file_panel_shown
    @file_panel_width = @file_panel_pane.position
    inner = @file_panel_pane.end_child
    @file_panel_pane.set_start_child(nil)
    @file_panel_pane.set_end_child(nil)
    set_editor_area(inner)
    @file_panel_shown = false
  end

  # The shown/hidden state is remembered across restarts (see
  # save_window_layout). Tests toggle the panel too; they must not clobber it.
  def toggle_file_panel
    @file_panel_shown ? hide_file_panel : show_file_panel
    save_window_layout
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
    @func_panel_pane = make_side_pane(@func_panel.widget, inner, @func_panel_width || PANEL_DEFAULT_WIDTH[:func_panel])
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
    @func_panel_width = @func_panel_pane.position
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
    save_window_layout
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
    set_keylog_width(@keylog_width) if @keylog_width
  end

  def hide_keylog_panel
    return unless @keylog_shown
    @keylog_width = keylog_width
    @keylog_panel.set_active(false)
    @keylog_pane.set_start_child(nil)
    @keylog_pane.set_end_child(nil)
    @vbox.remove(@keylog_pane)
    @vbox.attach(@minibuf_vpane, 0, 2, 2, 1)
    @keylog_shown = false
  end

  def toggle_keylog_panel
    @keylog_shown ? hide_keylog_panel : show_keylog_panel
    save_window_layout
  end

  # ── Window geometry and view layout, restored on startup ─────────────────
  # doc/TODO.md: "Restore window geometry and view layout on startup".
  # Saved by Editor#save_state (shutdown, restart) and when a column or panel
  # is toggled, to get_data_path("window_layout"): one layout per screen
  # resolution ("1920x1080@1" = logical monitor size @ scale factor), the
  # LAYOUT_KEEP most recently used. With no layout for the current resolution
  # the most recent one is fitted to the screen (fit_view_layout). GTK4 can't
  # place windows on Wayland, so only the size and maximized state are kept.
  # Test runs neither read nor write it; cnf.restore_layout = false turns it off.

  LAYOUT_FILE = "window_layout"
  LAYOUT_KEEP = 5
  EDITOR_MIN_WIDTH = 300
  WINDOW_MIN_SIZE = 600
  DEFAULT_WINDOW_SIZE = [1000, 800]
  PANEL_DEFAULT_WIDTH = { :file_panel => 180, :func_panel => 160, :keylog => 320 }
  SIDE_PANELS = [:file_panel, :func_panel, :keylog]

  def layout_enabled?
    !vma_test_mode? && cnf.restore_layout? != false
  end

  # Monitor the window is on. Before the window is mapped that isn't known:
  # then the first monitor (layout_recheck_monitor corrects a wrong guess).
  def layout_monitor
    d = Gdk::Display.default
    surface = (@window.native&.surface rescue nil)
    m = (d.get_monitor_at_surface(surface) rescue nil) if surface
    m || (d.monitors.get_item(0) rescue nil)
  end

  def monitor_key(m)
    return "unknown" if m.nil?
    g = m.geometry
    "#{g.width}x#{g.height}@#{m.scale_factor}"
  end

  def monitor_size(m)
    return [100_000, 100_000] if m.nil?
    g = m.geometry
    [g.width, g.height]
  end

  def file_panel_width
    @file_panel_shown ? @file_panel_pane.position : @file_panel_width
  end

  def func_panel_width
    @func_panel_shown ? @func_panel_pane.position : @func_panel_width
  end

  def keylog_width
    return @keylog_width unless @keylog_shown && @keylog_pane.width > 0
    @keylog_pane.width - @keylog_pane.position
  end

  # The key log is on the right: its divider position depends on the total
  # width, which is known only once the pane has been allocated.
  def set_keylog_width(w)
    tries = 0
    GLib::Timeout.add(50) {
      if !@keylog_shown
        false
      elsif @keylog_pane.width > 0
        @keylog_pane.position = [@keylog_pane.width - w, EDITOR_MIN_WIDTH].max
        false
      else
        (tries += 1) < 100
      end
    }
  end

  # Current geometry and layout as a Hash (see apply_view_layout). Widths are
  # in pixels, plus as a fraction of the window width (:frac) for a screen of
  # another size.
  def window_layout
    max = @window.maximized?
    # While maximized, the default size is the size to unmaximize to
    width, height = max ? [@window.default_width, @window.default_height] : [@window.width, @window.height]
    win_w = @window.width
    part = ->(shown, w) {
      { :shown => !!shown, :width => w, :frac => (w && win_w > 0 ? w.to_f / win_w : nil) }
    }
    w2 = @two_column && @windows[2] && @windows[2][:sw].child
    {
      :width => width, :height => height, :maximized => max, :win_width => win_w,
      :file_panel => part.(@file_panel_shown, file_panel_width),
      :func_panel => part.(@func_panel_shown, func_panel_width),
      :keylog => part.(@keylog_shown, keylog_width),
      :two_column => part.(@two_column, @two_column ? @pane.position : @column_split),
      :column2_file => (w2.respond_to?(:bufo) ? w2.bufo.fname : nil),
      :minibuf_history_height => @minibuf_history_height,
    }
  end

  def load_layouts
    f = get_data_path(LAYOUT_FILE)
    h = File.exist?(f) ? Marshal.load(File.binread(f)) : {}
    h.class == Hash ? h : {}
  rescue => ex
    debug "load_layouts failed: #{ex}"
    {}
  end

  # all with layout l stored under key, keeping the LAYOUT_KEEP most recent
  def merge_layouts(all, key, l, now = Time.now.to_f)
    all = all.merge(key => l.merge(:used => now))
    all.sort_by { |_k, v| -v[:used].to_f }.first(LAYOUT_KEEP).to_h
  end

  def save_window_layout
    return if !layout_enabled? || @window.nil?
    all = merge_layouts(load_layouts, monitor_key(layout_monitor), window_layout)
    File.binwrite(get_data_path(LAYOUT_FILE), Marshal.dump(all))
  rescue => ex
    debug "save_window_layout failed: #{ex}"
  end

  # Layout to start with on a key/mw x mh monitor: the one saved for this
  # resolution, else the most recently used one fitted to this screen.
  # Never nil: with nothing saved, the default window and no panels.
  def pick_layout(all, key, mw, mh)
    return fit_view_layout(all[key], mw, mh, true) if all[key]
    recent = all.values.max_by { |v| v[:used].to_f }
    if recent.nil? && vma.marshal_load("file_panel_shown", false)
      recent = { :file_panel => { :shown => true } } # saved by older versions
    end
    fit_view_layout(recent || {}, mw, mh, recent.nil?)
  end

  # Fit saved layout l to a mw x mh monitor. exact = saved for this
  # resolution: only clamp to the monitor. Otherwise (layout from another
  # screen) limit the window to 90% of the monitor, don't maximize if the
  # saved window was bigger than the screen, and scale the widths by their
  # fraction of the window width. Side panels that would leave the editor
  # narrower than EDITOR_MIN_WIDTH are hidden.
  def fit_view_layout(saved, mw, mh, exact)
    l = Marshal.load(Marshal.dump(saved || {}))
    w, h = l[:width], l[:height]
    if w.to_i <= 0 || h.to_i <= 0
      # First start: the default size, leaving some room on a small screen
      # (a window nearly as big as the screen gets maximized by e.g. GNOME)
      w, h = DEFAULT_WINDOW_SIZE
      exact = false
    end
    if exact
      w, h = [w, mw].min, [h, mh].min
    else
      l[:maximized] = false if w > mw || h > mh
      w, h = [w, (mw * 0.9).to_i].min, [h, (mh * 0.9).to_i].min
    end
    l[:width] = [w, [WINDOW_MIN_SIZE, mw].min].max
    l[:height] = [h, [WINDOW_MIN_SIZE, mh].min].max
    l[:maximized] = !!l[:maximized]

    # Width the window will have. Maximized, that's the monitor minus panels
    # and docks (e.g. GNOME's), which isn't known here: approximately mw.
    eff = l[:maximized] ? mw : l[:width]
    # Saved on this resolution: the pixel widths are right as they are
    same = exact || eff == l[:win_width]
    (SIDE_PANELS + [:two_column]).each { |k|
      p = (l[k] ||= {})
      p[:shown] = !!p[:shown]
      p[:width] = (p[:frac] * eff).round if !same && p[:frac] && p[:width]
    }
    side = ->() {
      SIDE_PANELS.sum { |k| l[k][:shown] ? (l[k][:width] || PANEL_DEFAULT_WIDTH[k]) : 0 }
    }
    [:keylog, :func_panel, :file_panel].each { |k|
      break if eff - side.() >= EDITOR_MIN_WIDTH
      l[k][:shown] = false
    }
    # Split of the two columns: inside the editor area
    sp = l[:two_column][:width]
    l[:two_column][:width] = nil if sp && sp >= eff - side.() - 100
    l
  end

  # Before the window is first shown: pick the layout for this screen and
  # size the window (GTK ignores a new default size once it is mapped).
  # The columns and panels come later, in restore_view_layout.
  def apply_startup_window_size
    m = layout_monitor
    mw, mh = monitor_size(m)
    @startup_monitor_key = monitor_key(m)
    l = layout_enabled? ? pick_layout(load_layouts, @startup_monitor_key, mw, mh) : fit_view_layout({}, mw, mh, true)
    @startup_layout = l
    @window.set_size_request([WINDOW_MIN_SIZE, mw].min, [WINDOW_MIN_SIZE, mh].min)
    @window.set_default_size(l[:width], l[:height])
    @window.maximize if l[:maximized]
  end

  # On the first map the real monitor is known. If it isn't the one guessed
  # in apply_startup_window_size, use the layout for the real one.
  def layout_recheck_monitor
    return if @layout_rechecked || !layout_enabled?
    @layout_rechecked = true
    GLib::Timeout.add(300) {
      m = layout_monitor
      key = monitor_key(m)
      if key != @startup_monitor_key
        mw, mh = monitor_size(m)
        l = pick_layout(load_layouts, key, mw, mh)
        @startup_layout = l
        l[:maximized] ? @window.maximize : @window.set_default_size(l[:width], l[:height])
        apply_view_layout(l) if @view_layout_restored
      end
      false
    }
  end

  # Called at startup once the first buffer exists: columns and panels.
  def restore_view_layout
    return if !layout_enabled? || @startup_layout.nil?
    apply_view_layout(@startup_layout)
    @view_layout_restored = true
  end

  # Show the columns and panels of layout l (from window_layout or
  # fit_view_layout) with their widths. Columns go first: show_file_panel /
  # show_func_panel wrap whatever is in the editor area.
  def apply_view_layout(l)
    got = ->(k) { l[k] || {} }
    @column_split = got.(:two_column)[:width] || @column_split
    @file_panel_width = got.(:file_panel)[:width] || @file_panel_width
    @func_panel_width = got.(:func_panel)[:width] || @func_panel_width
    @keylog_width = got.(:keylog)[:width] || @keylog_width
    @minibuf_history_height = l[:minibuf_history_height] if l[:minibuf_history_height]

    got.(:two_column)[:shown] ? set_two_column : set_one_column
    got.(:func_panel)[:shown] ? show_func_panel : hide_func_panel
    got.(:file_panel)[:shown] ? show_file_panel : hide_file_panel
    got.(:keylog)[:shown] ? show_keylog_panel : hide_keylog_panel
    # Already shown panels keep their old widths otherwise
    @pane.set_position(@column_split) if @two_column && @column_split.to_i > 0
    @file_panel_pane.set_position(@file_panel_width) if @file_panel_shown && @file_panel_width.to_i > 0
    @func_panel_pane.set_position(@func_panel_width) if @func_panel_shown && @func_panel_width.to_i > 0
    set_keylog_width(@keylog_width) if @keylog_shown && @keylog_width.to_i > 0
    @column2_file = l[:column2_file]
    restore_column2_buffer
  end

  # Put the file that was in the second column back there, once it is open
  # (the session's files load after the layout; see restore_session_files).
  def restore_column2_buffer
    return if !@two_column || @column2_file.nil?
    id = vma.buffers.get_buffer_by_filename(@column2_file)
    return if id.nil? || id == vma.buf.id
    set_buffer_to_window(id, 2)
    @column2_file = nil
  end
end
end # module Vimamsa
