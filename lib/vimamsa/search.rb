

class Search

  #attr_reader (:pos, :cpos, :lpos)

  #attr_reader :pos, :lpos, :cpos, :deltas, :fname

  def initialize()
    @cur_search_i = -1
  end

  def set(search_str, search_type, buffer)
    @search_str = search_str
    @search_type = search_type
    @buffer = buffer
    regex = Regexp.escape(search_str)
    if /.*\p{Upper}.*/ =~ regex
      reg = Regexp.new(regex)
    else
      # if does not contain uppercase characters, ignore case
      reg = Regexp.new(regex, Regexp::IGNORECASE)
    end
    @search_indexes = scan_indexes(buffer, reg)
    puts @search_indexes.inspect
    @cur_search_i = -1
    if @search_indexes.any?
      @cur_search_i = 0
      startpos = @search_indexes.select { |x| x > @buffer.pos }.min
      if startpos != nil
        @cur_search_i = @search_indexes.find_index(startpos)
      end
      @buffer.set_pos(@search_indexes[@cur_search_i])
    end
  end

  def jump_to_next()
    return if @cur_search_i < 0

    if @search_indexes.size > @cur_search_i + 1
      @cur_search_i = @cur_search_i + 1
    else
      @cur_search_i = 0
    end
    @buffer.set_pos(@search_indexes[@cur_search_i])
  end

  def jump_to_previous()
    return if @cur_search_i < 0

    if @cur_search_i - 1 < 0
      @cur_search_i = @search_indexes.size - 1
    else
      @cur_search_i = @cur_search_i - 1
    end
    @buffer.set_pos(@search_indexes[@cur_search_i])
  end
end
