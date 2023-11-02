# Buffer operations related to cursor position, e.g. moving the cursor (backward, forward, next line etc.)
class Buffer < String

  def line(lpos)
    if @line_ends.size == 0
      return self
    end

    #TODO: implement using line_range()
    if lpos >= @line_ends.size
      debug("lpos too large") #TODO
      return ""
    elsif lpos == @line_ends.size
    end
    start = @line_ends[lpos - 1] + 1 if lpos > 0
    start = 0 if lpos == 0
    _end = @line_ends[lpos]
    debug "start: _#{start}, end: #{_end}"
    return self[start.._end]
  end

  def at_end_of_line?()
    return (self[@pos] == "\n" or at_end_of_buffer?)
  end

  def at_end_of_buffer?()
    return @pos == self.size
  end

  def set_pos(new_pos)
    if new_pos >= self.size
      @pos = self.size - 1 # TODO:??right side of last char
    elsif new_pos >= 0
      @pos = new_pos
    end
    gui_set_cursor_pos(@id, @pos)
    calculate_line_and_column_pos

    check_if_modified_outside
  end

  # Get the line number of character position
  def get_line_pos(pos)
    lpos = @line_ends.bsearch_index { |x, _| x >= pos }
    return lpos
  end

  # Calculate the two dimensional column and line positions based on
  # (one dimensional) position in the buffer.
  def get_line_and_col_pos(pos)
    pos = self.size if pos > self.size
    pos = 0 if pos < 0

    lpos = get_line_pos(pos)

    lpos = @line_ends.size if lpos == nil
    cpos = pos
    cpos -= @line_ends[lpos - 1] + 1 if lpos > 0

    return [lpos, cpos]
  end

  def calculate_line_and_column_pos(reset = true)
    @lpos, @cpos = get_line_and_col_pos(@pos)
    reset_larger_cpos if reset
  end

  def set_line_and_column_pos(lpos, cpos, _reset_larger_cpos = true)
    @lpos = lpos if !lpos.nil?
    @cpos = cpos if !cpos.nil?
    if @lpos > 0
      new_pos = @line_ends[@lpos - 1] + 1
    else
      new_pos = 0
    end

    if @cpos > (line(@lpos).size - 1)
      debug("$cpos too large: #{@cpos} #{@lpos}")
      if @larger_cpos < @cpos
        @larger_cpos = @cpos
      end
      @cpos = line(@lpos).size - 1
    end
    new_pos += @cpos
    set_pos(new_pos)
    reset_larger_cpos if _reset_larger_cpos
  end

  # Calculate the one dimensional array index based on column and line positions
  def calculate_pos_from_cpos_lpos(reset = true)
    set_line_and_column_pos(nil, nil)
  end

  def update_pos(pos)
    @pos = pos
    calculate_line_and_column_pos
  end

  def is_legal_pos(pos, op = :read)
    return false if pos < 0
    if op == :add
      return false if pos > self.size
    elsif op == :read
      return false if pos >= self.size
    end
    return true
  end

  def jump_to_last_edit()
    return if @edit_pos_history.empty?
    @edit_pos_history_i += 1

    if @edit_pos_history_i > @edit_pos_history.size
      @edit_pos_history_i = 0
    end

    #        if @edit_pos_history.size >= @edit_pos_history_i
    set_pos(@edit_pos_history[-@edit_pos_history_i])
    center_on_current_line
    return true
    #        end
  end

  def jump_to_next_edit()
    return if @edit_pos_history.empty?
    @edit_pos_history_i -= 1
    @edit_pos_history_i = @edit_pos_history.size - 1 if @edit_pos_history_i < 0
    debug "@edit_pos_history_i=#{@edit_pos_history_i}"
    set_pos(@edit_pos_history[-@edit_pos_history_i])
    center_on_current_line
    return true
  end

  def jump_to_random_pos()
    set_pos(rand(self.size))
  end

  def jump_to_next_instance_of_word()
    if $kbd.last_action == $kbd.cur_action and @current_word != nil
      # debug "REPEATING *"
    else
      start_search = [@pos - 150, 0].max

      search_str1 = self[start_search..(@pos)]
      wsmarks = scan_indexes(search_str1, /(?<=[^\p{Word}])\p{Word}/)
      a = wsmarks[-1]
      a = 0 if a == nil

      search_str2 = self[(@pos)..(@pos + 150)]
      wemarks = scan_indexes(search_str2, /(?<=\p{Word})[^\p{Word}]/)
      b = wemarks[0]
      word_start = (@pos - search_str1.size + a + 1)
      word_start = 0 if !(word_start >= 0)
      @current_word = self[word_start..(@pos + b - 1)]
    end

    #TODO: search for /[^\p{Word}]WORD[^\p{Word}]/
    position_of_next_word = self.index(@current_word, @pos + 1)
    if position_of_next_word != nil
      set_pos(position_of_next_word)
    else #Search from beginning
      position_of_next_word = self.index(@current_word)
      set_pos(position_of_next_word) if position_of_next_word != nil
    end
    center_on_current_line
    return true
  end

  def jump_word(direction, wordpos)
    offset = 0
    if direction == FORWARD
      debug "POS: #{@pos},"
      search_str = self[(@pos)..(@pos + 250)]
      return if search_str == nil
      if wordpos == WORD_START # vim 'w'
        wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}|\Z/) # \Z = end of string, just before last newline.
        wsmarks2 = scan_indexes(search_str, /\n[ \t]*\n/) # "empty" lines that have whitespace
        wsmarks2 = wsmarks2.collect { |x| x + 1 }
        wsmarks = (wsmarks2 + wsmarks).sort.uniq
        offset = 0
        if wsmarks.any?
          next_pos = @pos + wsmarks[0] + offset
          set_pos(next_pos)
        end
      elsif wordpos == WORD_END
        search_str = self[(@pos + 1)..(@pos + 150)]
        wsmarks = scan_indexes(search_str, /(?<=\p{Word})[^\p{Word}]/)
        offset = -1
        if wsmarks.any?
          next_pos = @pos + 1 + wsmarks[0] + offset
          set_pos(next_pos)
        end
      end
    end
    if direction == BACKWARD #  vim 'b'
      start_search = @pos - 150 #TODO 150 length limit
      start_search = 0 if start_search < 0
      search_str = self[start_search..(@pos - 1)]
      return if search_str == nil
      wsmarks = scan_indexes(search_str,
                             #/(^|(\W)\w|\n)/) #TODO 150 length limit
                             #/^|(?<=[^\p{Word}])\p{Word}|(?<=\n)\n/) #include empty lines?
                             /\A|(?<=[^\p{Word}])\p{Word}/) # Start of string or nonword,word.

      offset = 0

      if wsmarks.any?
        next_pos = start_search + wsmarks.last + offset
        set_pos(next_pos)
      end
    end
  end

  def jump_to_mark(mark_char)
    p = @marks[mark_char]
    set_pos(p) if p
    center_on_current_line
    return true
  end

  def jump(target)
    if target == START_OF_BUFFER
      set_pos(0)
    end
    if target == END_OF_BUFFER
      set_pos(self.size - 1)
    end
    if target == BEGINNING_OF_LINE
      @cpos = 0
      calculate_pos_from_cpos_lpos
    end
    if target == END_OF_LINE
      @cpos = line(@lpos).size - 1
      calculate_pos_from_cpos_lpos
    end

    if target == FIRST_NON_WHITESPACE
      l = current_line()
      debug l.inspect
      @cpos = line(@lpos).size - 1
      a = scan_indexes(l, /\S/)
      debug a.inspect
      if a.any?
        @cpos = a[0]
      else
        @cpos = 0
      end
      calculate_pos_from_cpos_lpos
    end
  end

  def jump_to_line(line_n = 1)

    #    $method_handles_repeat = true
    #    if !$next_command_count.nil? and $next_command_count > 0
    #        line_n = $next_command_count
    #        debug "jump to line:#{line_n}"
    #    end
    debug "jump to line:#{line_n}"
    line_n = get_repeat_num() if line_n == 1

    if line_n > @line_ends.size
      debug("lpos too large") #TODO
      return
    end
    if line_n == 1
      set_pos(0)
    else
      set_pos(@line_ends[line_n - 2] + 1)
    end
  end

  def jump_to_next_instance_of_char(char, direction = FORWARD)

    #return if at_end_of_line?
    if direction == FORWARD
      position_of_next_char = self.index(char, @pos + 1)
      if position_of_next_char != nil
        @pos = position_of_next_char
      end
    elsif direction == BACKWARD
      start_search = @pos - 250
      start_search = 0 if start_search < 0
      search_substr = self[start_search..(@pos - 1)]
      _pos = search_substr.reverse.index(char)
      if _pos != nil
        @pos -= (_pos + 1)
      end
    end
    m = method("jump_to_next_instance_of_char")
    set_last_command({ method: m, params: [char, direction] })
    $last_find_command = { char: char, direction: direction }
    set_pos(@pos)
  end

  def jump_to_pos(new_pos)
    set_pos(new_pos)
  end
end
