
module Vimamsa
# Operations that change the content of the buffer
# e.g. insert, delete

class Buffer < String

  #TODO: change to apply=true as default
  def add_delta(delta, apply = false, auto_update_cpos = false)
    if @read_only
      message("This page is read-only")
      return
    end
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

    # cnf.undo.insert_one_step: no time-based steps inside an Insert session
    unless @macro_group_active || (cnf.undo.insert_one_step? && vma.kbd&.get_mode == :insert)
      if @last_delta_time && (Time.now - @last_delta_time) > cnf.undo.group_threshold!
        new_undo_group
      end
    end
    @current_group << delta
    @last_delta_time = Time.now
    if self[-1] != "\n"
      add_delta([self.size, INSERT, 1, "\n"], true)
    end
    reset_larger_cpos #TODO: correct here?
    refresh_title
  end

  # Indents whole buffer using external program
  def auto_format()
    ftype = get_file_type()
    formatters = cnf.auto_format.formatters!
    fmt = formatters&.fetch(ftype, nil)
    if fmt.nil?
      message("No auto-format handler for file of type: #{ftype}")
      return
    end

    tmppos = @pos
    message("Auto format #{@fname}")

    ext  = fmt[:ext] || ""
    file = Tempfile.new(["vmaformat", ext])
    file.write(self.to_s)
    file.flush

    cmd = fmt[:cmd] % { file: Shellwords.escape(file.path) }
    debug cmd

    ignore_exit = fmt[:ignore_exit_code]
    bufc = nil
    case fmt[:mode]
    when :inplace
      ok = system("bash", "-c", cmd)
      bufc = IO.read(file.path) if ok || ignore_exit
    when :stdout
      outfile = Tempfile.new("vmaformat_out")
      ok = system("bash", "-c", "#{cmd} > #{Shellwords.escape(outfile.path)}")
      bufc = IO.read(outfile.path) if ok || ignore_exit
      outfile.close; outfile.unlink
    else
      message("Unknown auto-format mode: #{fmt[:mode]}")
    end

    file.close; file.unlink

    unless bufc
      message("Auto-format command failed for #{ftype}")
      return
    end

    self.update_content(bufc)
    @pos = tmppos.clamp(0, [self.size - 1, 0].max)
    center_on_current_line
  end

  # Create a new line after current line and insert text on that line
  def put_to_new_next_line(txt)
    l = current_line_range()
    insert_txt_at(txt, l.end + 1)
    set_pos(l.end + 1)
  end

  # Whether text is what the editor copied as whole lines (the unnamed
  # register): text from other programs, read from the system clipboard, is
  # put as characters. entry: the unnamed register when the paste started.
  def register_linewise?(text, entry = vma.registers['"'])
    !entry.nil? && entry.linewise && entry.text == text
  end

  # Workaround for https://github.com/ruby-gnome/ruby-gnome/issues/1609
  def paste_start_xclip(at, register)
    @clipboard_paste_running = true
    ipos = @pos                # capture insertion point before the async read
    entry = vma.registers['"']
    Thread.new {
      text = `xclip -selection c -o`
      GLib::Idle.add { paste_finish(text, at, register, ipos: ipos, paste_lines: register_linewise?(text, entry)); false }
    }
    return nil
  end

  # Start asynchronous read of system clipboard
  def paste_start(at, register, overwrite: false)
    @clipboard_paste_running = true

    # if true or running_wayland? and !GLib::Version::or_later?(2, 79, 0)
      # return paste_start_xclip(at, register)
    # end

    # Capture the insertion point now: read_text_async returns immediately and
    # the callback fires on a later main-loop turn, by which time the cursor
    # may have moved (queued keystroke, mouse click, etc). Without this the
    # paste would land at wherever the cursor happens to be when the clipboard
    # data finally arrives.
    ipos = @pos
    entry = vma.registers['"']

    clipboard = vma.gui.window.display.clipboard
    clipboard.read_text_async do |_clipboard, result|
      begin
        text = _clipboard.read_text_finish(result)
      rescue Gio::IOError::NotSupported
        debug Gio::IOError::NotSupported
      else
        paste_finish(text, at, register, overwrite: overwrite, ipos: ipos, paste_lines: register_linewise?(text, entry))
      end
    end
    return nil
  end

  # ipos/paste_lines: when given, the cursor position and whether to put
  # whole lines, captured when the paste was started (see paste_start). nil
  # means the live cursor, and whole lines if text is what the editor copied
  # as lines (register_linewise?).
  def paste_finish(text, at, register, overwrite: false, ipos: nil, paste_lines: nil)
    debug "PASTE: #{text}"

    @paste_lines = paste_lines.nil? ? register_linewise?(text) : paste_lines
    if !ipos.nil?
      # Clamp in case the buffer shrank during the async window.
      set_pos(ipos.clamp(0, [size - 1, 0].max))
    end

    text = sanitize_input(text)

    vma.clipboard << text

    return if text == ""

    cursor_at_start = cnf.paste.cursor_at_start!

    if overwrite && !@paste_lines
      # Delete as many chars forward as we are about to insert, stopping before newline
      line_end = current_line_range.last - 1  # position of last char before \n
      n = [text.size, [line_end - @pos + 1, 0].max].min
      add_delta([@pos, DELETE, n], true) if n > 0
      insert_txt_at(text, @pos)
      set_pos(cursor_at_start ? @pos : @pos + text.size - 1)
    elsif @paste_lines
      debug "PASTE LINES"
      if at == BEFORE
        l = current_line_range()
        insert_txt_at(text, l.begin)
        set_pos(l.begin)
      else
        put_to_new_next_line(text)
        set_pos(@pos) if cursor_at_start
      end
    else
      debug "PASTE !LINES"
      if at_end_of_buffer? or at_end_of_line? or at == BEFORE
        pos = @pos
      else
        pos = @pos + 1
      end
      insert_txt_at(text, pos)
      set_pos(cursor_at_start ? pos : pos + text.size)
    end
    set_pos(@pos)
    vma.buf.view.after_action # redraw
    @clipboard_paste_running = false
  end

  def paste_over(at = AFTER, register = nil)
    paste_register(at, register, overwrite: true)
  end

  def paste(at = AFTER, register = nil)
    paste_register(at, register)
  end

  # Put a register (registers.rb): register (a name), else the one selected
  # with "x, else the unnamed one. The unnamed register and "+ / "* read the
  # system clipboard, so text copied in other programs is put too.
  def paste_register(at, register = nil, overwrite: false)
    reg = (register || vma.registers.take_pending || '"').to_s
    if ['"', "+", "*"].include?(reg)
      if vma.macro.running_macro
        # Macros can't wait for the asynchronous read: use the editor's copy
        paste_finish(vma.clipboard.get(), at, reg, overwrite: overwrite)
      else
        paste_start(at, reg, overwrite: overwrite)
      end
    else
      e = vma.registers[reg]
      if e.nil?
        message("Register #{reg} is empty")
        return false
      end
      paste_finish(e.text, at, reg, overwrite: overwrite, paste_lines: e.linewise)
    end
    return true
  end

  # Insert mode ctrl-r x: insert the text of register x at the cursor
  def insert_register(name)
    e = vma.registers[name]
    return false if e.nil? || e.text.empty?
    insert_txt(e.text)
    true
  end

  def increment_current_word()
    debug "increment_current_word", 2
    p = @pos
    return if !is_legal_pos(p)
    (word, range) = get_word_in_pos(p, boundary: :word2)
    if x = flip_term(word)
      rep = x  
    else
      num = word.to_i
      num += 1
      rep = num.to_s
    end
    debug [word, range].to_s, 2
    replace_range(range, rep)
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
    # add_delta restores the final "\n" of the buffer if the range deleted it
    text = text.delete_suffix("\n") if range.last >= self.size - 1
    delete_range(range.first, range.last, register: false)
    insert_txt_at(text, range.begin)
  end

  def delete2(range_id, mark = nil)
    range = get_range(range_id, mark: mark)
    return false if range == nil
    debug "RANGE"
    debug range.inspect
    debug range.inspect
    debug "------"
    # Flash the range first so it is visible before the text is removed. When
    # flashing is inactive (tests, config off) the block runs synchronously.
    Gui.flash_range(self, range) do
      delete_range(range.first, range.last)
      set_pos([range.first, @pos].min)
    end
    return true
  end

  def delete(op, x = nil)
    # Delete selection
    if op == SELECTION && visual_mode?
      (startpos, endpos) = get_visual_mode_range2
      delete_range(startpos, endpos, x)
      @pos = [@pos, @selection_start].min
      if vma.kbd.get_mode == :visual
        end_visual_mode
      else
        end_selection
      end
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
    elsif op == FORWARD_CHAR
      add_delta([@pos + 1, DELETE, 1], true)
    end
    set_pos(@pos)
    #recalc_line_ends
    calculate_line_and_column_pos
    #need_redraw!

    if vma.kbd&.get_mode == :insert
      v = (self.view rescue nil)
      v.autocp_on_delete if v.respond_to?(:autocp_on_delete)
    end
  end

  # Move the text in range (inclusive, like get_visual_mode_range) so that it
  # starts at insertion point target of the current text, with the cursor at
  # its new start. One undo step; the clipboard is left alone. Returns the
  # moved text's new range, or nil when target is inside (or right after) the
  # range, i.e. nothing would move.
  def move_text(range, target)
    s, e = range.begin, range.end
    return nil if s > e or target.nil? or (target >= s and target <= e + 1)
    txt = self[s..e]
    new_undo_group
    add_delta([s, DELETE, txt.size], true)
    t = target > e ? target - txt.size : target
    add_delta([t, INSERT, txt.size, txt], true)
    new_undo_group
    calculate_line_and_column_pos
    set_pos(t)
    return t..(t + txt.size - 1)
  end

  # Delete [startpos, endpos]. register: put the text in the registers and
  # the clipboard (false for edits that only replace text, like a case change).
  def delete_range(startpos, endpos, x = nil, register: true)
    s = self[startpos..endpos]
    if startpos > endpos or s == ""
      return
    end
    if x == :append
      debug "APPEND"
      s += "\n" + vma.clipboard.get()
    end
    vma.clipboard.set(s, kind: :delete) if register
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
    num_lines = get_repeat_num()
    lrange = line_range(@lpos, num_lines)
    s = self[lrange]
    add_delta([lrange.begin, DELETE, lrange.end - lrange.begin + 1], true)
    vma.clipboard.set(s, linewise: true, kind: :delete)
    update_pos(lrange.begin)
    #recalc_line_ends
  end

  def insert_tab
    if visual_mode?
      indent_selection
      return
    end
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
end # module Vimamsa
