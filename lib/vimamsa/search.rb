
def execute_search(input_str)
  $search = Search.new
  eval_str="execute_search(#{input_str.dump})"
  $macro.overwrite_current_action(eval_str)
  return $search.set(input_str, "simple", $buffer)
end

def invoke_search()
  nfo = ""
  
  callback = proc{|x| execute_search(x)}
  gui_one_input_action(nfo, "Search:", "search", callback)
end

class Search

  def initialize()
    @cur_search_i = -1
    @search_indexes = []
  end

  def set(search_str, search_type, buffer)
    @search_str = search_str
    @search_type = search_type
    @buffer = buffer
    regex = Regexp.escape(search_str)
    if /.*\p{Upper}.*/ =~ regex
      @reg = Regexp.new(regex)
    else
      # if does not contain uppercase characters, ignore case
      @reg = Regexp.new(regex, Regexp::IGNORECASE)
    end
    @search_indexes = scan_indexes(buffer, @reg)
    debug @search_indexes.inspect
    @cur_search_i = -1
    if @search_indexes.any?
      @cur_search_i = 0
      startpos = @search_indexes.select { |x| x > @buffer.pos }.min
      if startpos != nil
        @cur_search_i = @search_indexes.find_index(startpos)
      end
      @buffer.set_pos(@search_indexes[@cur_search_i])
    else
      return false
    end
  end

  def update_search()
    @search_indexes = scan_indexes(@buffer, @reg)

    @cur_search_i = 0
    startpos = @search_indexes.select { |x| x > @buffer.pos }.min
    if startpos != nil
      @cur_search_i = @search_indexes.find_index(startpos)
    end
    # Ripl.start :binding => binding
  end

  def jump_to_next()
  
    return if @cur_search_i < 0
    # TODO: optimize, update only after buffer changed
    # or search only for the next match
    update_search
    
    return if !@search_indexes.any?

    # if @search_indexes.size > @cur_search_i + 1
    # @cur_search_i = @cur_search_i + 1
    # else
    # @cur_search_i = 0
    # end
    @buffer.set_pos(@search_indexes[@cur_search_i])
  end

  def jump_to_previous()
    return if @cur_search_i < 0

    update_search
    return if !@search_indexes.any?
    
    # TODO: hack 
    2.times {
      if @cur_search_i - 1 < 0
        @cur_search_i = @search_indexes.size - 1
      else
        @cur_search_i = @cur_search_i - 1
      end
      break if @buffer.pos != @search_indexes[@cur_search_i]
    }
    @buffer.set_pos(@search_indexes[@cur_search_i])
  end
end


