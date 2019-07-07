
load "vendor/ver/lib/ver/theme.rb"

def toggle_highlight
  $cnf[:syntax_highlight] = !$cnf[:syntax_highlight]
end

$theme_list = Dir.glob("vendor/ver/themes/*.rb")
$cur_theme = 0

def build_options()
  $theme_list = Dir.glob("vendor/ver/themes/*.rb")
  theme_names = $theme_list.collect { |x| File.basename(x, ".rb") }
  $opt = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

  $opt["theme"]["type"] = "list"
  $opt["theme"]["selected"] = $cur_theme
  $opt["theme"]["conf_key"] = :theme
  $opt["theme"]["items"] = theme_names
  for o in $opt.keys
    if $opt[o].has_key?("conf_key")
      k = $opt[o]["conf_key"]
      if $cnf.has_key?(k)
        default = $cnf[k]
        ind = $opt["theme"]["items"].find_index(default)
        if ind != nil
          $opt[o]["selected"] = ind
        end
      end
    end
  end
  puts $opt.inspect
end

def handle_conf_change()
  if $opt["theme"]["selected"]
    i = $opt["theme"]["selected"]
    t = $opt["theme"]["items"][i]
    k = $opt["theme"]["conf_key"]
    $cnf[k] = t
    load_theme(t)
  end
  c = $cnf.clone
  IO.write(get_dot_path("settings.rb"), $cnf.inspect)
end

def load_theme(name = nil)
  $cur_theme += 1
  $cur_theme = 0 if $cur_theme >= $theme_list.size
  $cur_theme = name if name.class == Integer
  theme_path = $theme_list[$cur_theme]
  theme_path = "vendor/ver/themes/#{name}.rb" if name != nil and name.class == String
  message "load theme #{theme_path}"

  qt_load_theme($theme)
  $theme = Theme.load(theme_path)
  # qt_load_theme($theme)
  # sty = [$theme.default[:background]]
  # qt_add_font_style(sty)

  bgcolor = $theme.default[:background]
  fgcolor = $theme.default[:foreground]
  puts "QTextEdit {color: #{fgcolor}; background-color: #{bgcolor}; }"
  qt_set_stylesheet("QTextEdit {color: #{fgcolor}; background-color: #{bgcolor}; }")
  # qt_set_stylesheet("QTextEdit {color: ##{}00ff22; background-color: #003311; }")

  # $theme.default
  # >> $theme.default[:background] $theme.default[:lineHighlight]
end

def get_format(name)
  thm = $theme.get(name)
  format = nil
  if thm
    style = $theme.colors[thm]
    format = style[:qtid]
    # puts "close_tag:#{name} mark:#{mark}, match:#{thm} qtid=#{style[:qtid]} style:#{style}"
  end
  return format
end

class Processor
  attr_reader :highlights

  def start_parsing(name)
    puts "start_parsing"
    @marks = []
    @lineno = -1
    @tags = {}

    #TODO:delete
    # @hltags = {}
    $highlight = {}
    @highlights = {}
  end

  def end_parsing(name)
  end

  def new_line(line)
    #        puts "new_line:#{@lineno} #{line}"
    @lineno += 1
  end

  def open_tag(name, pos)
    format = get_format(name)
    if format
      @tags[name] = [@lineno, pos]
    end
  end

  def close_tag(name, mark)
    # Ripl.start :binding => binding

    thm = $theme.get(name)
    format = nil
    if thm
      style = $theme.colors[thm]
      format = style[:qtid]
      debug("L=#{@lineno} close_tag:#{name} mark:#{mark}, match:#{thm} qtid=#{style[:qtid]} style:#{style}")
    else
      debug("L=#{@lineno} NO THEME FOR close_tag:#{name} mark:#{mark}")
    end

    # format = get_format(name)
    if format != nil
      if @tags[name] and @tags[name][0] == @lineno
        startpos = @tags[name][1]
        endpos = mark - 1
        @highlights[@lineno] = [] if @highlights[@lineno] == nil
        x = [startpos, endpos, format]
        # puts "x:#{x}"
        @highlights[@lineno] << x
        @highlights[@lineno].sort!
      end
    end
  end
end
