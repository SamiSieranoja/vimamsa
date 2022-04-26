class Grep
  attr_accessor :history

  def initialize()
  end
end

class FileSelector
  def initialize()
    @buf = nil
  end

  def run
    ld = buflist.get_last_dir
    dir_to_buf(ld)
    # puts "ld=#{ld}"
    # dlist = Dir["#{ld}/*"]
  end

  def dir_to_buf(dirpath, b = nil)
    @ld = dirpath
    @dlist = Dir.children(@ld)
    @cdirs = []
    @cfiles = []
    for x in @dlist
      if File.directory?(fullp(x))
        @cdirs << x
      else
        @cfiles << x
      end
    end
    s = "..\n"
    s << @cdirs.join("\n")
    s << @cfiles.join("\n")

    if @buf.nil?
      @buf = create_new_file(nil, s)
      @buf.module = self
      @buf.active_kbd_mode = :file_exp
    else
      @buf.set_content(s)
    end
  end

  def fullp(fn)
    "#{@ld}/#{fn}"
  end

  def select_line
    # puts "def select_line"
    fn = fullp(@buf.get_current_line[0..-2])
    if File.directory?(fn)
      debug "CHDIR: #{fn}"
      dir_to_buf(fn)
    # elsif vma.can_open_extension?(fn) #TODO: remove this check?
      # jump_to_file(fn)
    elsif file_is_text_file(fn)
      jump_to_file(fn)
    else
      open_with_default_program(fn)
    end
  end
end

def gui_grep()
  callback = proc { |x| grep_cur_buffer(x) }
  # gui_one_input_action("Grep", "Search:", "grep", "grep_cur_buffer")
  gui_one_input_action("Grep", "Search:", "grep", callback)
end

def grep_cur_buffer(search_str, b = nil)
  debug "grep_cur_buffer(search_str)"
  lines = $buffer.split("\n")
  r = Regexp.new(Regexp.escape(search_str), Regexp::IGNORECASE)
  fpath = ""
  fpath = $buffer.pathname.expand_path.to_s + ":" if $buffer.pathname
  res_str = ""

  $grep_matches = []
  lines.each_with_index { |l, i|
    if r.match(l)
      # res_str << "#{fpath}#{i + 1}:#{l}\n"
      res_str << "#{i + 1}:#{l}\n"
      $grep_matches << i + 1 # Lines start from index 1
    end
  }
  $grep_bufid = $buffers.current_buf
  b = create_new_file(nil, res_str)
  # set_current_buffer(buffer_i, update_history = true)
  # @current_buf = buffer_i

  b.line_action_handler = proc { |lineno|
    debug "GREP HANDLER:#{lineno}"
    jumpto = $grep_matches[lineno]
    if jumpto.class == Integer
      $buffers.set_current_buffer($grep_bufid, update_history = true)
      buf.jump_to_line(jumpto)
    end
  }
end

def invoke_grep_search()
  start_minibuffer_cmd("", "", :grep_cur_buffer)
end

def gui_one_input_action(title, field_label, button_title, callback)
  a = OneInputAction.new(nil, title, field_label, button_title, callback)
  a.run
  return
end

# def gui_replace_callback(search_str, replace_str)
def gui_replace_callback(vals)
  search_str = vals["search"]
  replace_str = vals["replace"]
  debug "gui_replace_callback: #{search_str} => #{replace_str}"
  gui_select_window_close(0)
  buf_replace(search_str, replace_str)
end

# Search and replace text via GUI interface
def gui_search_replace()
  params = {}
  params["inputs"] = {}
  params["inputs"]["search"] = { :label => "Search", :type => :entry }
  params["inputs"]["replace"] = { :label => "Replace", :type => :entry }
  params["inputs"]["btn1"] = { :label => "Replace all", :type => :button }
  callback = proc { |x| gui_replace_callback(x) }

  params[:callback] = callback
  PopupFormGenerator.new(params).run
end

def invoke_replace()
  start_minibuffer_cmd("", "", :buf_replace_string)
end

def buf_replace(search_str, replace_str)
  if $buffer.visual_mode?
    r = $buffer.get_visual_mode_range
    txt = $buffer[r]
    txt.gsub!(search_str, replace_str)
    $buffer.replace_range(r, txt)
    $buffer.end_visual_mode
  else
    repbuf = $buffer.to_s.clone
    repbuf.gsub!(search_str, replace_str)
    tmppos = $buffer.pos
    if repbuf == $buffer.to_s.clone
      message("NO CHANGE. Replacing #{search_str} with #{replace_str}.")
    else
      $buffer.set_content(repbuf)
      $buffer.set_pos(tmppos)
      message("Replacing #{search_str} with #{replace_str}.")
    end
  end
end

# Requires instr in form "FROM/TO"
# Replaces all occurences of FROM with TO
def buf_replace_string(instr)
  # puts "buf_replace_string(instr=#{instr})"

  a = instr.split("/")
  if a.size != 2
    return
  end
  buf_replace(a[0], a[1])
end

# PopupFormGenerator.new().run
class PopupFormGenerator
  def submit()
    ret = {}
    for id, entry in @vals
      ret[id] = entry.text
    end
    @callback.call(ret)
    @window.destroy
  end

  def initialize(params = nil)
    @window = Gtk::Window.new(:toplevel)
    # @window.screen = main_window.screen
    # @window.title = title
    # params = {}
    # params["inputs"] = {}
    # params["inputs"]["search"] = { :label => "Search", :type => :entry }
    # params["inputs"]["replace"] = { :label => "Replace", :type => :entry }
    # params["inputs"]["btn1"] = { :label => "Replace all", :type => :button }
    # params[:callback] = proc { |x| puts "====="; puts x.inspect; puts "=====" }

    @callback = params[:callback]
    @window.title = ""

    frame = Gtk::Frame.new()
    frame.margin = 8
    @window.add(frame)

    # @window.title = params["title"]

    # @callback = params["callback"]

    infolabel = Gtk::Label.new
    # infolabel.markup = params["title"]

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin = 8
    frame.add(vbox)

    hbox = Gtk::Box.new(:horizontal, 8)
    # @window.add(hbox)
    @vals = {}

    for id, elem in params["inputs"]
      if elem[:type] == :button
        button = Gtk::Button.new(:label => elem[:label])
        hbox.pack_start(button, :expand => false, :fill => false, :padding => 0)
        button.signal_connect "clicked" do
          submit
        end
      elsif elem[:type] == :entry
        label = Gtk::Label.new(elem[:label])
        entry = Gtk::Entry.new
        hbox.pack_start(label, :expand => false, :fill => false, :padding => 0)
        hbox.pack_start(entry, :expand => false, :fill => false, :padding => 0)
        @vals[id] = entry

        entry.signal_connect("key_press_event") do |widget, event|
          if event.keyval == Gdk::Keyval::KEY_Return
            submit
            true
          elsif event.keyval == Gdk::Keyval::KEY_Escape
            @window.destroy
            true
          else
            false
          end
        end
      end
    end

    vbox.pack_start(hbox, :expand => false, :fill => false, :padding => 0)

    cancel_button = Gtk::Button.new(:label => "Cancel")
    cancel_button.signal_connect "clicked" do
      @window.destroy
    end
    hbox.pack_start(cancel_button, :expand => false, :fill => false, :padding => 0)

    return
  end

  def run
    if !@window.visible?
      @window.show_all
    else
      @window.destroy
    end
    @window
  end
end

class OneInputAction
  def initialize(main_window, title, field_label, button_title, callback)
    @window = Gtk::Window.new(:toplevel)
    # @window.screen = main_window.screen
    # @window.title = title
    @window.title = ""

    frame = Gtk::Frame.new()
    frame.margin = 8
    @window.add(frame)

    infolabel = Gtk::Label.new
    infolabel.markup = title

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin = 8
    frame.add(vbox)

    hbox = Gtk::Box.new(:horizontal, 8)
    # @window.add(hbox)
    vbox.pack_start(infolabel, :expand => false, :fill => false, :padding => 0)
    vbox.pack_start(hbox, :expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => button_title)
    cancel_button = Gtk::Button.new(:label => "Cancel")

    label = Gtk::Label.new(field_label)

    @entry1 = Gtk::Entry.new

    button.signal_connect "clicked" do
      callback.call(@entry1.text)
      @window.destroy
    end

    cancel_button.signal_connect "clicked" do
      @window.destroy
    end

    @entry1.signal_connect("key_press_event") do |widget, event|
      if event.keyval == Gdk::Keyval::KEY_Return
        callback.call(@entry1.text)
        @window.destroy
        true
      elsif event.keyval == Gdk::Keyval::KEY_Escape
        @window.destroy
        true
      else
        false
      end
    end

    hbox.pack_start(label, :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(@entry1, :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(button, :expand => false, :fill => false, :padding => 0)
    hbox.pack_start(cancel_button, :expand => false, :fill => false, :padding => 0)
    return
  end

  def run
    if !@window.visible?
      @window.show_all
    else
      @window.destroy
    end
    @window
  end
end
