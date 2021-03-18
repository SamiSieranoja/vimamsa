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

require "vimamsa/util"
require "vimamsa/main"

require "vimamsa/actions"
require "vimamsa/key_binding_tree"
require "vimamsa/key_actions"


require "vimamsa/gui"
require "vimamsa/gui_select_window"
require "vimamsa/gui_sourceview"

require "vimamsa/macro"
require "vimamsa/buffer"
require "vimamsa/debug"
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

def unimplemented
  puts "unimplemented"
end

# module Rbvma
# # Your code goes here...
# def foo
# puts "BAR"
# end
# end
$debug = false

def scan_indexes(txt, regex)
  # indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) + 1 }
  indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) }
  return indexes
end

$update_cursor = false


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
    # require "default_key_bindings"

    require "vimamsa/key_bindings_vimlike"

    $macro = Macro.new


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
