$idle_scroll_to_mark = false

def gui_open_file_dialog(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Open file",
                                      :action => :open,
                                      :buttons => [[Gtk::Stock::OPEN, :accept],
                                                   [Gtk::Stock::CANCEL, :cancel]])
  dialog.set_current_folder(dirpath)

  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT
      open_new_file(dialog.filename)
      # debug "uri = #{dialog.uri}"
    end
    dialog.destroy
  end
  dialog.run
end

def gui_file_saveas(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Save as",
                                      :action => :save,
                                      :buttons => [[Gtk::Stock::SAVE, :accept],
                                                   [Gtk::Stock::CANCEL, :cancel]])
  dialog.set_current_folder(dirpath)
  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT
      file_saveas(dialog.filename)
    end
    dialog.destroy
  end

  dialog.run
end

def idle_func
  # debug "IDLEFUNC"
  if $idle_scroll_to_mark
    # Ripl.start :binding => binding
    # $view.get_visible_rect
    vr = $view.visible_rect

    # iter = b.get_iter_at(:offset => i)

    b = $view.buffer
    iter = b.get_iter_at(:offset => b.cursor_position)
    iterxy = $view.get_iter_location(iter)
    # debug "ITERXY" + iterxy.inspect
    # Ripl.start :binding => binding

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
  # clipboard = $vmag.window.get_clipboard(Gdk::Selection::CLIPBOARD)
  utf8_string = Gdk::Atom.intern("UTF8_STRING")
  # x = clipboard.request_contents(utf8_string)

  widget = Gtk::Invisible.new
  clipboard = Gtk::Clipboard.get_default($vmag.window.display)
  received_text = ""

  target_string = Gdk::Selection::TARGET_STRING
  ti = clipboard.request_contents(target_string)

  # clipboard.request_contents(target_string) do |_clipboard, selection_data|
  # received_text = selection_data.text
  # debug "received_text=#{received_text}"
  # end
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
  # return if arg.class != String
  # return if s.size < 1
  # utf8_string = Gdk::Atom.intern("UTF8_STRING")
  widget = Gtk::Invisible.new
  clipboard = Gtk::Clipboard.get_default($vmag.window.display)
  clipboard.text = arg
end

def gui_create_buffer(id)
  debug "gui_create_buffer(#{id})"
  buf1 = GtkSource::Buffer.new()
  view = VSourceView.new()

  view.set_highlight_current_line(true)
  view.set_show_line_numbers(true)
  view.set_buffer(buf1)

  ssm = GtkSource::StyleSchemeManager.new
  ssm.set_search_path(ssm.search_path << ppath("styles/"))
  #  sty = ssm.get_scheme("dark")
  sty = ssm.get_scheme("molokai_edit")
  # debug ssm.scheme_ids

  view.buffer.highlight_matching_brackets = true
  view.buffer.style_scheme = sty

  provider = Gtk::CssProvider.new
  provider.load(data: "textview { font-family: Monospace; font-size: 11pt; }")
  # provider.load(data: "textview { font-family: Arial; font-size: 12pt; }")
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

# def set_window_title(str)
# unimplemented
# end

def gui_set_buffer_contents(id, txt)
  # $vbuf.set_text(txt)
  debug "gui_set_buffer_contents(#{id}, txt)"

  $vmag.buffers[id].buffer.set_text(txt)
end

def gui_set_cursor_pos(id, pos)
  $view.set_cursor_pos(pos)
  # Ripl.start :binding => binding
end

def gui_set_current_buffer(id)
  view = $vmag.buffers[id]
  debug "gui_set_current_buffer(#{id}), view=#{view}"
  buf1 = view.buffer
  $vmag.view = view
  $vmag.buf1 = buf1
  $view = view
  $vbuf = buf1

  $vmag.sw.remove($vmag.sw.child) if !$vmag.sw.child.nil?
  $vmag.sw.add(view)

  view.grab_focus
  #view.set_focus(10)
  view.set_cursor_visible(true)
  #view.move_cursor(1, 1, false)
  view.place_cursor_onscreen

  #TODO:
  # itr = view.buffer.get_iter_at(:offset => 0)
  # view.buffer.place_cursor(itr)

  # wtitle = ""
  # wtitle = buf.fname if !buf.fname.nil?
  $vmag.sw.show_all
end

def gui_set_window_title(wtitle, subtitle = "")
  $vmag.window.title = wtitle
  $vmag.window.titlebar.subtitle = subtitle
end

class VMAgui
  attr_accessor :buffers, :sw, :view, :buf1, :window

  VERSION = "1.0"

  HEART = "♥"
  RADIUS = 150
  N_WORDS = 5
  FONT = "Serif 18"
  TEXT = "I ♥ GTK+"

  def initialize()
    @show_overlay = true
    @da = nil
    @buffers = {}
    @view = nil
    @buf1 = nil
  end

  def run
    init_window
    # init_rtext
    Gtk.main
  end

  def start_overlay_draw()
    @da = Gtk::Fixed.new
    @overlay.add_overlay(@da)
    @overlay.set_overlay_pass_through(@da, true)
  end

  def clear_overlay()
    if @da != nil
      @overlay.remove(@da)
    end
  end

  def overlay_draw_text(text, textpos)
    # debug "overlay_draw_text #{[x,y]}"
    (x, y) = @view.pos_to_coord(textpos)
    # debug "overlay_draw_text #{[x,y]}"
    label = Gtk::Label.new("<span background='#00000088' foreground='#ff0000' weight='ultrabold'>#{text}</span>")
    label.use_markup = true
    @da.put(label, x, y)
  end

  def end_overlay_draw()
    @da.show_all
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

    @da.show_all
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
    startiter = @minibuf.buffer.get_iter_at(:offset => 0)
    @minibuf.buffer.insert(startiter, "#{msg}\n")
    @minibuf.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), -1, false)
  end

  def init_minibuffer()
    # Init minibuffer
    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    overlay = Gtk::Overlay.new
    overlay.add(sw)
    # @vpaned.pack2(overlay, :resize => false)
    @vbox.attach(overlay, 0, 2, 1, 1)
    # overlay.set_size_request(-1, 50)
    # $ovrl = overlay
    # $ovrl.set_size_request(-1, 30)
    $sw2 = sw
    sw.set_size_request(-1, 12)

    view = VSourceView.new()
    view.set_highlight_current_line(false)
    view.set_show_line_numbers(false)
    # view.set_buffer(buf1)
    ssm = GtkSource::StyleSchemeManager.new
    ssm.set_search_path(ssm.search_path << ppath("styles/"))
    sty = ssm.get_scheme("molokai_edit")
    view.buffer.highlight_matching_brackets = false
    view.buffer.style_scheme = sty
    provider = Gtk::CssProvider.new
    # provider.load(data: "textview { font-family: Monospace; font-size: 11pt; }")
    provider.load(data: "textview { font-family: Arial; font-size: 10pt; color:#ff0000}")
    view.style_context.add_provider(provider)
    view.wrap_mode = :char
    @minibuf = view
    # Ripl.start :binding => binding
    # startiter = view.buffer.get_iter_at(:offset => 0)
    message("STARTUP")
    sw.add(view)
  end

  def init_header_bar()
    header = Gtk::HeaderBar.new
    @header = header
    header.show_close_button = true
    header.title = ""
    header.has_subtitle = true
    header.subtitle = ""
    # Ripl.start :binding => binding

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
    @window.add(Gtk::TextView.new)
  end

  def create_menu_item(label, depth)
    menuitem = Gtk::MenuItem.new(:label => label)
    menuitem.submenu = create_menu(depth)
    @menubar.append(menuitem)
  end

  def create_menu(depth)
    return nil if depth < 1

    menu = Gtk::Menu.new
    last_item = nil
    (0..5).each do |i|
      j = i + 1
      label = "item #{depth} - #{j}"
      menu_item = Gtk::RadioMenuItem.new(nil, label)
      menu_item.join_group(last_item) if last_item
      last_item = menu_item
      menu.append(menu_item)
      menu_item.sensitive = false if i == 3
      menu_item.submenu = create_menu(depth - 1)
    end

    menu
  end

  def init_window
    @window = Gtk::Window.new(:toplevel)
    @window.set_default_size(650, 850)
    @window.title = "Multiple Views"
    @window.show_all
    # vpaned = Gtk::Paned.new(:horizontal)
    @vpaned = Gtk::Paned.new(:vertical)
    #@vpaned = Gtk::Box.new(:vertical, 0)
    # @vbox = Gtk::Box.new(:vertical, 0)
    @vbox = Gtk::Grid.new()
    @window.add(@vbox)

    @menubar = Gtk::MenuBar.new
    @menubar.expand = false
    

    @sw = Gtk::ScrolledWindow.new
    @sw.set_policy(:automatic, :automatic)
    @overlay = Gtk::Overlay.new
    @overlay.add(@sw)

    # @vpaned.pack1(@overlay, :resize => true)
    # @vpaned.pack2(@menubar, :resize => false)
    # @vbox.add(@menubar, :resize => false)

    init_header_bar

    # @window.show_all

    # @vbox.pack_start(@menubar, :expand => false, :fill => false, :padding => 0 )
    # @vbox.pack_start(@menubar)
    # @vbox.pack_start(@overlay, :expand => true, :fill => true, :padding => 0 )
    # @vbox.pack_start(@overlay, :expand => true, :fill => true, :padding => 0 )
    @vbox.attach(@menubar, 0, 0, 1, 1)
    @vbox.attach(@overlay, 0, 1, 1, 1)
    @overlay.vexpand = true
    @overlay.hexpand = true

    @menubar.vexpand = false
    @menubar.hexpand = false

    init_minibuffer


    @window.show_all
    vma.start
    Vimamsa::Menu.new(@menubar)
    @window.show_all
    
  end
end
