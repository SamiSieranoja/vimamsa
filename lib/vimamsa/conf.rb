
# Set conf value by:
#   cnf.foo.bar.baz = 3

# Get conf value by:
# cnf.foo.bar.baz?
# cnf.foo.bar.baz!
# get(cnf.foo.bar.baz)
# (All ways get the same result)

$confh = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
# set cnf.foo.bar.baz, 3
# => $confh = {:foo=>{:bar=>{:baz=>3}}}
def set(_id, val)
  a = $confh
  id = _id.to_a.dup
  last = id.pop
  for x in id
    a = a[x]
  end
  a[last] = val
end

def get(id)
  id = id.to_a
  a = $confh
  for x in id
    return nil if a[x].nil?
    return nil if a.empty?
    a = a[x]
  end
  return a
end

class ConfId
  def initialize(first)
    @id = [first]
  end

  def method_missing(method_name, *args)
    # pp "asize:#{args.size}"
    if m = method_name.match(/(.*)=$/)
      @id << m[1].to_sym
      # pp [@id, args[0]]
      set(self, args[0])
      return args[0]
    elsif m = method_name.match(/(.*)[\!\?]$/)
      @id << m[1].to_sym
      r = get(self)

      if r.class == Hash and r.empty?
        # The accessed key was not defined
        return nil
      else
        return r
      end
    else
      @id << method_name
    end

    return self
  end

  def to_s
    @id.join(".")
  end

  def to_a
    return @id
  end
end

class Conf
  attr_reader :confh

  def initialize()
    @id = []
    @confh = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
  end

  def method_missing(method_name, *args)
    c = ConfId.new(method_name)

    #TODO: improve
    if m = method_name.match(/(.*)[\!\?]$/)
      c = ConfId.new(m[1])
      return get(c)
    end

    if m = method_name.match(/(.*)=$/)
      c = ConfId.new(m[1])
      set(c, args[0])
      return args[0]
    end

    return c
  end
end

$vimamsa_conf = Conf.new

def cnf()
  return $vimamsa_conf
end

cnf.indent_based_on_last_line = true
cnf.extensions_to_open = [".txt", ".h", ".c", ".cpp", ".hpp", ".rb", ".inc", ".php", ".sh", ".m", ".gd", ".js", ".py"]
cnf.default_search_extensions = ["txt", "rb"]

cnf.log.verbose = 1
cnf.lsp.enabled = false
cnf.fexp.experimental = false
cnf.experimental = false

cnf.kbd.show_prev_action = true

cnf.tab.width = 2
cnf.tab.to_spaces_default = false
cnf.tab.to_spaces_languages = ["c", "java", "ruby", "hyperplaintext", "php"]
cnf.tab.to_spaces_not_languages = ["makefile"]
cnf.workspace_folders = []

cnf.match.highlight.color = "#10bd8e"

cnf.lsp.enabled = false

cnf.font.size = 11
cnf.font.family = "Monospace"

cnf.startup_file=false

cnf.macro.animation_delay = 0.02


