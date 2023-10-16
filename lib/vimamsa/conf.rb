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
conf(:custom_lsp)[:ruby] = {name: "solargraph", command:"solargraph stdio", type: "stdio"}
conf(:custom_lsp)[:cpp] = {name: "clangd", command:"clangd-12 --offset-encoding=utf-8", type: "stdio"}
conf(:custom_lsp)[:python] = {name: "pyright", command:"pyright-langserver --stdio --verbose", type: "stdio"}

setcnf :indent_based_on_last_line, true
setcnf :extensions_to_open, [".txt", ".h", ".c", ".cpp", ".hpp", ".rb", ".inc", ".php", ".sh", ".m", ".gd", ".js", ".py"]
setcnf :default_search_extensions, ["txt", "rb"]


setcnf "log.verbose", 1
setcnf :tab_width, 4
setcnf :enable_lsp, false

setcnf :workspace_folders, []

