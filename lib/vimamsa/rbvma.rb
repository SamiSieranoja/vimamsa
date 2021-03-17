require "gtk3"
require "gtksourceview3"
#require "gtksourceview4"
require "ripl"
require "fileutils"
require "pathname"
require "date"
require "ripl/multi_line"
require "json"
require "listen"

puts "INIT rbvma"

require "vimamsa/util"
# require "rbvma/rbvma"
require "vimamsa/main" #
require "vimamsa/key_binding_tree" #
require "vimamsa/actions" #
require "vimamsa/macro" #
require "vimamsa/buffer" #
require "vimamsa/debug" #
require "vimamsa/constants"
require "vimamsa/easy_jump"
require "vimamsa/hook"
require "vimamsa/search"
require "vimamsa/search_replace"
require "vimamsa/buffer_list"
require "vimamsa/file_finder"
require "vimamsa/hyper_plain_text"
require "vimamsa/ack"
require "vimamsa/encrypt"
require "vimamsa/file_manager"

# load "vendor/ver/lib/ver/vendor/textpow.rb"
# load "vendor/ver/lib/ver/syntax/detector.rb"
# load "vendor/ver/config/detect.rb"

$vma = Editor.new

def vma()
  return $vma
end

$idle_scroll_to_mark = false

def idle_func
  # puts "IDLEFUNC"
  if $idle_scroll_to_mark
    # Ripl.start :binding => binding
    # $view.get_visible_rect
    vr = $view.visible_rect

    # iter = b.get_iter_at(:offset => i)

    b = $view.buffer
    iter = b.get_iter_at(:offset => b.cursor_position)
    iterxy = $view.get_iter_location(iter)
    # puts "ITERXY" + iterxy.inspect
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

# qt_select_update_window(l, $select_keys.collect { |x| x.upcase },
# "gui_find_macro_select_callback",
# "gui_find_macro_update_callback")
class SelectUpdateWindow
  COLUMN_JUMP_KEY = 0
  COLUMN_DESCRIPTION = 1

  def update_item_list(item_list)
    # puts item_list.inspect
    # Ripl.start :binding => binding
    @model.clear
    for item in item_list
      iter = @model.append
      v = ["", item[0]]
      puts v.inspect
      iter.set_values(v)
    end

    set_selected_row(0)
  end

  def set_selected_row(rownum)
    rownum = 0 if rownum < 0
    @selected_row = rownum

    if @model.count > 0
      path = Gtk::TreePath.new(@selected_row.to_s)
      iter = @model.get_iter(path)
      @tv.selection.select_iter(iter)
    end
  end

  def initialize(main_window, item_list, jump_keys, select_callback, update_callback)
    @window = Gtk::Window.new(:toplevel)
    # @window.screen = main_window.screen
    @window.title = "List Store"

    @selected_row = 0

    puts item_list.inspect
    @update_callback = method(update_callback)
    @select_callback = method(select_callback)
    # puts @update_callback_m.call("").inspect

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin = 8
    @window.add(vbox)

    @entry = Gtk::SearchEntry.new
    @entry.width_chars = 45
    container = Gtk::Box.new(:horizontal, 10)
    # container.halign = :start
    container.halign = :center
    container.pack_start(@entry,
                         :expand => false, :fill => false, :padding => 0)

    # create tree view
    @model = Gtk::ListStore.new(String, String)
    treeview = Gtk::TreeView.new(@model)
    treeview.search_column = COLUMN_DESCRIPTION
    @tv = treeview
    # item_list = @update_callback.call("")
    update_item_list(item_list)

    # Ripl.start :binding => binding
    @window.signal_connect("key-press-event") do |_widget, event|
      # puts "KEYPRESS 1"
      @entry.handle_event(event)
    end

    @entry.signal_connect("key_press_event") do |widget, event|
      # puts "KEYPRESS 2"
      if event.keyval == Gdk::Keyval::KEY_Down
        puts "DOWN"
        set_selected_row(@selected_row + 1)
        # fixed = iter[COLUMN_FIXED]

        true
      elsif event.keyval == Gdk::Keyval::KEY_Up
        set_selected_row(@selected_row - 1)
        puts "UP"
        true
      elsif event.keyval == Gdk::Keyval::KEY_Return
        path = Gtk::TreePath.new(@selected_row.to_s)
        iter = @model.get_iter(path)
        ret = iter[1]
        @select_callback.call(ret, @selected_row)
        @window.destroy
        # puts iter[1].inspect
        true
      elsif event.keyval == Gdk::Keyval::KEY_Escape
        @window.destroy
        true
      else
        false
      end
    end

    @entry.signal_connect("search-changed") do |widget|
      puts "search changed: #{widget.text || ""}"
      item_list = @update_callback.call(widget.text)
      update_item_list(item_list)
      # label.text = widget.text || ""
    end
    @entry.signal_connect("changed") { puts "[changed] " }
    @entry.signal_connect("next-match") { puts "[next-match] " }

    label = Gtk::Label.new(<<-EOF)
    
    Search:
EOF
    vbox.pack_start(label, :expand => false, :fill => false, :padding => 0)

    vbox.pack_start(container, :expand => false, :fill => false, :padding => 0)
    sw = Gtk::ScrolledWindow.new(nil, nil)
    sw.shadow_type = :etched_in
    sw.set_policy(:never, :automatic)
    vbox.pack_start(sw, :expand => true, :fill => true, :padding => 0)

    sw.add(treeview)

    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new("JMP",
                                     renderer,
                                     "text" => COLUMN_JUMP_KEY)
    column.sort_column_id = COLUMN_JUMP_KEY
    treeview.append_column(column)

    renderer = Gtk::CellRendererText.new
    column = Gtk::TreeViewColumn.new("Description",
                                     renderer,
                                     "text" => COLUMN_DESCRIPTION)
    column.sort_column_id = COLUMN_DESCRIPTION
    treeview.append_column(column)

    @window.set_default_size(280, 500)
    puts "SelectUpdateWindow"
  end

  def run
    if !@window.visible?
      @window.show_all
      # add_spinner
    else
      @window.destroy
      # GLib::Source.remove(@tiemout) unless @timeout.zero?
      @timeout = 0
    end
    @window
  end
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

def qt_select_update_window(item_list, jump_keys, select_callback, update_callback)
  $selup = SelectUpdateWindow.new(nil, item_list, jump_keys, select_callback, update_callback)
  $selup.run
end

# ~/Drive/code/ruby-gnome/gtk3/sample/gtk-demo/search_entry2.rb
# ~/Drive/code/ruby-gnome/gtk3/sample/gtk-demo/list_store.rb

def qt_open_file_dialog(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Open file",
                                      :action => :open,
                                      :buttons => [[Gtk::Stock::OPEN, :accept],
                                                   [Gtk::Stock::CANCEL, :cancel]])
  dialog.set_current_folder(dirpath)

  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT
      open_new_file(dialog.filename)
      # puts "uri = #{dialog.uri}"
    end
    dialog.destroy
  end
  dialog.run
end

def qt_file_saveas(dirpath)
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

def qt_create_buffer(id)
  puts "qt_create_buffer(#{id})"
  buf1 = GtkSource::Buffer.new()
  view = VSourceView.new()

  view.set_highlight_current_line(true)
  view.set_show_line_numbers(true)
  view.set_buffer(buf1)

  ssm = GtkSource::StyleSchemeManager.new
  ssm.set_search_path(ssm.search_path << ppath("styles/"))
  #  sty = ssm.get_scheme("dark")
  sty = ssm.get_scheme("molokai_edit")
  # puts ssm.scheme_ids

  view.buffer.highlight_matching_brackets = true
  view.buffer.style_scheme = sty

  provider = Gtk::CssProvider.new
  provider.load(data: "textview { font-family: Monospace; font-size: 11pt; }")
  # provider.load(data: "textview { font-family: Arial; font-size: 12pt; }")
  view.style_context.add_provider(provider)
  view.wrap_mode = :char

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

def qt_process_deltas
end

def qt_add_image(imgpath, pos)
end

def qt_process_deltas
end

def qt_process_events
end

def qt_select_window_close(arg = nil)
end

# def set_window_title(str)
  # unimplemented
# end

def render_text(tmpbuf, pos, selection_start, reset)
  unimplemented
end

def qt_set_buffer_contents(id, txt)
  # $vbuf.set_text(txt)
  puts "qt_set_buffer_contents(#{id}, txt)"

  $vmag.buffers[id].buffer.set_text(txt)
end

def qt_set_cursor_pos(id, pos)
  $view.set_cursor_pos(pos)
  # Ripl.start :binding => binding
end

def qt_set_selection_start(id, selection_start)
end

def qt_set_current_buffer(id)
  view = $vmag.buffers[id]
  puts "qt_set_current_buffer(#{id}), view=#{view}"
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

def gui_set_window_title(wtitle,subtitle="")
  $vmag.window.title = wtitle
  $vmag.window.titlebar.subtitle = subtitle
end

def unimplemented
  puts "unimplemented"
end

def center_where_cursor
  unimplemented
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
  # puts "received_text=#{received_text}"
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
    # puts $clipboard[-1]
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

# module Rbvma
# # Your code goes here...
# def foo
# puts "BAR"
# end
# end
$debug = true

def scan_indexes(txt, regex)
  # indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) + 1 }
  indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) }
  return indexes
end

$update_cursor = false

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
      qt_set_cursor_pos($buffer.id, $buffer.pos) #TODO: only when necessary
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

class VMAg
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
    # puts "overlay_draw_text #{[x,y]}"
    (x, y) = @view.pos_to_coord(textpos)
    # puts "overlay_draw_text #{[x,y]}"
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
    # puts "startpos,endpos:#{[startpos, endpos]}"

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

    # puts @view.pos_to_coord(300).inspect

    @da.show_all
  end

  def init_keybindings
    $kbd = KeyBindingTree.new()
    $kbd.add_mode("C", :command)
    $kbd.add_mode("I", :insert)
    $kbd.add_mode("V", :visual)
    $kbd.add_mode("M", :minibuffer)
    $kbd.add_mode("R", :readchar)
    $kbd.add_mode("B", :browse)
    $kbd.set_default_mode(:command)
    require "default_key_bindings"

    $macro = Macro.new

    # bindkey "VC j", "buf.move(FORWARD_LINE)"
    bindkey "VC j", "puts('j_key_action')"
    bindkey "VC ctrl-j", "puts('ctrl_j_key_action')"

    bindkey "VC l", "buf.move(FORWARD_CHAR)"
    bindkey "C x", "buf.delete(CURRENT_CHAR_FORWARD)"
    # bindkey "C r <char>",  "buf.replace_with_char(<char>)"
    bindkey "I space", 'buf.insert_txt(" ")'

    bindkey "VC l", "buf.move(FORWARD_CHAR)"
    bindkey "VC j", "buf.move(FORWARD_LINE)"
    bindkey "VC k", "buf.move(BACKWARD_LINE)"
    bindkey "VC h", "buf.move(BACKWARD_CHAR)"
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
    @vpaned.pack2(overlay, :resize => false)
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

  def init_window
    @window = Gtk::Window.new(:toplevel)
    @window.set_default_size(650, 850)
    @window.title = "Multiple Views"
    @window.show_all
    # vpaned = Gtk::Paned.new(:horizontal)
    @vpaned = Gtk::Paned.new(:vertical)
    @window.add(@vpaned)

    @sw = Gtk::ScrolledWindow.new
    @sw.set_policy(:automatic, :automatic)
    @overlay = Gtk::Overlay.new
    @overlay.add(@sw)
    @vpaned.pack1(@overlay, :resize => true)

    init_minibuffer
    init_header_bar

    @window.show_all

    vma.start
  end
end
