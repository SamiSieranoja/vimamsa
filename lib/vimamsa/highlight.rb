def toggle_highlight
  $cnf[:syntax_highlight] = !$cnf[:syntax_highlight]
end

class Processor
  attr_reader :highlights

  def start_parsing(name)
    puts "start_parsing"
    @marks = []
    @lineno = -1
    @tags = {}

    @hltags = {}
    @hltags["storage.type.c"] = 3
    @hltags["string.quoted.double.c"] = 2
    @hltags["constant.other.placeholder.c"] = 1
    @hltags["constant.numeric.c"] = 2
    #        @hltags["support.function.C99.c"] = 4
    @hltags["keyword.operator.sizeof.c"] = 4
    @hltags["keyword.control.c"] = 4

    $highlight = {}
    @highlights = {}
  end

  def end_parsing(name)
    #        Ripl.start :binding => binding
    #        puts "end_parsing"
  end

  def new_line(line)
    #        puts "new_line:#{@lineno} #{line}"
    @lineno += 1
  end

  def open_tag(name, pos)
    format = get_format(name)
    #        puts "open_tag:#{name} pos:#{pos}"
    #        if name == "string.quoted.double.c"
    if format
      @tags[name] = [@lineno, pos]
    end
  end

  def close_tag(name, mark)
    #        puts "close_tag:#{name} mark:#{mark}"
    format = get_format(name)
    if format
      if @tags[name] and @tags[name][0] == @lineno
        startpos = @tags[name][1]
        endpos = mark
        @highlights[@lineno] = [] if @highlights[@lineno] == nil
        @highlights[@lineno] << [startpos, endpos, format]
        @highlights[@lineno].sort!
      end
    end
  end
end


