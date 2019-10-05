require "digest"
require "tempfile"
require "pathname"
require "openssl"
require "ripl/multi_line"

$paste_lines = false
$buffer_history = [0]

$update_highlight = true

module Differ
  class Diff
    def get_raw_array()
      return @raw
    end
  end
end

def save_buffer_list()
  message("Save buffer list")
  buffn = get_dot_path("buffers.txt")
  f = File.open(buffn, "w")
  bufstr = $buffers.collect { |buf| buf.fname }.inspect
  f.write(bufstr)
  f.close()
end

def load_buffer_list()
  message("Load buffer list")
  buffn = get_dot_path("buffers.txt")
  return if !File.exist?(buffn)
  bufstr = IO.read(buffn)
  buflist = eval(bufstr)
  debug buflist
  for buf in buflist
    load_buffer(buf) if buf != nil and File.file?(buf)
  end
end

class BufferList < Array
  attr_reader :current_buf

  def <<(_buf)
    super
    $buffer = _buf
    @current_buf = self.size - 1
    $buffer_history << @current_buf
    @recent_ind = 0
    $hook.call(:change_buffer, $buffer)
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
    debug "SWITCH TO LAST BUF:"
    debug $buffer_history
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

    $hook.call(:change_buffer, $buffer)

    set_window_title("Vimamsa - #{fpath}")
    $buffer.need_redraw!
    $buffer.reset_highlight
    hpt_scan_images() if $debug # experimental
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
    debug "IND:#{@recent_ind} RECENT:#{recent.join(" ")}"
    set_current_buffer(bufid, false)
  end

  def history_switch_forwards()
    recent = get_recent_buffers()
    @recent_ind -= 1
    @recent_ind = self.size - 1 if @recent_ind < 0
    bufid = recent[@recent_ind]
    debug "IND:#{@recent_ind} RECENT:#{recent.join(" ")}"
    set_current_buffer(bufid, false)
  end

  def compact_buf_history()
    h = {}
    # Keep only first occurence in history
    bh = $buffer_history.reverse.select { |x| r = h[x] == nil; h[x] = true; r }
    $buffer_history = bh.reverse
  end

  def close_buffer(buffer_i, from_recent = false)
    return if self.size <= buffer_i

    bufname = self[buffer_i].basename
    message("Closed buffer #{bufname}")
    recent = get_recent_buffers
    jump_to_buf = recent[@recent_ind + 1]
    jump_to_buf = 0 if jump_to_buf == nil

    self.slice!(buffer_i)
    $buffer_history = $buffer_history.collect { |x| r = x; r = x - 1 if x > buffer_i; r = nil if x == buffer_i; r }.compact

    if @current_buf == buffer_i
      if from_recent
        @current_buf = jump_to_buf
      else
        @current_buf = $buffer_history.last
      end
    end
    # Ripl.start :binding => binding
    if self.size == 0
      self << Buffer.new("\n")
      @current_buf = 0
    else
      @current_buf = 0 if @current_buf >= self.size
    end
    set_current_buffer(@current_buf, false)
  end

  def close_all_buffers()
    message("Closing all buffers")
    while true
      if self.size == 1
        close_buffer(0)
        break
      else
        close_buffer(0)
      end
    end
    # self << Buffer.new("\n")
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

  def close_current_buffer(from_recent = false)
    close_buffer(@current_buf, from_recent)
  end
end

# Return currently active buffer
def buf()
  return $buffer
end

class Buffer < String

  #attr_reader (:pos, :cpos, :lpos)

  attr_reader :pos, :lpos, :cpos, :deltas, :edit_history, :fname, :call_func, :pathname, :basename, :update_highlight, :marks, :is_highlighted, :syntax_detect_failed
  attr_writer :call_func, :update_highlight
  attr_accessor :qt_update_highlight, :update_hl_startpos, :update_hl_endpos, :hl_queue, :syntax_parser, :highlights, :qt_reset_highlight, :is_parsing_syntax, :line_ends

  def initialize(str = "\n", fname = nil)
    debug "Buffer.rb: def initialize"
    super(str)
    @crypt = nil
    @update_highlight = true
    @syntax_detect_failed = false
    @is_parsing_syntax = false
    @last_update = Time.now - 100
    if fname != nil
      @fname = File.expand_path(fname)
    else
      @fname = fname
    end
    @hl_queue = []

    @qt_reset_highlight = true

    t1 = Time.now
    set_content(str)
    debug "init time:#{Time.now - t1}"

    # TODO: add \n when chars are added after last \n
    self << "\n" if self[-1] != "\n"
    @current_word = nil
  end

  def add_image(imgpath, pos)
    return if !is_legal_pos(pos)
    # insert_txt_at(" ", pos)
    qt_process_deltas
    qt_add_image(imgpath, pos)
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

  def set_encrypted(password)
    @crypt = Encrypt.new(password)
    message("Set buffer encrypted")
  end

  def set_unencrypted()
    @crypt = nil
  end

  def get_file_type()
    # We cant detect syntax if no filename
    if !@fname
      @syntax_detect_failed = true
      return ""
    end
    if @ftype == nil
      @ftype = VER::Syntax::Detector.detect(@fname)
      if @ftype == nil
        @syntax_detect_failed = true
      else
        @syntax_detect_failed = false
      end
    end
    debug "ftype=#{@ftype.inspect}"
    return @ftype
  end

  def create_syntax_parser()
    @syntax_detect_failed = false
    debug("Create @syntax_parser")
    ft = self.get_file_type()
    file = "vendor/ver/config/syntax/#{ft}.rb"
    if File.exist?(file)
      @syntax_parser = Textpow::SyntaxNode.load(file)
    else
      debug "NON-HIGHLIGHTABLE FILE: '#{ft}'"
      @syntax_detect_failed = true
      return
    end
  end

  def highlight()
    # puts "higlight()"
    return if !$cnf[:syntax_highlight]
    return if @syntax_detect_failed
    return if fname == nil
    # debug "START HIGHLIGHT"

    if @syntax_parser != nil
      # Not first time, calculate only for changed part
    else
      @update_hl_startpos = 0
      @update_hl_endpos = self.size - 1
      add_hl_update(@update_hl_startpos, @update_hl_endpos)
      debug "@update_hl_endpos = #{@update_hl_endpos}"
    end

    if @syntax_parser == nil
      create_syntax_parser()
    end

    @is_highlighted = true
    # debug "@update_highlight=#{@update_highlight}"
    if @update_highlight and (Time.now - @last_update > 5) and !@is_parsing_syntax
      @is_parsing_syntax = true
      @last_update = Time.now
      # if (Time.now - @last_update > 5)
      debug "if @update_highlight"

      #            Ripl.start :binding => binding
      bufstr = $buffer.to_s
      curbuf = $buffer
      t1 = Thread.new {
        debug "START HL parsing #{Time.now}"
        sp = Processor.new
        curbuf.syntax_parser.parse(bufstr, sp)

        #TODO
        curbuf.highlights.delete_if { |x| true }
        curbuf.highlights.merge!(sp.highlights)

        # if doing like this, sometimes segfaults from Highlighter::highlightBlock
        # which tries to use old $buffer.highlights
        # curbuf.highlights = sp.highlights

        $update_highlight = true

        @hl_queue.clear
        add_hl_update(0, self.size - 1)
        debug "END oF HL parsing"
        # @last_update = Time.now
        curbuf.is_parsing_syntax = false
        @qt_update_highlight = true
      }

      @update_highlight = false
    end
    # puts @highlight
  end

  def revert()
    return if !@fname
    return if !File.exists?(@fname)
    message("Revert buffer #{@fname}")
    str = read_file("", @fname)
    self.set_content(str)
  end

  def reset_highlight()
    @update_highlight = true
    @qt_reset_highlight = true
    @update_hl_startpos = 0 #TODO
    @update_hl_endpos = self.size - 1
    @last_update = Time.now - 10
    add_hl_update(@update_hl_startpos, @update_hl_endpos)
    # message("Reset highlight: #{@update_hl_startpos} #{@update_hl_endpos}")
    # highlight()
  end

  def decrypt(password)
    begin
      @crypt = Encrypt.new(password)
      str = @crypt.decrypt(@encrypted_str)
    rescue OpenSSL::Cipher::CipherError => e
      str = "incorrect password"
    end
    self.set_content(str)
  end

  def sanitycheck_btree()
      return
    lines = self.split("\n")

    ok = true
    for i in 0..(lines.size - 1)
      leaf = @bt.tree.get_line(i)
      spos = leaf.pos
      epos = (leaf.pos + leaf.nchar - 2)
      r = ""
      r = self[spos..epos] if epos >= spos
      if lines[i] != r #or true
        puts "NO MATCH FOR LINE:"
        puts "i=#{i}["
        puts "pos=#{leaf.pos} |#{leaf.data}|"
        puts "spos=#{spos} nchar=#{leaf.nchar} epos=#{epos} a[]=\n|#{r}|"
        puts "|#{lines[i]}"
        puts "]"
        ok = false
      end
    end
    puts "BT: NO ERRORS" if ok

    puts "nchar=#{@bt.numchars} a.size=#{self.size} lines=#{@bt.numlines}"
  end

  def set_content(str)
    @encrypted_str = nil
    @qt_update_highlight = true
    @ftype = nil
    if str[0..10] == "VMACRYPT001"
      @encrypted_str = str[11..-1]
      gui_one_input_action("Decrypt", "Password:", "decrypt", "decrypt_cur_buffer")
      str = "ENCRYPTED"
    else
      # @crypt = nil
    end

    if (str[-1] != "\n")
      str << "\n"
    end

    self.replace(str)
    @line_ends = scan_indexes(self, /\n/)

    @bt = BufferTree.new(str)
    if $debug
      sanitycheck_btree()
    end

    @last_update = Time.now - 10
    debug("line_ends")
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

    @is_highlighted = false
    @update_highlight = true
    @update_hl_startpos = 0 #TODO
    @update_hl_endpos = self.size - 1
    # add_hl_update(@update_hl_startpos, @update_hl_endpos)
  end

  def set_filename(filename)
    @fname = filename
    @pathname = Pathname.new(fname) if @fname
    @basename = @pathname.basename if @fname
    create_syntax_parser()
    reset_highlight()
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

  #TODO: change to apply=true as default
  def add_delta(delta, apply = false, auto_update_cpos = false)
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
  end

  def add_hl_update(startpos, endpos)
    return if @is_highlighted == false
    @hl_queue << [startpos, endpos]
  end

  def run_delta(delta, auto_update_cpos = false)
    # auto_update_cpos: In some cases position of cursor should be updated automatically based on change to buffer (delta). In other cases this is handled by the action that creates the delta.
    if $experimental
      @bt.handle_delta(Delta.new(delta[0],delta[1],delta[2],delta[3]))
    end
    pos = delta[0]
    if @edit_pos_history.any? and (@edit_pos_history.last - pos).abs <= 2
      @edit_pos_history.pop
    end

    lsp = get_line_start(pos)

    if @edit_pos_history[-1] != lsp
      @edit_pos_history << lsp
    end
    @edit_pos_history_i = 0

    if delta[1] == DELETE
      delta[3] = self.slice!(delta[0], delta[2])
      @deltas << delta
      update_index(pos, -delta[2])
      update_line_ends(pos, -delta[2], delta[3])
      update_highlights(pos, -delta[2], delta[3])
      update_cursor_pos(pos, -delta[2]) if auto_update_cpos

      @update_hl_startpos = pos - delta[2]
      @update_hl_endpos = pos
      add_hl_update(@update_hl_startpos, @update_hl_endpos)
      debug "@update_hl_endpos = #{@update_hl_endpos}"
    elsif delta[1] == INSERT
      self.insert(delta[0], delta[3])
      @deltas << delta
      debug [pos, +delta[2]].inspect
      update_index(pos, +delta[2])
      update_cursor_pos(pos, +delta[2]) if auto_update_cpos
      update_line_ends(pos, +delta[2], delta[3])
      update_highlights(pos, +delta[2], delta[3])

      @update_hl_startpos = pos
      @update_hl_endpos = pos + delta[2]
      add_hl_update(@update_hl_startpos, @update_hl_endpos)
      debug "@update_hl_endpos = #{@update_hl_endpos}"
    end
    debug "DELTA=#{delta.inspect}"
    # sanity_check_line_ends #TODO: enable with debug mode
    #highlight_c()

    $update_highlight = true
    @update_highlight = true

    return delta
  end

  # Update cursor position after change in buffer contents.
  # e.g. after processing with external command like indenter
  def update_cursor_pos(pos, changeamount)
    if @pos > pos + 1 && changeamount > 0
      # @pos is after addition
      set_pos(@pos + changeamount)
    elsif @pos > pos && changeamount < 0 && @pos < pos - changeamount
      # @pos is between removal
      set_pos(pos)
    elsif @pos > pos && changeamount < 0 && @pos >= pos - changeamount
      # @pos is after removal
      set_pos(@pos + changeamount)
    end
  end

  def update_index(pos, changeamount)
    # puts "pos #{pos}, changeamount #{changeamount}, @pos #{@pos}"
    @edit_pos_history.collect! { |x| r = x if x <= pos; r = x + changeamount if x > pos; r }
    # TODO: handle between removal case
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
    center_on_current_line
    #        end
  end

  def jump_to_next_edit()
    return if @edit_pos_history.empty?
    @edit_pos_history_i -= 1
    @edit_pos_history_i = @edit_pos_history.size - 1 if @edit_pos_history_i < 0
    #        Ripl.start :binding => binding
    debug "@edit_pos_history_i=#{@edit_pos_history_i}"
    set_pos(@edit_pos_history[-@edit_pos_history_i])
    center_on_current_line
  end

  def undo()
    debug @edit_history.inspect
    return if !@edit_history.any?
    last_delta = @edit_history.pop
    @redo_stack << last_delta
    debug last_delta.inspect
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
    debug redo_delta.inspect
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
    return nil if @syntax_detect_failed

    com_str = nil
    if get_file_type() == "C" or get_file_type() == "Javascript"
      com_str = "//"
    elsif get_file_type() == "Ruby"
      com_str = "#"
    else
      com_str = "//"
    end
    return com_str
  end

  def comment_linerange(r)
    com_str = get_com_str()
    #lines = $buffer[r].split(/(\n)/).each_slice(2).map { |x| x[0] }
    lines = $buffer[r].lines
    mod = ""
    lines.each { |line|
      m = line.match(/^(\s*)(\S.*)/)
      if m == nil or m[2].size == 0
        ret = line
      elsif m[2].size > 0
        ret = "#{m[1]}#{com_str} #{m[2]}\n"
      end
      mod << ret
    }
    replace_range(r, mod)
  end

  def get_line_start(pos)

    # Bsearch: https://www.rubydoc.info/stdlib/core/Array#bsearch-instance_method
    # In find-minimum mode (this is a good choice for typical use case), the block must return true or false, and there must be an index i (0 <= i <= ary.size) so that:
    # the block returns false for any element whose index is less than i, and
    # the block returns true for any element whose index is greater than or equal to i.
    # This method returns the i-th element. If i is equal to ary.size, it returns nil.

    # (OLD) slower version:
    # ls = @line_ends.select { |x| x < pos }.max
    a = @line_ends.bsearch_index { |x| x >= pos }

    a = @line_ends[-1] if a == nil
    a = 0 if a == nil
    if a > 0
      a = a - 1
    else
      a = 0
    end
    ls = nil
    ls = @line_ends[a] if a != nil
    # if a != nil and ls != @line_ends[a]
    # puts "NO MATCH @line_ends[a]"
    # Ripl.start :binding => binding
    # end

    if ls == nil
      ls = 0
    else
      ls = ls + 1
    end
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
      #      last = get_line_end(endpos)
      last = get_line_end(endpos - 1)
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
    mod = lines.collect { |x| x.sub(/^(\s*)(#{com_str}\s?)/, '\1') + "\n" }.join()
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
    insert_txt_at(text, range.begin)
  end

  def current_line_range()
    range = line_range(@lpos, 1)
    return range
  end

  def line_range(start_line, num_lines, include_last_nl = true)
    end_line = start_line + num_lines - 1
    if end_line >= @line_ends.size
      debug("lpos too large") #TODO
      end_line = @line_ends.size - 1
    end
    start = @line_ends[start_line - 1] + 1 if start_line > 0
    start = 0 if start_line == 0
    if include_last_nl
      _End = @line_ends[end_line]
    else
      _End = @line_ends[end_line] - 1
    end
    _End = start if _End < start
    debug "line range: start=#{start}, end=#{_End}"
    return start.._End
  end

  def copy(range_id)
    $paste_lines = false
    debug "range_id: #{range_id}"
    debug range_id.inspect
    range = get_range(range_id)
    debug range.inspect
    set_clipboard(self[range])
  end

  def recalc_line_ends()
    t1 = Time.now
    leo = @line_ends.clone
    @line_ends = scan_indexes(self, /\n/)
    if @line_ends == leo
      debug "No change to line ends"
    else
      debug "CHANGES to line ends"
    end

    debug "Scan line_end time: #{Time.now - t1}"
    #puts @line_ends
  end

  def sanity_check_line_ends()
    leo = @line_ends.clone
    @line_ends = scan_indexes(self, /\n/)
    if @line_ends == leo
      debug "No change to line ends"
    else
      debug "CHANGES to line ends"
      debug leo.inspect
      debug @line_ends.inspect
      crash("CHANGES to line ends")
    end
  end

  def update_bufpos_on_change(positions, xpos, changeamount)
    # puts "xpos=#{xpos} changeamount=#{changeamount}"
    positions.collect { |x|
      r = nil
      r = x if x < xpos
      r = x + changeamount if changeamount < 0 && x + changeamount >= xpos
      r = x + changeamount if changeamount > 0 && x >= xpos
      r
    }
  end

  def update_highlights(pos, changeamount, changestr)
    return if !self.is_highlighted # $cnf[:syntax_highlight]
    lpos, cpos = get_line_and_col_pos(pos)
    if @highlights and @highlights[lpos]
      hl = @highlights[lpos]
      hls = hl.collect { |x| x[0] } # highlight range start
      hle = hl.collect { |x| x[1] } # highlight range end
      hls2 = update_bufpos_on_change(hls, cpos, changeamount)
      hle2 = update_bufpos_on_change(hle, cpos, changeamount)
      hlnew = []
      for i in hle.size.times
        if hls2[i] != nil and hle2[i] != nil
          hlnew << [hls2[i], hle2[i], hl[i][2]]
        end
      end
      @highlights[lpos] = hlnew
    end
  end

  def update_line_ends(pos, changeamount, changestr)
    if changeamount > -1
      changeamount = changestr.size
      i_nl = scan_indexes(changestr, /\n/)
      i_nl.collect! { |x| x + pos }
    end
    #    puts "change:#{changeamount}"
    #TODO: this is the bottle neck in insert_txt action
    @line_ends.collect! { |x|
      r = nil
      r = x if x < pos
      r = x + changeamount if changeamount < 0 && x + changeamount >= pos
      r = x + changeamount if changeamount > 0 && x >= pos
      r
    }.compact!

    if changeamount > -1 && i_nl.size > 0
      @line_ends.concat(i_nl)
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
      @pos = self.size - 1 # TODO:??right side of last char
    elsif new_pos >= 0
      @pos = new_pos
    end
    calculate_line_and_column_pos
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
    return if range == nil
    debug "RANGE"
    debug range.inspect
    debug range.inspect
    debug "------"
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
    range = nil
    if range_id == :to_word_end
      wmarks = get_word_end_marks(@pos, @pos + 150)
      if wmarks.any?
        range = @pos..wmarks[0]
      end
    elsif range_id == :to_line_end
      puts "TO LINE END"
      range = @pos..(@line_ends[@lpos] - 1)
    elsif range_id == :to_line_start
      puts "TO LINE START: #{@lpos}"

      if @cpos == 0
        range = nil
      else
        if @lpos == 0
          startpos = 0
        else
          startpos = @line_ends[@lpos - 1] + 1
        end
        endpos = @pos - 1
        range = startpos..endpos
      end
      # range = startpos..(@pos - 1)
    else
      crash("INVALID RANGE")
    end
    return range if range == nil
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
    wsm = scan_marks(@pos - 200, @pos, /((?<=\s)\S)|^\S/)

    # Ripl.start :binding => binding
    word_start = wsm[-1]
    word_end = wem[0]
    word_start = pos if word_start == nil
    word_end = pos if word_end == nil
    word = self[word_start..word_end]
    puts "'WORD: #{word}'"
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
    elsif hpt_check_cur_word(word)
      puts word
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
    if $kbd.last_action == $kbd.cur_action and @current_word != nil
      # puts "REPEATING *"
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
      #insert_txt(' ',AFTER)
      insert_txt(" ", BEFORE)
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
    debug "self_pos:'#{self[@pos]}'"
    return if self[@pos] == "\n"
    d1 = [@pos, DELETE, 1]
    d2 = [@pos, INSERT, 1, char]
    add_delta(d1, true)
    add_delta(d2, true)
    debug "DELTAS:#{$buffer.deltas.inspect} "
  end

  def insert_txt_at(c, pos)
    c = c.force_encoding("UTF-8");  #TODO:correct?
    c = "\n" if c == "\r"
    add_delta([pos, INSERT, c.size, c], true)
    calculate_line_and_column_pos
  end

  def insert_new_line()
    s = get_current_line
    $hook.call(:insert_new_line, s)
    insert_txt("\n")
    # message("foo")
  end

  def insert_txt(c, mode = BEFORE)
    # start_profiler
    #Sometimes we get ASCII-8BIT although actually UTF-8  "incompatible character encodings: UTF-8 and ASCII-8BIT (Encoding::CompatibilityError)"
    c = c.force_encoding("UTF-8");  #TODO:correct?

    c = "\n" if c == "\r"
    if $cnf[:indent_based_on_last_line] and c == "\n" and @lpos > 0
      # Indent start of new line based on last line
      last_line = line(@lpos)
      m = /^( +)([^ ]+|$)/.match(last_line)
      debug m.inspect
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
    # end_profiler
  end

  # Update buffer contents to newstr
  # Change by taking diff of old/new content
  def update_content(newstr)
    diff = Differ.diff_by_char(newstr, self.to_s)

    da = diff.get_raw_array

    pos = 0
    posA = 0
    posB = 0
    deltas = []

    for x in da
      if x.class == String
        posA += x.size
        posB += x.size
      elsif x.class == Differ::Change
        if x.insert?
          deltas << [posB, INSERT, x.insert.size, x.insert.clone]
          posB += x.insert.size
        elsif x.delete?
          posA += x.delete.size
          deltas << [posB, DELETE, x.delete.size]
        end
      end
    end
    for d in deltas
      add_delta(d, true, true)
    end
    # $buffer.update_content(IO.read('test.txt'))
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
      debug "PASTE LINES"
      l = current_line_range()
      debug "------------"
      debug l.inspect
      debug "------------"
      #$buffer.move(FORWARD_LINE)
      #set_pos(l.end+1)
      insert_txt_at(text, l.end + 1)
      set_pos(l.end + 1)
    else
      if at_end_of_buffer? or at_end_of_line? or at == BEFORE
        pos = @pos
      else
        pos = @pos + 1
      end
      insert_txt_at(text, pos)
      set_pos(pos + text.size)
    end
    #TODO: AFTER does not work
    #insert_txt($clipboard[-1],AFTER)
    #recalc_line_ends #TODO: bug when run twice?
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
    $kbd.set_mode(:visual)
  end

  def copy_active_selection()
    debug "!COPY SELECTION"
    $paste_lines = false
    return if !@visual_mode

    debug "COPY SELECTION"
    set_clipboard(self[get_visual_mode_range])
    end_visual_mode
    return true
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

  def convert_selected_text(converter_id)
    return if !@visual_mode
    r = get_visual_mode_range
    txt = self[r]
    txt = $vma.apply_conv(converter_id, txt)
    #TODO: Detect if changed?
    replace_range(r, txt)
    end_visual_mode
  end

  def style_transform(op)
    return if !@visual_mode
    r = get_visual_mode_range
    #TODO: if txt[-1]=="\n"
    txt = self[r]
    txt = "⦁" + txt + "⦁" if op == :bold
    txt = "⟦" + txt + "⟧" if op == :link
    txt = "❙" + txt + "❙" if op == :title
    txt.gsub!(/[❙◼⟦⟧⦁]/, "") if op == :clear

    replace_range(r, txt)
    end_visual_mode
  end

  def set_line_style(op)
    lrange = line_range(@lpos, 1, false)
    txt = self[lrange]
    # txt = "◼ " + txt if op == :heading
    txt = "⦁" + txt + "⦁" if op == :bold
    txt = "❙" + txt + "❙" if op == :title
    txt.gsub!(/◼ /, "") if op == :clear
    txt.gsub!(/[❙◼⟦⟧⦁]/, "") if op == :clear or [:h1, :h2, :h3, :h4].include?(op)

    if [:h1, :h2, :h3, :h4].include?(op)
      txt.strip!
      txt = "◼ " + txt if op == :h1
      txt = "◼◼ " + txt if op == :h2
      txt = "◼◼◼ " + txt if op == :h3
      txt = "◼◼◼◼ " + txt if op == :h4
    end
    replace_range(lrange, txt)
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

  def get_current_line
    s = self[line_range(@lpos, 1)]
    return s
  end

  def put_file_path_to_clipboard
    set_clipboard(self.fname)
  end

  def delete_active_selection() #TODO: remove this function
    return if !@visual_mode #TODO: this should not happen

    _start, _end = get_visual_mode_range
    set_clipboard(self[_start, _end])
    end_visual_mode
  end

  def end_visual_mode()
    #TODO:take previous mode (insert|command) from stack?
    $kbd.set_mode(:command)
    @visual_mode = false
    return true
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
    debug "save_as"
    savepath = ""

    # If current file has fname, save to that fname
    # Else search for previously open files and save to the directory of
    # the last viewed file that has a filename
    # $buffers[$buffer_history.reverse[1]].fname

    if @fname
      savepath = @fname
    else
      for bufid in $buffer_history.reverse[1..-1]
        buf = $buffers[bufid]
        debug "FNAME:#{buf.fname}"
        if buf.fname
          savepath = File.dirname(buf.fname)
          break
        end
      end
    end
    # Ripl.start :binding => binding
    qt_file_saveas(savepath)
    # calls back to file_saveas
    # TODO:?
  end

  def save()
    if !@fname
      save_as()
      return
    end
    message("Saving file #{@fname}")
    if @crypt != nil
      mode = "wb+"
      contents = "VMACRYPT001" + @crypt.encrypt(self.to_s)
    else
      mode = "w+"
      contents = self.to_s
    end

    Thread.new {
      File.open(@fname, mode) do |io|
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

    if get_file_type() == "C" or get_file_type() == "C++"

      #C/C++/Java/JavaScript/Objective-C/Protobuf code
      system("clang-format -style='{BasedOnStyle: LLVM, ColumnLimit: 100,  SortIncludes: false}' #{file.path} > #{infile.path}")
      bufc = IO.read(infile.path)
    elsif get_file_type() == "Javascript"
      cmd = "/home/samisi/bin/clang-format #{file.path} > #{infile.path}'"
      debug cmd
      system(cmd)
      bufc = IO.read(infile.path)
    elsif get_file_type() == "Ruby"
      cmd = "rufo #{file.path}"
      debug cmd
      system(cmd)
      bufc = IO.read(file.path)
    else
      return
    end
    $buffer.update_content(bufc)
    #    set_pos(tmppos)
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
    return false if !can_save_to_directory?(spath)
    datetime = DateTime.now().strftime("%d%m%Y:%H%M%S")
    savepath = "#{spath}/#{spfx}_#{datetime}"
    if is_path_writable(savepath)
      debug "BACKUP BUFFER TO: #{savepath}"
      IO.write(savepath, self.to_s) if @crypt == nil #TODO: For encrypted
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
