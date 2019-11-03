class Grep
  attr_accessor :history

  def initialize()
  end
end

def gui_grep()
  callback = proc{|x| grep_cur_buffer(x)}
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
      $grep_matches << i+1 # Lines start from index 1
    end
  }
  $grep_bufid = $buffers.current_buf
  b = create_new_file(nil, res_str)
  # set_current_buffer(buffer_i, update_history = true)
  # @current_buf = buffer_i

  b.line_action_handler = proc { |lineno|
    puts "GREP HANDLER:#{lineno}"
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
  params = {}
  params["title"] = title
  params["input1_label"] = field_label
  params["input1"] = ""
  params["input2_label"] = nil
  params["input2"] = nil
  params["callback"] = callback
  
  $prevent_carbage_collect_hack = callback # TODO

  params["button1"] = button_title
  qt_popup_window(params)
end

def gui_replace_callback(search_str, replace_str)
  puts "gui_replace_callback: #{search_str} => #{replace_str}"
  qt_select_window_close(0)
  buf_replace(search_str, replace_str)
end

# Search and replace text via GUI interface
def gui_search_replace()
  params = {}
  params["title"] = "Search & Replace:"
  params["input1_label"] = "Search:"
  params["input1"] = "rep"
  params["input2_label"] = "Replace:"
  params["input2"] = ""
  params["callback"] = "gui_replace_callback"

  params["button1"] = "Replace all"
  qt_popup_window(params)
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
      $do_center = 1
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
