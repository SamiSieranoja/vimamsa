require 'digest'

class BufferList < Array

    def <<(_buf)
        super
        $buffer =_buf
        @current_buf = self.size - 1
    end

    def switch()
        debug "SWITCH BUF. bufsize:#{self.size}, curbuf: #{@current_buf}"
        @current_buf += 1
        @current_buf = 0 if @current_buf >= self.size
        $buffer = self[@current_buf]
        $buffer.need_redraw!
        m = method("switch")
        set_last_command({method: m, params: []})

        set_window_title("VIwbaw - #{File.basename($buffer.fname)}")
        # TODO: set window title
    end

    def get_buffer_by_filename(fname) 
        bufs = self.select{|b| b.fname == fname}
        if bufs.any?
            return bufs.first
        else
            return nil
        end
    end

    def set_current_buffer(buf) 
        i = self.index(buf)
        @current_buf = i
        $buffer = buf
        $buffer.need_redraw!
    end

end



class Buffer < String

    #attr_reader (:pos, :cpos, :lpos)

    attr_reader :pos, :lpos, :cpos, :deltas, :fname

    def initialize(str,fname)
        if(str[-1] != "\n")
            str << "\n"
        end
        super(str)
        t1 = Time.now
        @line_ends = scan_indexes(self,/\n/)
        puts @line_ends
        puts str.inspect
        @fname = fname
        @pos = 0 # Position in whole string
        @cpos = 0 # Column position on current line
        @lpos = 0 # Number of current line
        @larger_cpos = 0 
        @need_redraw = 1
        @deltas = []
        puts Time.now - t1
        # TODO: add \n when chars are added after last \n
        self << "\n" if self[-1] != "\n"
    end
    def line(lpos)
        #TODO: implement using line_range()
        if lpos >= @line_ends.size
            debug("lpos too large") #TODO
            return ""
        elsif lpos == @line_ends.size
        end
        start = @line_ends[lpos - 1] if lpos > 0
        start = 0 if lpos == 0
        _end = @line_ends[lpos] - 1
        debug "start: _#{start}, end: #{_end}"
        return self[start.._end]
    end

    def current_char()
        return self[@pos]
    end

    def current_line()
        range = line_range(@lpos,1)
        return self[range]
    end


    def line_range(start_line,num_lines)
        end_line = start_line + num_lines - 1
        if end_line >= @line_ends.size
            debug("lpos too large") #TODO
            end_line = @line_ends.size - 1
        end
        start = @line_ends[start_line - 1] if start_line > 0
        start = 0 if start_line == 0
        _end = @line_ends[end_line] - 1
        debug "line range: start=#{start}, end=#{_end}"
        return start.._end
    end


    def recalc_line_ends()
        t1 = Time.now
        @line_ends = scan_indexes(self,/\n/)

        puts "Scan line_end time: #{Time.now - t1}"
        #puts @line_ends
    end

    def at_end_of_line?()
        return ( self[@pos] == "\n" or at_end_of_buffer? )
    end
    def at_end_of_buffer?()
        return @pos == self.size
    end

    def set_pos(new_pos)
        @pos = new_pos
        calculate_line_and_column_pos
    end


    # Calculate the two dimensional column and line positions based on current
    # (one dimensional) position in the buffer.
    def calculate_line_and_column_pos()
        @pos = self.size if @pos > self.size
        @pos = 0 if @pos < 0
        #puts @line_ends
        next_line_end = @line_ends.bsearch {|x| x - 1 >= @pos  } #=> 4
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
            @cpos -= @line_ends[@lpos - 1]
        end
    end

    # Calculate the one dimensional array index based on column and line positions
    def calculate_pos_from_cpos_lpos()
        if @lpos > 0
            new_pos = @line_ends[@lpos - 1]
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
    end

  def delete(op)

      # Delete selection
      if op== SELECTION && visual_mode?
          (start,_end) = get_visual_mode_range2
          @deltas << [start,DELETE,(_end - start + 1)]
          self.slice!(start.._end) 
          @pos = [@pos,@selection_start].min
          end_visual_mode

          # Delete current char
      elsif op == CURRENT_CHAR_FORWARD
          @deltas << [@pos,DELETE,1]
          self.slice!(@pos) 

          # Delete current char and then move backward
      elsif op == CURRENT_CHAR_BACKWARD
          @deltas << [@pos,DELETE,1]
          self.slice!(@pos) 
          @pos -= 1

          # Delete the char before current char and move backward
      elsif op == BACKWARD_CHAR
          @deltas << [@pos - 1,DELETE,1]
          self.slice!(@pos - 1) #TODO: check
          @pos -= 1

      elsif op == FORWARD_CHAR #TODO: ok?
          @deltas << [@pos+1,DELETE,1]
          self.slice!(@pos + 1) 
      end

      recalc_line_ends
      calculate_line_and_column_pos
        #need_redraw!
  end
   

    def move(direction)

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

        if direction == BACKWARD_LINE or direction == FORWARD_LINE
            if @lpos > 0
                new_pos = @line_ends[@lpos - 1]
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

            #new_pos += @cpos
            #@pos = new_pos
            calculate_pos_from_cpos_lpos

        end
    end

    def jump_word(direction,wordpos)
        if direction == FORWARD
            debug "POS: #{@pos},"
            if wordpos == WORD_START # 'w'
                
                #wsmarks = scan_indexes(self[@pos..(@pos + 150)],/((\W)\w)|\n\n|\Z/) # \Z = end of string, just before last newline.
                # http://ruby-doc.org/core-2.1.1/Regexp.html
                wsmarks = scan_indexes(self[@pos..(@pos + 150)],/(([^\p{Word}])\p{Word})|\n\n|\Z/) # \Z = end of string, just before last newline.

            elsif wordpos == WORD_END
                #wsmarks = scan_indexes(self[@pos..(@pos + 150)],/(\w(\W)|\n\n)/) # include empty lines?
                #wsmarks = scan_indexes(self[@pos..(@pos + 150)],/(\w(\W))/)
                wsmarks = scan_indexes(self[@pos..(@pos + 150)],/\p{Word}[^\p{Word}]/)

            end
            if wsmarks.any?
                next_pos = @pos + wsmarks[0] - 1
                set_pos(next_pos)
            end
        end
         if direction == BACKWARD
             start_search = @pos - 150
             start_search = 0 if start_search < 0
            wsmarks = scan_indexes(self[start_search..(@pos - 1)],
                                   #/(^|(\W)\w|\n)/) #TODO 150 length limit
                                   /(^|[^\p{Word}]\p{Word}|\n)/) #TODO 150 length limit

            if wsmarks.any?
                next_pos = start_search + wsmarks.last - 1
                set_pos(next_pos)
            end
        end
  
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
            a = scan_indexes(l,/\S/)
            puts a.inspect
            if a.any?
                @cpos = a[0] - 1 
            else
                @cpos = 0
            end
            calculate_pos_from_cpos_lpos
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
                insert_char(' ',AFTER) 
            end
    end



    def jump_to_next_instance_of_char(char,direction=FORWARD)
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
        set_last_command({method: m, params: [char,direction]})
        calculate_line_and_column_pos
    end


    def insert_char(c,mode = BEFORE)
        c = "\n" if c == "\r"
        if mode == BEFORE
            insert_pos = @pos
            @pos += c.size
        elsif mode == AFTER
            insert_pos = @pos +1
        else
            return
        end
        
        self.insert(insert_pos,c)
        @deltas << [insert_pos,INSERT,0,c]
        puts("encoding: #{c.encoding}")
        puts "c.size: #{c.size}"
        recalc_line_ends #TODO: optimize?
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
       #TODO: AFTER does not work
       #insert_char($clipboard[-1],AFTER)
       insert_char($clipboard[-1])
       #recalc_line_ends #TODO: bug when run twice?
    end



    def insert_new_line()
        insert_char("\n")
    end

    def delete_cur_line()
        start = @line_ends[@lpos - 1] if @lpos > 0
        start = 0 if @lpos == 0
        _end = @line_ends[@lpos] - 1

        @deltas << [start,DELETE,_end - start + 1]
        $clipboard << self.slice!(start.._end)
        recalc_line_ends #TODO: optimize?
        calculate_pos_from_cpos_lpos
        #need_redraw!

    end

    def start_visual_mode()
        @visual_mode = true
        @selection_start=@pos
        $at.set_mode(VISUAL)
    end
    def copy_active_selection()
        return if !@visual_mode

        #_start = @selection_start
        #_end = @pos
        #_start,_end = _end,_start if _start > _end

        #_start,_end = get_visual_mode_range
        # TODO: Jump to start pos
        
        $clipboard << self[get_visual_mode_range] #TODO: check if range ok
        end_visual_mode
    end

    def copy_line()
        $method_handles_repeat = true
        num_lines = 1
        if !$next_command_count.nil? and $next_command_count > 0
            num_lines = $next_command_count
            debug "copy num_lines:#{num_lines}"
        end
        $clipboard << self[line_range(@lpos,num_lines)] 
    end



    def delete_active_selection() #TODO: remove this function
        return if !@visual_mode #TODO: this should not happen

        _start,_end = get_visual_mode_range
        $clipboard << self[_start,_end]
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
        _start,_end = _end,_start if _start > _end
        return [_start,_end - 1]
    end

    def get_visual_mode_range()
        _start = @selection_start
        _end = @pos
        _start,_end = _end,_start if _start > _end
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

    #  https://github.com/manveru/ver
    def save()
        
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

end


