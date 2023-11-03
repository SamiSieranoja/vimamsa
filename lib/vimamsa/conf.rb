$cnf = {} # TODO

def conf(id)
  return $cnf[id]
end

def set_conf(id, val)
  $cnf[id] = val
end

def setcnf(id, val)
  set_conf(id, val)
end

setcnf :custom_lsp, {}
# conf(:custom_lsp)[:ruby] = {name: "solargraph", command:"solargraph stdio", type: "stdio"}
# conf(:custom_lsp)[:cpp] = {name: "clangd", command:"clangd-12 --offset-encoding=utf-8", type: "stdio"}
# conf(:custom_lsp)[:python] = {name: "pyright", command:"pyright-langserver --stdio --verbose", type: "stdio"}

setcnf :indent_based_on_last_line, true
setcnf :extensions_to_open, [".txt", ".h", ".c", ".cpp", ".hpp", ".rb", ".inc", ".php", ".sh", ".m", ".gd", ".js", ".py"]
setcnf :default_search_extensions, ["txt", "rb"]

setcnf "log.verbose", 1
setcnf :enable_lsp, false

setcnf :tab_width, 2
setcnf :tab_to_spaces_default, false
setcnf :tab_to_spaces_languages, ["c", "java", "ruby", "hyperplaintext", "php"]
setcnf :tab_to_spaces_not_languages, ["makefile"]

setcnf :workspace_folders, []

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
      return get(self)
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
    return c
  end
end

# New way to configure:

#To set conf value:
# cnf.foo.bar.baz = 3

#To get conf value:
# cnf.foo.bar.baz?
# cnf.foo.bar.baz!
# get(cnf.foo.bar.baz)

$confh = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
# set cnf.foo.bar.baz, 3
# => $confh = {:foo=>{:bar=>{:baz=>3}}}
def set(_id, val)
  a = $confh
  id = _id.to_a
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

$vimamsa_conf = Conf.new

def cnf()
  return $vimamsa_conf
end

# cnf.foo.bar.baz = 3
# pp $confh
# pp cnf.foo.bar.baz!
# pp cnf.foo.bar.baz?
# pp get(cnf.foo.bar.baz)

cnf.indent_based_on_last_line = true
cnf.extensions_to_open = [".txt", ".h", ".c", ".cpp", ".hpp", ".rb", ".inc", ".php", ".sh", ".m", ".gd", ".js", ".py"]
cnf.default_search_extensions = ["txt", "rb"]

cnf.log.verbose = 1
cnf.lsp.enabled = false
cnf.fexp.experimental = false

cnf.tab.width = 2
cnf.tab.to_spaces_default = false
cnf.tab.to_spaces_languages = ["c", "java", "ruby", "hyperplaintext", "php"]
cnf.tab.to_spaces_not_languages = ["makefile"]
cnf.workspace_folders = []

cnf.match.highlight.color = "#10bd8e"


pp $confh
# Ripl.start :binding => binding


