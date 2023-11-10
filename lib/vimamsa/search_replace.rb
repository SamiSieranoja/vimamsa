
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

class Grep
  attr_reader :buf
  @@cur = nil # Current object of class

  def self.cur()
    return @@cur
  end

  def self.init()
    vma.kbd.add_minor_mode("grep", :grep, :command)

    if cnf.experimental?
      bindkey "grep shift!", [:grep_apply_changes, proc {
        if vma.buf.module.class == Grep
          vma.buf.module.apply_changes
        else
          debug vma.buf.module, 2
          message("ERROR")
        end
      }, "Write changes edited in grep buffer to the underlying file"]
    end
    vma.kbd.add_minor_mode("bmgr", :buf_mgr, :command)
    reg_act(:grep_buffer, proc { Grep.new.run }, "Grep current buffer")
    reg_act(:grep_refresh, proc {
      if vma.buf.module.class == Grep
        vma.buf.module.refresh
      end
    }, "Refresh current Grep buffer")

    bindkey "C , g", :grep_buffer
    bindkey "grep ctrl-r", :grep_refresh
  end

  def apply_changes()
    b = @orig_buf
    gb = vma.buf
    changed = 0
    gb.lines.each { |x|
      if m = x.match(/(\d+):(.*)/m)
        lineno = m[1].to_i
        newl = m[2]
        r = @orig_buf.line_range(lineno - 1, 1)
        old = @orig_buf[r.first..r.last]
        if old != newl
          @orig_buf.replace_range(r, newl)
          changed += 1
        end
      end
    }
    message("GREP: apply changes, #{changed} changed lines")
  end

  def initialize()
    @buf = nil
    @line_to_id = {}
  end

  def refresh
    set_buf_contents
  end

  def set_buf_contents()
    lines = @orig_buf.split("\n")

    @grep_matches = []

    res_str = ""
    lines.each_with_index { |l, i|
      if @r.match(l)
        res_str << "#{i + 1}:"
        # ind = scan_indexes(l, r)
        res_str << "#{l}\n"
        @grep_matches << i + 1 # Lines start from index 1
      end
    }

    @buf.set_content(res_str)

    Gui.highlight_match(@buf, @search_str, color: cnf.match.highlight.color!)
  end

  def callback(search_str, b = nil)
    debug "grep_cur_buffer(search_str)"
    @r = Regexp.new(Regexp.escape(search_str), Regexp::IGNORECASE)
    fpath = ""
    fpath = vma.buf.pathname.expand_path.to_s + ":" if vma.buf.pathname

    @search_str = search_str
    @orig_buf = vma.buf
    @buf = create_new_buffer("", "grep")

    @buf.default_mode = :grep
    @buf.module = self

    vma.kbd.set_default_mode(:grep)
    @buf.line_action_handler = proc { |lineno|
      debug "GREP HANDLER:#{lineno}"
      jumpto = @grep_matches[lineno]
      if jumpto.class == Integer
        vma.buffers.set_current_buffer_by_id(@orig_buf.id)
        @orig_buf.jump_to_line(jumpto)
      end
    }

    set_buf_contents
  end

  def run()
    callb = self.method("callback")
    gui_one_input_action("Grep", "Search:", "grep", callb)
  end
end

def gui_one_input_action(title, field_label, button_title, callback, opt = {})
  a = OneInputAction.new(nil, title, field_label, button_title, callback, opt)
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
  if vma.buf.visual_mode?
    r = vma.buf.get_visual_mode_range
    txt = vma.buf[r]
    txt.gsub!(search_str, replace_str)
    vma.buf.replace_range(r, txt)
    vma.buf.end_visual_mode
  else
    repbuf = vma.buf.to_s.clone
    repbuf.gsub!(search_str, replace_str)
    tmppos = vma.buf.pos
    if repbuf == vma.buf.to_s.clone
      message("NO CHANGE. Replacing #{search_str} with #{replace_str}.")
    else
      vma.buf.set_content(repbuf)
      vma.buf.set_pos(tmppos)
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
