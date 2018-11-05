require 'digest'
require 'tempfile'
require 'pathname'
#require 'ripl'
$paste_lines = false

class BufferList < Array

    def <<(_buf)
        super
        $buffer = _buf
        @current_buf = self.size - 1
    end

    def switch()
        debug "SWITCH BUF. bufsize:#{self.size}, curbuf: #{@current_buf}"
        @current_buf += 1
        @current_buf = 0 if @current_buf >= self.size
        #$buffer = self[@current_buf]
        #$buffer.need_redraw!
        m = method("switch")
        set_last_command({method: m, params: []})

        set_current_buffer(@current_buf)
        #set_window_title("VIwbaw - #{File.basename($buffer.fname)}")
        # TODO: set window title
    end

    def get_buffer_by_filename(fname)
        #TODO: check using stat/inode?  http://ruby-doc.org/core-1.9.3/File/Stat.html#method-i-ino        
        buf_idx = self.index{|b| b.fname == fname}
        return buf_idx
    end

    def set_current_buffer(buffer_i)
        $buffer = self[buffer_i]
        @current_buf = buffer_i
        debug "SWITCH BUF2. bufsize:#{self.size}, curbuf: #{@current_buf}"
        set_window_title("VIwbaw - #{$buffer.basename}")
        $buffer.need_redraw!
    end

    def close_buffer(buffer_i)
        self.slice!(buffer_i)
        @current_buf = 0 if @current_buf >= self.size
        if self.size==0
            self << Buffer.new("emptybuf\n")
        end
        set_current_buffer(@current_buf)
    end

    def close_current_buffer
        close_buffer(@current_buf)
    end

end


class Buffer < String

    #attr_reader (:pos, :cpos, :lpos)

    attr_reader :pos, :lpos, :cpos, :deltas, :edit_history, :fname, :call_func, :pathname, :basename
    attr_writer :call_func

    def initialize(str = "\n", fname = nil)
        if (str[-1] != "\n")
            str << "\n"
        end

        @marks = Hash.new

        if 0
            super(str)
            t1 = Time.now
            @line_ends = scan_indexes(self, /\n/)
            puts @line_ends
            puts str.inspect
            @fname = fname
            @basename = ""
            @pathname = Pathname.new(fname) if @fname
            @basename = @pathname.basename if @fname
            @pos = 0 # Position in whole string
            @cpos = 0 # Column position on current line
            @lpos = 0 # Number of current line
            @edit_version = 0 # +1 for every buffer modification
            @larger_cpos = 0
            @need_redraw = 1
            @call_func = nil
            @deltas = []
            @edit_history = []
            @redo_stack = []
            @edit_pos_history = []
            @edit_pos_history_i = 0
        end

        set_content(str)

        puts Time.now - t1
        # TODO: add \n when chars are added after last \n
        self << "\n" if self[-1] != "\n"
    end

    def get_file_type()
        ext = File.extname(@fname)
        ext = ext[1..-1]
        puts "EXT:#{ext}"
        return "ruby" if ext=="rb"
        return "c" if ext=="c" or ext=="cpp" or ext=="h" or ext=="hpp"
    end

    def revert()
        puts @fname.inspect
        str = read_file("",@fname)
        self.set_content(str)
    end

    def set_content(str)
        self.replace(str)
        @line_ends = scan_indexes(self, /\n/)
        #puts str.inspect
        @fname = fname
        @basename = ""
        @pathname = Pathname.new(fname) if @fname
        @basename = @pathname.basename if @fname
        @pos = 0 # Position in whole string
        @cpos = 0 # Column position on current line
        @lpos = 0 # Number of current line
        @edit_version = 0 # +1 for every buffer modification
        @larger_cpos = 0
        @need_redraw = 1
        @call_func = nil
        @deltas = []
        @edit_history = []
        @redo_stack = []
        @edit_pos_history = []
        @edit_pos_history_i = 0
    end

    def set_filename(filename)
        @fname = filename
        @pathname = Pathname.new(fname) if @fname
        @basename = @pathname.basename if @fname
    end

    def line(lpos)
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

    #TODO: change to apply=true as default
    def add_delta(delta, apply = false)
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
            update_index(pos,-delta[2])
            update_line_ends(pos,-delta[2], delta[3])
        elsif delta[1] == INSERT
            self.insert(delta[0], delta[3])
            @deltas << delta
            puts [pos,+delta[2]].inspect
            update_index(pos,+delta[2])
            update_line_ends(pos,+delta[2], delta[3])
        end
        sanity_check_line_ends
        return delta
    end



    def update_index(pos, changeamount)
        puts @edit_pos_history.inspect
        @edit_pos_history.collect! {|x| return x if x <= pos; return x + changeamount if x > pos}
    end

    def jump_to_last_edit()
        @edit_pos_history_i += 1
        puts @edit_pos_history.inspect
        if @edit_pos_history.size >= @edit_pos_history_i
            set_pos(@edit_pos_history[-@edit_pos_history_i])
        end
    end

    def undo()
        puts @edit_history.inspect
        return if !@edit_history.any?
        last_delta = @edit_history.pop
        @redo_stack << last_delta
        puts last_delta.inspect
        if last_delta[1] == DELETE
            d =  [last_delta[0], INSERT, 0, last_delta[3]]
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
        _end = @line_ends[end_line]
        debug "line range: start=#{start}, end=#{_end}"
    return start.._end
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
        exit
    end
end

def update_line_ends(pos, changeamount, changestr)
    puts @line_ends.inspect
    puts pos
    if changeamount > -1
        changeamount = changestr.size
        i = scan_indexes(changestr, /\n/)
        i.collect! {|x|x+pos}
        puts "new LINE ENDS:#{i.inspect}"
    end
    puts "change:#{changeamount}"
    #@line_ends.collect!{|x| return x if x <= pos; return x + changeamount if x > pos}
    @line_ends.collect! {|x | r = nil;
        r = x if x < pos;
        r = x + changeamount if changeamount < 0 && x +changeamount >= pos;
        r = x + changeamount if changeamount > 0 && x >= pos;
    r}.compact!

    if changeamount > -1 && i.size > 0
        @line_ends.concat(i)
        @line_ends.sort!
    end
end

def at_end_of_line?()
    return ( self[@pos] == "\n" or at_end_of_buffer? )
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
end


# Calculate the two dimensional column and line positions based on current
# (one dimensional) position in the buffer.
def calculate_line_and_column_pos(reset=true)
    @pos = self.size if @pos > self.size
    @pos = 0 if @pos < 0
    #puts @line_ends
    next_line_end = @line_ends.bsearch {|x | x  >= @pos  } #=> 4
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
def calculate_pos_from_cpos_lpos(reset=true)
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

def delete(op)

    # Delete selection
    if op== SELECTION && visual_mode?
        (startpos, endpos) = get_visual_mode_range2
        delete_range(startpos, endpos)
        @pos = [@pos,@selection_start].min
        end_visual_mode
        return

        # Delete current char
    elsif op == CURRENT_CHAR_FORWARD
        return if @pos >= self.size - 1 # May not delete last '\n'
        add_delta([@pos, DELETE, 1], true)

        # Delete current char and then move backward
    elsif op == CURRENT_CHAR_BACKWARD
        add_delta([@pos, DELETE, 1], true)
        @pos -= 1

        # Delete the char before current char and move backward
    elsif op == BACKWARD_CHAR
        add_delta([@pos - 1, DELETE, 1], true)
        @pos -= 1

    elsif op == FORWARD_CHAR #TODO: ok?
        add_delta([@pos+1, DELETE, 1], true)
    end

    #recalc_line_ends
    calculate_line_and_column_pos
    #need_redraw!
end


def  delete_range(startpos, endpos)
    #s = self.slice!(startpos..endpos)
    set_clipboard(self[startpos..endpos])
    add_delta([startpos, DELETE,(endpos - startpos + 1)], true)
    #recalc_line_ends
    calculate_line_and_column_pos
end

def get_range(range_id)
    #if range_id == :current_to_next_word_end
if range_id == :to_word_end
    wmarks = get_word_end_marks(@pos,@pos+150)
    if wmarks.any?
        range =  @pos..wmarks[0]
    end
elsif range_id == :to_line_end
    puts "TO LINE END"
    range = @pos..(@line_ends[@lpos] -1)
elsif range_id == :to_line_start
    puts "TO LINE START"
    if @lpos == 0
        startpos = 0
    else
        startpos = @line_ends[@lpos - 1] + 1
    end
    range = startpos..(@pos - 1)
else
    puts "INVALID RANGE"
    exit
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

def delete2(range_id)
    range = get_range(range_id)
    puts "RANGE"
    puts range.inspect
    puts range.inspect
    puts "------"
    delete_range(range.first, range.last)
    @pos = [range.first,@pos].min

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
        if @lpos >= @line_ends.size - 1  # Cursor is on last line
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
    search_str = self[(startpos)..(endpos)]
    return if search_str == nil
    wsmarks = scan_indexes(search_str, /(?<=\p{Word})[^\p{Word}]/)
    wsmarks = wsmarks.collect {|x| x+startpos - 1}
    return wsmarks
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
    position_of_next_word = self.index(current_word,@pos + 1)
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
        search_str = self[(@pos)..(@pos + 150)]
        return if search_str == nil
        if wordpos == WORD_START # vim 'w'

            wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}|\Z/) # \Z = end of string, just before last newline.
            wsmarks2 = scan_indexes(search_str, /\n[ \t]*\n/) # "empty" lines that have whitespace
            wsmarks2 = wsmarks2.collect {|x| x+1}
            wsmarks = (wsmarks2 + wsmarks).sort.uniq
            offset = 0

        elsif wordpos == WORD_END
            wsmarks = scan_indexes(search_str, /(?<=\p{Word})[^\p{Word}]/)
            offset = 0
        end
        if wsmarks.any?
            #puts wsmarks.inspect
            next_pos = @pos + wsmarks[0] + offset
            set_pos(next_pos)
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

    $method_handles_repeat = true
    if !$next_command_count.nil? and $next_command_count > 0
        line_n = $next_command_count
        debug "jump to line:#{line_n}"
    end

    if line_n > @line_ends.size
        debug("lpos too large") #TODO
        return
    end
    if line_n == 1
        set_pos(0)
    else
        set_pos(@line_ends[line_n-2]+1)
    end
end

def join_lines()
    if @lpos >= @line_ends.size - 1  # Cursor is on last line
        debug("ON LAST LINE")
        return
    else
        # TODO: replace all whitespace between lines with ' '
        jump(END_OF_LINE)
        delete(CURRENT_CHAR_FORWARD)
        #insert_char(' ',AFTER) 
        insert_char(' ', BEFORE)
    end
end



def jump_to_next_instance_of_char(char, direction = FORWARD)
    #return if at_end_of_line?
    if direction == FORWARD
        position_of_next_char = self.index(char,@pos + 1)
        if position_of_next_char != nil
            @pos = position_of_next_char
        end
    elsif direction == BACKWARD
        start_search = @pos - 250
        start_search = 0 if start_search < 0
        search_substr = self[start_search..(@pos - 1)]
        _pos = search_substr.reverse.index(char)
        if _pos != nil
            @pos -= ( _pos + 1 )
        end
    end
    m = method("jump_to_next_instance_of_char")
    set_last_command({method: m, params: [char, direction]})
    $last_find_command = {char: char, direction:direction}
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

def insert_char(c, mode = BEFORE)
    #Sometimes we get ASCII-8BIT although actually UTF-8  "incompatible character encodings: UTF-8 and ASCII-8BIT (Encoding::CompatibilityError)"
    c = c.force_encoding("UTF-8"); #TODO:correct?

    c = "\n" if c == "\r"
    if  $cnf[:indent_based_on_last_line] and c == "\n" and @lpos > 0
        # Indent start of new line based on last line
        last_line = line(@lpos)
        m = /^( +)([^ ]+|$)/.match(last_line)
        puts m.inspect
        c = c+" "*m[1].size if m
    end
    if mode == BEFORE
        insert_pos = @pos
        @pos += c.size
    elsif mode == AFTER
        insert_pos = @pos +1
    else
        return
    end

    #self.insert(insert_pos,c)
    add_delta([insert_pos, INSERT, 0, c], true)
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

def paste()
    return if !$clipboard.any?
    if $paste_lines
        l = current_line_range()
        puts "------------"
        puts l.inspect
        puts "------------"
        #$buffer.move(FORWARD_LINE)
        set_pos(l.end+1)
        insert_char($clipboard[-1])
        set_pos(l.end+1)
    else
        insert_char($clipboard[-1])
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
    $paste_lines = true
    num_lines = 1
    if !$next_command_count.nil? and $next_command_count > 0
        num_lines = $next_command_count
        debug "copy num_lines:#{num_lines}"
    end
    lrange = line_range(@lpos, num_lines)
    s = self[lrange]
    add_delta([lrange.begin, DELETE, lrange.end - lrange.begin + 1], true)
    set_clipboard(s)
    #recalc_line_ends
end

def delete_cur_line() #TODO: remove
    #TODO: implement using delete_range
    start = @line_ends[@lpos - 1] + 1 if @lpos > 0
    start = 0 if @lpos == 0
    _end = @line_ends[@lpos]

    s = self.slice!(start.._end)
    add_delta([start, DELETE, _end - start + 1, s])
    set_clipboard(s)
    #recalc_line_ends #TODO: optimize?
    calculate_pos_from_cpos_lpos
    #need_redraw!

end

def start_visual_mode()
    @visual_mode = true
    @selection_start=@pos
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

def copy_line()
    $method_handles_repeat = true
    $paste_lines = true
    num_lines = 1
    if !$next_command_count.nil? and $next_command_count > 0
        num_lines = $next_command_count
        debug "copy num_lines:#{num_lines}"
    end
    set_clipboard(self[line_range(@lpos, num_lines)])
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
    _start = @selection_start
    _end = @pos
_start, _end = _end, _start if _start > _end
return [_start, _end - 1]
end

def get_visual_mode_range()
    _start = @selection_start
    _end = @pos
_start, _end = _end, _start if _start > _end
return _start..(_end - 1)

end

def selection_start()
    return - 1 if !@visual_mode
    return @selection_start if @visual_mode
end

def visual_mode?()
    return @visual_mode
end

def value()
    return self.to_s
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
        File.open(@fname, 'w+') do |io|
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

def identify()
    file = Tempfile.new('out')
    infile = Tempfile.new('in')
    file.write($buffer.to_s)
    file.flush
    bufc = "FOO"

    tmppos = @pos

    if get_file_type()=="c"
        #C/C++/Java/JavaScript/Objective-C/Protobuf code
        #system("clang-format #{file.path} > #{infile.path}")
        # system("clang-format -style='{BasedOnStyle: LLVM, ColumnLimit: 100, AllowShortBlocksOnASingleLine: true, SortIncludes: false, AllowShortIfStatementsOnASingleLine: true}' #{file.path} > #{infile.path}")         
        system("clang-format -style='{BasedOnStyle: LLVM, ColumnLimit: 100,  SortIncludes: false}' #{file.path} > #{infile.path}")
        bufc = IO.read(infile.path)
        puts bufc
    elsif get_file_type()=="ruby"
        #cmd = "/usr/share/universalindentgui/indenters/ruby_formatter.rb -s 4 #{file.path}" 
        cmd = "~/source/viwbaw/ruby_formatter.rb -s 4 #{file.path}" 
        # cmd = "rubocop -x -f simple #{file.path}" 
        puts cmd
        system(cmd)
        system("cp #{file.path} /tmp/foob")
        bufc = IO.read(file.path)
    end
    $buffer.set_content(bufc)
    set_pos(tmppos)
    $do_center = 1
    file.close;  file.unlink
    infile.close;  infile.unlink
end

end
