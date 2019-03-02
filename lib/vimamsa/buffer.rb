require "digest"
require "tempfile"
require "pathname"
require "ripl/multi_line"

$paste_lines = false
$buffer_history = [0]

$update_highlight = true

class BufferList < Array
  attr_reader :current_buf

  def <<(_buf)
    super
    $buffer = _buf
    @current_buf = self.size - 1
    $buffer_history << @current_buf
    @recent_ind = 0
  end

  def switch()
    debug "SWITCH BUF. bufsize:#{self.size}, curbuf: #{@current_buf}"
    @current_buf += 1
    @current_buf = 0 if @current_buf >= self.size
    m = method("switch")
    set_last_command({ method: m, params: [] })
    set_current_buffer(@current_buf)
  end

  def switch_to_last_buf()
    puts "SWITCH TO LAST BUF:"
    puts $buffer_history
    last_buf = $buffer_history[-2]
    if last_buf
      set_current_buffer(last_buf)
    end
  end

  def get_buffer_by_filename(fname)
    #TODO: check using stat/inode?  http://ruby-doc.org/core-1.9.3/File/Stat.html#method-i-ino
    buf_idx = self.index { |b| b.fname == fname }
    return buf_idx
  end

  def add_current_buf_to_history()
    @recent_ind = 0
    $buffer_history << @current_buf
    compact_buf_history()
  end

  def set_current_buffer(buffer_i, update_history = true)
    buffer_i = self.size -1 if buffer_i > self.size
    buffer_i = 0 if buffer_i < 0
    $buffer = self[buffer_i]
    return if !$buffer
    @current_buf = buffer_i
    debug "SWITCH BUF2. bufsize:#{self.size}, curbuf: #{@current_buf}"
    fpath = $buffer.fname
    if fpath and fpath.size > 50
      fpath = fpath[-50..-1]
    end

    if update_history
      add_current_buf_to_history
    end

    set_window_title("Vimamsa - #{fpath}")
    $buffer.need_redraw!
  end

  def get_recent_buffers()
    bufs = []; b = {}
    $buffer_history.reverse.each { |x| bufs << x if !b[x] && x < self.size; b[x] = true }
    return bufs
  end

  def history_switch_backwards()
    recent = get_recent_buffers()
    @recent_ind += 1
    @recent_ind = 0 if @recent_ind >= recent.size
    bufid = recent[@recent_ind]
    puts "IND:#{@recent_ind} RECENT:#{recent.join(" ")}"
    set_current_buffer(bufid, false)
  end

  def history_switch_forwards()
    recent = get_recent_buffers()
    @recent_ind -= 1
    @recent_ind = self.size - 1 if @recent_ind < 0
    bufid = recent[@recent_ind]
    puts "IND:#{@recent_ind} RECENT:#{recent.join(" ")}"
    set_current_buffer(bufid, false)
  end

  def compact_buf_history()
    h = {}
    # Keep only first occurence in history
    bh = $buffer_history.reverse.select { |x| r = h[x] == nil; h[x] = true; r }
    $buffer_history = bh.reverse
  end

  def close_buffer(buffer_i)
    return if self.size <= buffer_i
    self.slice!(buffer_i)
    $buffer_history = $buffer_history.collect { |x| r = x; r = x - 1 if x > buffer_i; r = nil if x == buffer_i; r }.compact

    #        Ripl.start :binding => binding
    @current_buf = 0 if @current_buf >= self.size
    if self.size == 0
      self << Buffer.new("emptybuf\n")
    end
    set_current_buffer(@current_buf)
  end

  def close_scrap_buffers()
    i = 0
    while i < self.size
      if !self[i].pathname
        close_buffer(i)
      else
        i += 1
      end
    end
  end

  def close_current_buffer
    close_buffer(@current_buf)
  end
end

class Buffer < String

  #attr_reader (:pos, :cpos, :lpos)

  attr_reader :pos, :lpos, :cpos, :deltas, :edit_history, :fname, :call_func, :pathname, :basename, :highlights, :update_highlight, :marks
  attr_writer :call_func, :update_highlight

  def initialize(str = "\n", fname = nil)
    if (str[-1] != "\n")
      str << "\n"
    end

    super(str)
    @fname = fname

    t1 = Time.now
    set_content(str)
    puts "init time:#{Time.now - t1}"

    # TODO: add \n when chars are added after last \n
    self << "\n" if self[-1] != "\n"
  end

  def get_file_type()
    return "" if !@fname
    ext = File.extname(@fname)
    ext = ext[1..-1]
    puts "EXT:#{ext}"
    return "ruby" if ext == "rb"
    return "c" if ext == "c" or ext == "cpp" or ext == "h" or ext == "hpp"
  end

  def highlight()
    return if !$cnf[:syntax_highlight]
    puts "START HIGHLIGHT"

    if @syntax_parser == nil
      if self.get_file_type() == "ruby"
        file = "vendor/ver/config/syntax/Ruby.rb"
      elsif self.get_file_type() == "c"
        file = "vendor/ver/config/syntax/C.rb"
      else
        puts "NON-HIGHLIGHTABLE FILE: '#{get_file_type()}'"
        return
      end
      @syntax_parser = Textpow::SyntaxNode.load(file)
    end

    puts "@update_highlight=#{@update_highlight}"
    if @update_highlight and (Time.now - @last_update > 5)
      puts "if @update_highlight"

      #            Ripl.start :binding => binding
      t1 = Thread.new {
        sp = Processor.new
        @syntax_parser.parse($buffer.to_s, sp)
        #TODO
        @highlights = sp.highlights
        $update_highlight = true
        @last_update = Time.now
      }

      # t1=Thread.new{ sp = Processor.new;                 @syntax_parser.parse($buffer.to_s, sp);   @highlights = sp.highlights;                 $update_highlight = true;             }

      @update_highlight = false
    end
    puts @highlight
  end

  def revert()
    message("Revert buffer #{@fname}")
    puts @fname.inspect
    str = read_file("", @fname)
    self.set_content(str)
  end

  def set_content(str)
    self.replace(str)
    @line_ends = scan_indexes(self, /\n/)
    @last_update = Time.now - 10
    debug("line_ends")
    #puts str.inspect
    @marks = Hash.new
    @basename = ""
    @pathname = Pathname.new(fname) if @fname
    @basename = @pathname.basename if @fname
    @pos = 0 # Position in whole file
    @cpos = 0 # Column position on current line
    @lpos = 0 # Number of current line
    @edit_version = 0 # +1 for every buffer modification
    @larger_cpos = 0 # Store @cpos when move up/down to shorter line than @cpos
    @need_redraw = 1
    @call_func = nil
    @deltas = []
    @edit_history = []
    @redo_stack = []
    @edit_pos_history = []
    @edit_pos_history_i = 0
    @highlights = {}

    @syntax_parser = nil
    @update_highlight = true
  end

  def set_filename(filename)
    @fname = filename
    @pathname = Pathname.new(fname) if @fname
    @basename = @pathname.basename if @fname
  end

  def get_short_path()
    fpath = self.fname
    if fpath.size > 50
      fpath = fpath[-50..-1]
    end
    return fpath
  end

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

  def is_delta_ok(delta)
    ret = true
    pos = delta[0]
    if pos < 0
      ret = false
      puts "pos=#{pos} < 0"
    elsif pos > self.size
      puts "pos=#{pos} > self.size=#{self.size}"
      ret = false
    end
    if ret == false
      crash("DELTA OK=#{ret}")
    end
    return ret
  end

  #TODO: change to apply=true as default
  def add_delta(delta, apply = false)
    return if !is_delta_ok(delta)
    @edit_version += 1
    @redo_stack = []
    if apply
      delta = run_delta(delta)
    else
      @deltas << delta
    end
    @edit_history << delta
    reset_larger_cpos #TODO: correct here?
  end

  def run_delta(delta)
    pos = delta[0]
    if @edit_pos_history.any? and (@edit_pos_history.last - pos).abs <= 2
      @edit_pos_history.pop
    end
    @edit_pos_history << pos
    @edit_pos_history_i = 0

    if delta[1] == DELETE
      delta[3] = self.slice!(delta[0], delta[2])
      @deltas << delta
      update_index(pos, -delta[2])
      update_line_ends(pos, -delta[2], delta[3])
    elsif delta[1] == INSERT
      self.insert(delta[0], delta[3])
      @deltas << delta
      puts [pos, +delta[2]].inspect
      update_index(pos, +delta[2])
      update_line_ends(pos, +delta[2], delta[3])
    end
    puts "DELTA=#{delta.inspect}"
    sanity_check_line_ends
    #highlight_c()
    $update_highlight = true
    @update_highlight = true

    return delta
  end

  def update_index(pos, changeamount)
    @edit_pos_history.collect! { |x| r = x if x <= pos; r = x + changeamount if x > pos; r }
    for k in @marks.keys
      #            puts "change(?): pos=#{pos}, k=#{k}, #{@marks[k]}, #{changeamount}"
      if @marks[k] > pos
        @marks[k] = @marks[k] + changeamount
      end
    end
  end

  def jump_to_last_edit()
    return if @edit_pos_history.empty?
    @edit_pos_history_i += 1

    if @edit_pos_history_i > @edit_pos_history.size
      @edit_pos_history_i = 0
    end

    #        if @edit_pos_history.size >= @edit_pos_history_i
    set_pos(@edit_pos_history[-@edit_pos_history_i])
    #        end
  end

  def jump_to_next_edit()
    return if @edit_pos_history.empty?
    @edit_pos_history_i -= 1
    @edit_pos_history_i = @edit_pos_history.size - 1 if @edit_pos_history_i < 0
    #        Ripl.start :binding => binding
    puts "@edit_pos_history_i=#{@edit_pos_history_i}"
    puts @edit_pos_history.size
    set_pos(@edit_pos_history[-@edit_pos_history_i])
  end

  def undo()
    puts @edit_history.inspect
    return if !@edit_history.any?
    last_delta = @edit_history.pop
    @redo_stack << last_delta
    puts last_delta.inspect
    if last_delta[1] == DELETE
      d = [last_delta[0], INSERT, 0, last_delta[3]]
      run_delta(d)
    elsif last_delta[1] == INSERT
      d = [last_delta[0], DELETE, last_delta[3].size]
      run_delta(d)
    else
      return #TODO: assert?
    end
    @pos = last_delta[0]
    #recalc_line_ends #TODO: optimize?
    calculate_line_and_column_pos
  end

  def redo()
    return if !@redo_stack.any?
    #last_delta = @edit_history[-1].pop
    redo_delta = @redo_stack.pop
    #printf("==== UNDO ====\n")
    puts redo_delta.inspect
    run_delta(redo_delta)
    @edit_history << redo_delta
    @pos = redo_delta[0]
    #recalc_line_ends #TODO: optimize?
    calculate_line_and_column_pos
  end

  def current_char()
    return self[@pos]
  end

  def current_line()
    range = line_range(@lpos, 1)
    return self[range]
  end

  def get_com_str()
    com_str = nil
    if get_file_type() == "c"
      com_str = "//"
    elsif get_file_type() == "ruby"
      com_str = "#"
    end
    return com_str
  end

  def comment_linerange(r)
    com_str = get_com_str()
    #r=$buffer.line_range($buffer.lpos, 2)
    lines = $buffer[r].split(/(\n)/).each_slice(2).map { |x| x[0] }
    #TODO: .lines ?
    mod = lines.collect { |x| "#{com_str}#{x}\n" }.join()
    #Ripl.start :binding => binding
    replace_range(r, mod)
  end

  def get_line_start(pos)
    #Ripl.start :binding => binding
    ls = @line_ends.select { |x| x < pos }.max + 1
    ls = 0 if ls == nil
    return ls
  end

  def get_line_end(pos)
    #Ripl.start :binding => binding
    return @line_ends.select { |x| x > pos }.min
  end

  def comment_selection(op = :comment)
    if visual_mode?
      (startpos, endpos) = get_visual_mode_range2
      first = get_line_start(startpos)
      last = get_line_end(endpos)
      if op == :comment
        comment_linerange(first..last)
      elsif op == :uncomment
        uncomment_linerange(first..last)
      end
      $buffer.end_visual_mode
    end
  end

  def uncomment_linerange(r)
    com_str = get_com_str()
    #r=$buffer.line_range($buffer.lpos, 2)
    lines = $buffer[r].split(/(\n)/).each_slice(2).map { |x| x[0] }
    mod = lines.collect { |x| x.sub(/^(\s*)(#{com_str})/, '\1') + "\n" }.join()
    replace_range(r, mod)
  end

  def get_repeat_num()
    $method_handles_repeat = true
    repeat_num = 1
    if !$next_command_count.nil? and $next_command_count > 0
      repeat_num = $next_command_count
    end
    return repeat_num
  end

  def comment_line(op = :comment)
    num_lines = get_repeat_num()
    lrange = line_range(@lpos, num_lines)
    if op == :comment
      comment_linerange(lrange)
    elsif op == :uncomment
      uncomment_linerange(lrange)
    end
  end

  def replace_range(range, text)
    delete_range(range.first, range.last)
    insert_char_at(text, range.begin)
  end

  def current_line_range()
    range = line_range(@lpos, 1)
    return range
  end

  def line_range(start_line, num_lines)
    end_line = start_line + num_lines - 1
    if end_line >= @line_ends.size
      debug("lpos too large") #TODO
      end_line = @line_ends.size - 1
    end
    start = @line_ends[start_line - 1] + 1 if start_line > 0
    start = 0 if start_line == 0
    _End = @line_ends[end_line]
    debug "line range: start=#{start}, end=#{_End}"
    return start.._End
  end

  def copy(range_id)
    $paste_lines = false
    puts "range_id: #{range_id}"
    puts range_id.inspect
    range = get_range(range_id)
    puts range.inspect
    set_clipboard(self[range])
  end

  def recalc_line_ends()
    t1 = Time.now
    leo = @line_ends.clone
    @line_ends = scan_indexes(self, /\n/)
    if @line_ends == leo
      puts "No change to line ends"
    else
      puts "CHANGES to line ends"
    end

    puts "Scan line_end time: #{Time.now - t1}"
    #puts @line_ends
  end

  def sanity_check_line_ends()
    leo = @line_ends.clone
    @line_ends = scan_indexes(self, /\n/)
    if @line_ends == leo
      puts "No change to line ends"
    else
      puts "CHANGES to line ends"
      puts leo.inspect
      puts @line_ends.inspect
      crash("CHANGES to line ends")
    end
  end

  def update_line_ends(pos, changeamount, changestr)
    puts @line_ends.inspect
    puts pos
    if changeamount > -1
      changeamount = changestr.size
      i = scan_indexes(changestr, /\n/)
      i.collect! { |x| x + pos }
      puts "new LINE ENDS:#{i.inspect}"
    end
    puts "change:#{changeamount}"
    @line_ends.collect! { |x|
      r = nil
      r = x if x < pos
      r = x + changeamount if changeamount < 0 && x + changeamount >= pos
      r = x + changeamount if changeamount > 0 && x >= pos
      r
    }.compact!

    if changeamount > -1 && i.size > 0
      @line_ends.concat(i)
      @line_ends.sort!
    end
  end

  def at_end_of_line?()
    return (self[@pos] == "\n" or at_end_of_buffer?)
  end

  def at_end_of_buffer?()
    return @pos == self.size
  end

  def set_pos(new_pos)
    if new_pos >= self.size
      @pos = self.size # right side of last char
    elsif new_pos >= 0
      @pos = new_pos
    end
    calculate_line_and_column_pos

    Thread.new { #TODO:Hackish solution
      sleep(0.2)
      #            center_on_current_line
    }
  end

  # Calculate the two dimensional column and line positions based on current
  # (one dimensional) position in the buffer.
  def calculate_line_and_column_pos(reset = true)
    @pos = self.size if @pos > self.size
    @pos = 0 if @pos < 0
    #puts @line_ends
    next_line_end = @line_ends.bsearch { |x| x >= @pos } #=> 4
    #puts @line_ends
    #puts "nle: #{next_line_end}"
    @lpos = @line_ends.index(next_line_end)
    if @lpos == nil
      @lpos = @line_ends.size
    else
      #@lpos += 1
    end
    @cpos = @pos
    if @lpos > 0
      @cpos -= @line_ends[@lpos - 1] + 1 #TODO??
    end
    reset_larger_cpos if reset
  end

  # Calculate the one dimensional array index based on column and line positions
  def calculate_pos_from_cpos_lpos(reset = true)
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
    @pos = new_pos
    reset_larger_cpos if reset
  end

  def delete2(range_id)
    $paste_lines = false
    range = get_range(range_id)
    puts "RANGE"
    puts range.inspect
    puts range.inspect
    puts "------"
    delete_range(range.first, range.last)
    pos = [range.first, @pos].min
    set_pos(pos)
  end

  def delete(op)
    $paste_lines = false
    # Delete selection
    if op == SELECTION && visual_mode?
      (startpos, endpos) = get_visual_mode_range2
      delete_range(startpos, endpos)
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
    #recalc_line_ends
    calculate_line_and_column_pos
    #need_redraw!
  end

  def delete_range(startpos, endpos)
    #s = self.slice!(startpos..endpos)
    set_clipboard(self[startpos..endpos])
    add_delta([startpos, DELETE, (endpos - startpos + 1)], true)
    #recalc_line_ends
    calculate_line_and_column_pos
  end

  def get_range(range_id)
    if range_id == :to_word_end
      wmarks = get_word_end_marks(@pos, @pos + 150)
      if wmarks.any?
        range = @pos..wmarks[0]
      end
    elsif range_id == :to_line_end
      puts "TO LINE END"
      range = @pos..(@line_ends[@lpos] - 1)
    elsif range_id == :to_line_start
      puts "TO LINE START"
      if @lpos == 0
        startpos = 0
      else
        startpos = @line_ends[@lpos - 1] + 1
      end
      range = startpos..(@pos - 1)
    else
      crash("INVALID RANGE")
    end
    if range.last < range.first
      range.last = range.first
    end
    if range.first < 0
      range.first = 0
    end
    if range.last >= self.size
      range.last = self.size - 1
    end
    #TODO: sanity check
    return range
  end

  def reset_larger_cpos()
    @larger_cpos = @cpos
  end

  def move(direction)
    puts "cpos:#{@cpos} lpos:#{@lpos} @larger_cpos:#{@larger_cpos}"
    if direction == :forward_page
      puts "FORWARD PAGE"
      visible_range = get_visible_area()
      set_pos(visible_range[1])
      top_where_cursor()
    end
    if direction == :backward_page
      puts "backward PAGE"
      visible_range = get_visible_area()
      set_pos(visible_range[0])
      bottom_where_cursor()
    end

    if direction == FORWARD_CHAR
      return if @pos >= self.size - 1
      @pos += 1
      puts "FORWARD: #{@pos}"
      calculate_line_and_column_pos
    end
    if direction == BACKWARD_CHAR
      @pos -= 1
      calculate_line_and_column_pos
    end
    if direction == FORWARD_LINE
      if @lpos >= @line_ends.size - 1 # Cursor is on last line
        debug("ON LAST LINE")
        return
      else
        @lpos += 1
      end
    end
    if direction == BACKWARD_LINE
      if @lpos == 0 # Cursor is on first line
        return
      else
        @lpos -= 1
      end
    end

    if direction == FORWARD_CHAR or direction == BACKWARD_CHAR
      reset_larger_cpos
    end

    if direction == BACKWARD_LINE or direction == FORWARD_LINE
      if @lpos > 0
        new_pos = @line_ends[@lpos - 1] - 1
      else
        new_pos = 0
      end

      _line = self.line(@lpos)
      if @cpos > (_line.size - 1)
        debug("$cpos too large: #{@cpos} #{@lpos}")
        if @larger_cpos < @cpos
          @larger_cpos = @cpos
        end
        @cpos = line(@lpos).size - 1
      end

      if @larger_cpos > @cpos and @larger_cpos < (_line.size)
        @cpos = @larger_cpos
      elsif @larger_cpos > @cpos and @larger_cpos >= (_line.size)
        @cpos = line(@lpos).size - 1
      end

      #new_pos += @cpos
      #@pos = new_pos
      calculate_pos_from_cpos_lpos(false)
    end
  end

  def mark_current_position(mark_char)
    @marks[mark_char] = @pos
  end

  # Get positions of last characters in words
  def get_word_end_marks(startpos, endpos)
    startpos = 0 if startpos < 0
    endpos = self.size if endpos > self.size
    search_str = self[(startpos)..(endpos)]
    return if search_str == nil
    wsmarks = scan_indexes(search_str, /(?<=\p{Word})[^\p{Word}]/)
    wsmarks = wsmarks.collect { |x| x + startpos - 1 }
    return wsmarks
  end

  # Get positions of first characters in words
  def get_word_start_marks(startpos, endpos)
    startpos = 0 if startpos < 0
    endpos = self.size if endpos > self.size
    search_str = self[(startpos)..(endpos)]
    return if search_str == nil
    wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}/)
    wsmarks = wsmarks.collect { |x| x + startpos }
    return wsmarks
  end

  def scan_marks(startpos, endpos, regstr, offset = 0)
    startpos = 0 if startpos < 0
    endpos = self.size if endpos > self.size
    search_str = self[(startpos)..(endpos)]
    return if search_str == nil
    marks = scan_indexes(search_str, regstr)
    marks = marks.collect { |x| x + startpos + offset }
    return marks
  end

  def can_open_extension(filepath)
    exts = $cnf[:extensions_to_open]
    extname = Pathname.new(filepath).extname
    can_open = exts.include?(extname)
    puts "CAN OPEN?: #{can_open}"
    return can_open
  end

  def get_cur_nonwhitespace_word()

    #wem = scan_marks(@pos,@pos+200,/(?<=\p{Word})[^\p{Word}]/,-1)
    #wsm = scan_marks(@pos-200,@pos,/(?<=[^\p{Word}])\p{Word}/)
    wem = scan_marks(@pos, @pos + 200, /(?<=\S)\s/, -1)
    wsm = scan_marks(@pos - 200, @pos, /(?<=\s)\S/)
    word_start = wsm[-1]
    word_end = wem[0]
    word_start = pos if word_start == nil
    word_end = pos if word_end == nil
    word = self[word_start..word_end]
    puts "'#{word}'"
    message("'#{word}'")
    linep = get_file_line_pointer(word)
    puts "linep'#{linep}'"
    path = File.expand_path(word)
    if is_url(word)
      message("URL:'#{word}'")
      open_url(word)
    elsif is_existing_file(path)
      message("PATH:'#{word}'")
      if can_open_extension(path)
        open_existing_file(path)
      else
        open_url(path)
      end
    elsif linep != nil
      puts linep
      jump_to_file(linep[0], linep[1].to_i)
    end
    #puts wm
  end

  def get_cur_word()
    wem = get_word_end_marks(@pos, @pos + 200)
    wsm = get_word_start_marks(@pos - 200, @pos)
    word_start = wsm[-1]
    word_end = wem[0]
    word_start = pos if word_start == nil
    word_end = pos if word_end == nil
    word = self[word_start..word_end]
    puts "'#{word}'"
    message("'#{word}'")
    #puts wm
  end

  def jump_to_next_instance_of_word()
    start_search = [@pos - 150, 0].max

    search_str1 = self[start_search..(@pos)]
    wsmarks = scan_indexes(search_str1, /(?<=[^\p{Word}])\p{Word}/)
    a = wsmarks[-1]
    a = 0 if a == nil

    search_str2 = self[(@pos)..(@pos + 150)]
    wemarks = scan_indexes(search_str2, /(?<=\p{Word})[^\p{Word}]/)
    b = wemarks[0]
    puts search_str1.inspect
    word_start = (@pos - search_str1.size + a + 1)
    word_start = 0 if !(word_start >= 0)
    current_word = self[word_start..(@pos + b - 1)]
    #printf("CURRENT WORD: '#{current_word}' a:#{a} b:#{b}\n")

    #TODO: search for /[^\p{Word}]WORD[^\p{Word}]/
    position_of_next_word = self.index(current_word, @pos + 1)
    if position_of_next_word != nil
      set_pos(position_of_next_word)
    else #Search from beginning
      position_of_next_word = self.index(current_word)
      set_pos(position_of_next_word) if position_of_next_word != nil
    end
    center_on_current_line
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
      puts l.inspect
      @cpos = line(@lpos).size - 1
      a = scan_indexes(l, /\S/)
      puts a.inspect
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

  def join_lines()
    if @lpos >= @line_ends.size - 1 # Cursor is on last line
      debug("ON LAST LINE")
      return
    else
      # TODO: replace all whitespace between lines with ' '
      jump(END_OF_LINE)
      delete(CURRENT_CHAR_FORWARD)
      #insert_char(' ',AFTER)
      insert_char(" ", BEFORE)
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
    calculate_line_and_column_pos
  end

  def replace_with_char(char)
    puts "self_pos:'#{self[@pos]}'"
    return if self[@pos] == "\n"
    d1 = [@pos, DELETE, 1]
    d2 = [@pos, INSERT, 1, char]
    add_delta(d1, true)
    add_delta(d2, true)
    puts "DELTAS:#{$buffer.deltas.inspect} "
  end

  def insert_char_at(c, pos)
    c = c.force_encoding("UTF-8");  #TODO:correct?
    c = "\n" if c == "\r"
    add_delta([pos, INSERT, c.size, c], true)
    calculate_line_and_column_pos
  end

  def insert_char(c, mode = BEFORE)
    #Sometimes we get ASCII-8BIT although actually UTF-8  "incompatible character encodings: UTF-8 and ASCII-8BIT (Encoding::CompatibilityError)"
    c = c.force_encoding("UTF-8");  #TODO:correct?

    c = "\n" if c == "\r"
    if $cnf[:indent_based_on_last_line] and c == "\n" and @lpos > 0
      # Indent start of new line based on last line
      last_line = line(@lpos)
      m = /^( +)([^ ]+|$)/.match(last_line)
      puts m.inspect
      c = c + " " * m[1].size if m
    end
    if mode == BEFORE
      insert_pos = @pos
      @pos += c.size
    elsif mode == AFTER
      insert_pos = @pos + 1
    else
      return
    end

    #self.insert(insert_pos,c)
    add_delta([insert_pos, INSERT, c.size, c], true)
    #puts("encoding: #{c.encoding}")
    #puts "c.size: #{c.size}"
    #recalc_line_ends #TODO: optimize?
    calculate_line_and_column_pos
    #need_redraw!
    #@pos += c.size
  end

  def need_redraw!
    @need_redraw = true
  end

  def need_redraw?
    return @need_redraw
  end

  def set_redrawed
    @need_redraw = false
  end

  def paste(at = AFTER, register = nil)
    # Paste after current char. Except if at end of line, paste before end of line.
    return if !$clipboard.any?
    if register == nil
      text = $clipboard[-1]
    else
      text = $register[register]
    end
    return if text == ""

    if $paste_lines
      puts "PASTE LINES"
      l = current_line_range()
      puts "------------"
      puts l.inspect
      puts "------------"
      #$buffer.move(FORWARD_LINE)
      #set_pos(l.end+1)
      insert_char_at(text, l.end + 1)
      set_pos(l.end + 1)
    else
      if at_end_of_buffer? or at_end_of_line? or at == BEFORE
        pos = @pos
      else
        pos = @pos + 1
      end
      insert_char_at(text, pos)
      set_pos(pos + text.size)
    end
    #TODO: AFTER does not work
    #insert_char($clipboard[-1],AFTER)
    #recalc_line_ends #TODO: bug when run twice?
  end

  def insert_new_line()
    insert_char("\n")
  end

  def delete_line()
    $method_handles_repeat = true
    num_lines = 1
    if !$next_command_count.nil? and $next_command_count > 0
      num_lines = $next_command_count
      debug "copy num_lines:#{num_lines}"
    end
    lrange = line_range(@lpos, num_lines)
    s = self[lrange]
    add_delta([lrange.begin, DELETE, lrange.end - lrange.begin + 1], true)
    set_clipboard(s)
    update_pos(lrange.begin)
    $paste_lines = true
    #recalc_line_ends
  end

  def update_pos(pos)
    @pos = pos
    calculate_line_and_column_pos
  end

  def start_visual_mode()
    @visual_mode = true
    @selection_start = @pos
    $at.set_mode(VISUAL)
  end

  def copy_active_selection()
    puts "!COPY SELECTION"
    $paste_lines = false
    return if !@visual_mode

    puts "COPY SELECTION"
    #_start = @selection_start
    #_end = @pos
    #_start,_end = _end,_start if _start > _end

    #_start,_end = get_visual_mode_range
    # TODO: Jump to start pos

    #TODO: check if range ok
    set_clipboard(self[get_visual_mode_range])
    end_visual_mode
  end

  def transform_selection(op)
    return if !@visual_mode
    r = get_visual_mode_range
    txt = self[r]
    txt.upcase! if op == :upcase
    txt.downcase! if op == :downcase
    txt.gsub!(/\w+/, &:capitalize) if op == :capitalize
    txt.swapcase! if op == :swapcase
    txt.reverse! if op == :reverse

    replace_range(r, txt)
    end_visual_mode
  end

  def copy_line()
    $method_handles_repeat = true
    num_lines = 1
    if !$next_command_count.nil? and $next_command_count > 0
      num_lines = $next_command_count
      debug "copy num_lines:#{num_lines}"
    end
    set_clipboard(self[line_range(@lpos, num_lines)])
    $paste_lines = true
  end

  def delete_active_selection() #TODO: remove this function
    return if !@visual_mode #TODO: this should not happen

    _start, _end = get_visual_mode_range
    set_clipboard(self[_start, _end])
    end_visual_mode
  end

  def end_visual_mode()
    #TODO:take previous mode (insert|command) from stack?
    $at.set_mode(COMMAND)
    @visual_mode = false
  end

  def get_visual_mode_range2()
    r = get_visual_mode_range
    return [r.begin, r.end]
  end

  def get_visual_mode_range()
    _start = @selection_start
    _end = @pos

    _start, _end = _end, _start if _start > _end
    _end = _end + 1 if _start < _end

    return _start..(_end - 1)
  end

  def selection_start()
    return -1 if !@visual_mode
    return @selection_start if @visual_mode
  end

  def visual_mode?()
    return @visual_mode
  end

  def value()
    return self.to_s
  end

  def save_as()
    qt_file_saveas()
  end

  #  https://github.com/manveru/ver
  def save()
    if !@fname
      puts "TODO: SAVE AS"
      qt_file_saveas()
      return
    end
    message("Saving file #{@fname}")

    Thread.new {
      contents = self.to_s
      File.open(@fname, "w+") do |io|
        #io.set_encoding(self.encoding)

        begin
          io.write(contents)
        rescue Encoding::UndefinedConversionError => ex
          # this might happen when trying to save UTF-8 as US-ASCII
          # so just warn, try to save as UTF-8 instead.
          warn("Saving as UTF-8 because of: #{ex.class}: #{ex}")
          io.rewind

          io.set_encoding(Encoding::UTF_8)
          io.write(contents)
          #self.encoding = Encoding::UTF_8
        end
      end
      sleep 3
    }
  end

  # Indents whole buffer using external program
  def indent()
    file = Tempfile.new("out")
    infile = Tempfile.new("in")
    file.write($buffer.to_s)
    file.flush
    bufc = "FOO"

    tmppos = @pos

    message("Auto format #{@fname}")

    if get_file_type() == "c"
      #C/C++/Java/JavaScript/Objective-C/Protobuf code
      system("clang-format -style='{BasedOnStyle: LLVM, ColumnLimit: 100,  SortIncludes: false}' #{file.path} > #{infile.path}")
      bufc = IO.read(infile.path)
      puts bufc
    elsif get_file_type() == "ruby"
      #TODO:
      #            cmd = "./vendor/ruby_formatter.rb -s 4 #{file.path}"
      cmd = "rufo #{file.path}"
      puts cmd
      system(cmd)
      system("cp #{file.path} /tmp/foob")
      bufc = IO.read(file.path)
    else
      return
    end
    $buffer.set_content(bufc)
    set_pos(tmppos)
    $do_center = 1
    file.close; file.unlink
    infile.close; infile.unlink
  end

  def backup()
    fname = @fname
    return if !@fname
    message("Backup buffer #{fname}")
    spfx = fname.gsub("=", "==").gsub("/", "=:")
    spath = File.expand_path("~/autosave")
    datetime = DateTime.now().strftime("%d%m%Y:%H%M%S")
    savepath = "#{spath}/#{spfx}_#{datetime}"
    if is_path_writable(savepath)
      puts "BACKUP BUFFER TO: #{savepath}"
      IO.write(savepath, $buffer.to_s)
    else
      message("PATH NOT WRITABLE: #{savepath}")
    end
  end
end

def write_to_file(savepath, s)
  if is_path_writable(savepath)
    IO.write(savepath, $buffer.to_s)
  else
    message("PATH NOT WRITABLE: #{savepath}")
  end
end

def is_path_writable(fpath)
  r = false
  if fpath.class == String
    r = true if File.writable?(Pathname.new(fpath).dirname)
  end
  return r
end

def backup_all_buffers()
  for buf in $buffers
    buf.backup
  end
  message("Backup all buffers")
end