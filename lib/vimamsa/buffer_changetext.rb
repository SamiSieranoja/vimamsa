# Operations that change the content of the buffer
# e.g. insert, delete

class Buffer < String

  #TODO: change to apply=true as default
  def add_delta(delta, apply = false, auto_update_cpos = false)
    @t_modified = Time.now
    return if !is_delta_ok(delta)
    if delta[1] == DELETE
      return if delta[0] >= self.size
      # If go over length of buffer
      if delta[0] + delta[2] >= self.size
        delta[2] = self.size - delta[0]
      end
    end

    @edit_version += 1
    @redo_stack = []
    if apply
      delta = run_delta(delta, auto_update_cpos)
    else
      @deltas << delta
    end
    @edit_history << delta
    if self[-1] != "\n"
      add_delta([self.size, INSERT, 1, "\n"], true)
    end
    reset_larger_cpos #TODO: correct here?
    refresh_title
  end

  # TODO: rename ot auto-format. separate module?
  # Indents whole buffer using external program
  def indent()
    file = Tempfile.new("out")
    infile = Tempfile.new("in")
    file.write(self.to_s)
    file.flush
    bufc = "FOO"

    tmppos = @pos

    message("Auto format #{@fname}")

    ftype = get_file_type()
    if ["chdr", "c", "cpp", "cpphdr"].include?(ftype)

      #C/C++/Java/JavaScript/Objective-C/Protobuf code
      system("clang-format -style='{BasedOnStyle: LLVM, ColumnLimit: 100,  SortIncludes: false}' #{file.path} > #{infile.path}")
      bufc = IO.read(infile.path)
    elsif ftype == "Javascript"
      cmd = "clang-format #{file.path} > #{infile.path}'"
      debug cmd
      system(cmd)
      bufc = IO.read(infile.path)
    elsif ftype == "ruby"
      cmd = "rufo #{file.path}"
      debug cmd
      system(cmd)
      bufc = IO.read(file.path)
    else
      message("No auto-format handler for file of type: #{ftype}")
      return
    end
    self.update_content(bufc)
    center_on_current_line #TODO: needed?
    file.close; file.unlink
    infile.close; infile.unlink
  end

  # Create a new line after current line and insert text on that line
  def put_to_new_next_line(txt)
    l = current_line_range()
    insert_txt_at(txt, l.end + 1)
    set_pos(l.end + 1)
  end

  # Workaround for https://github.com/ruby-gnome/ruby-gnome/issues/1609
  def paste_start_xclip(at, register)
    @clipboard_paste_running = true
    Thread.new {
      text = `xclip -selection c -o`
      paste_finish(text, at, register)
    }
    return nil
  end

  # Start asynchronous read of system clipboard
  def paste_start(at, register)
    @clipboard_paste_running = true

    if true or running_wayland? and !GLib::Version::or_later?(2, 79, 0)
      return paste_start_xclip(at, register)
    end
    
    clipboard = vma.gui.window.display.clipboard
    clipboard.read_text_async do |_clipboard, result|
      begin
        text = clipboard.read_text_finish(result)
      rescue Gio::IOError::NotSupported
        debug Gio::IOError::NotSupported
      else
        paste_finish(text, at, register)
      end
    end
    return nil
  end

  def paste_finish(text, at, register)
    debug "PASTE: #{text}"

    # If we did not put this text to clipboard
    if text != vma.clipboard[-1]
      @paste_lines = false
    end

    text = sanitize_input(text)

    vma.clipboard << text

    return if text == ""

    if @paste_lines
      debug "PASTE LINES"
      put_to_new_next_line(text)
    else
      debug "PASTE !LINES"
      if at_end_of_buffer? or at_end_of_line? or at == BEFORE
        pos = @pos
      else
        pos = @pos + 1
      end
      insert_txt_at(text, pos)
      set_pos(pos + text.size)
    end
    set_pos(@pos)
    @clipboard_paste_running = false
  end

  def paste(at = AFTER, register = nil)
    # Macro's don't work with asynchronous call using GTK
    # TODO: implement as synchronous?
    # Use internal clipboard
    if vma.macro.running_macro
      text = vma.clipboard.get()
      paste_finish(text, at, register)
    else
      # Get clipboard using GUI
      paste_start(at, register)
    end
    return true
  end

  def complete_current_word(rep)
    debug "complete_current_word", 2
    p = @pos - 1
    return if !is_legal_pos(p)
    (word, range) = get_word_in_pos(p, boundary: :word)
    debug [word, range].to_s, 2
    endpos = range.begin + rep.size
    replace_range(range, rep)
    set_pos(endpos)
  end

  def replace_range(range, text)
    delete_range(range.first, range.last)
    insert_txt_at(text, range.begin)
  end

  def delete2(range_id, mark = nil)
    @paste_lines = false
    range = get_range(range_id, mark: mark)
    return false if range == nil
    debug "RANGE"
    debug range.inspect
    debug range.inspect
    debug "------"
    delete_range(range.first, range.last)
    pos = [range.first, @pos].min
    set_pos(pos)
    return true
  end

  def delete(op, x = nil)
    @paste_lines = false
    # Delete selection
    if op == SELECTION && visual_mode?
      (startpos, endpos) = get_visual_mode_range2
      delete_range(startpos, endpos, x)
      @pos = [@pos, @selection_start].min
      end_visual_mode
      #return

      # Delete current char
    elsif op == CURRENT_CHAR_FORWARD
      return if @pos >= self.size - 1 # May not delete last '\n'
      add_delta([@pos, DELETE, 1], true)

      # Delete current char and then move backward
    elsif op == CURRENT_CHAR_BACKWARD
      add_delta([@pos, DELETE, 1], true)
      @pos -= 1

      # Delete the char before current char and move backward
    elsif op == BACKWARD_CHAR and @pos > 0
      add_delta([@pos - 1, DELETE, 1], true)
      @pos -= 1
    elsif op == FORWARD_CHAR #TODO: ok?
      add_delta([@pos + 1, DELETE, 1], true)
    end
    set_pos(@pos)
    #recalc_line_ends
    calculate_line_and_column_pos
    #need_redraw!
  end

  def delete_range(startpos, endpos, x = nil)
    s = self[startpos..endpos]
    if startpos == endpos or s == ""
      return
    end
    if x == :append
      debug "APPEND"
      s += "\n" + vma.clipboard.get()
    end
    vma.clipboard.set(s)
    add_delta([startpos, DELETE, (endpos - startpos + 1)], true)
    #recalc_line_ends
    calculate_line_and_column_pos
  end

  def is_delta_ok(delta)
    ret = true
    pos = delta[0]
    if pos < 0
      ret = false
      debug "pos=#{pos} < 0"
    elsif pos > self.size
      debug "pos=#{pos} > self.size=#{self.size}"
      ret = false
    end
    if ret == false
      # crash("DELTA OK=#{ret}")
    end
    return ret
  end

  def delete_line()
    vma.kbd.method_handles_repeat = true
    num_lines = 1
    if !vma.kbd.next_command_count.nil? and vma.kbd.next_command_count > 0
      num_lines = vma.kbd.next_command_count
      debug "copy num_lines:#{num_lines}"
    end
    lrange = line_range(@lpos, num_lines)
    s = self[lrange]
    add_delta([lrange.begin, DELETE, lrange.end - lrange.begin + 1], true)
    vma.clipboard.set(s)
    update_pos(lrange.begin)
    @paste_lines = true
    #recalc_line_ends
  end

  def insert_tab
    convert = cnf.tab.to_spaces_default?
    convert = true if cnf.tab.to_spaces_languages?.include?(@lang)
    convert = false if cnf.tab.to_spaces_not_languages?.include?(@lang)
    tw = cnf.tab.width!
    if convert
      indent_to = (@cpos / tw) * tw + tw
      indentdiff = indent_to - @cpos
      insert_txt(" " * indentdiff)
    else
      insert_txt("\t")
    end
  end

  def insert_image_after_current_line(fname)
    lr = current_line_range()
    a = "⟦img:#{fname}⟧\n"
    b = " \n"
    txt = a + b
    insert_txt_at(txt, lr.end + 1)
    buf.view.handle_deltas
    imgpos = lr.end + 1 + a.size
    add_image(fname, imgpos)
  end
end
