# Interface for ack! https://beyondgrep.com/

def gui_ack()
  nfo = "<html><h2>Search contents of all files using ack</h2>
  <div style='width:300px'>
  <p>Hint: add empty file named .vma_project to dirs you want to search.</p>\n<p>If .vma_project exists in parent dir of current file, searches within that dir</p></div></html>"
  callback = proc{|x| ack_buffer(x)}
  gui_one_input_action(nfo, "Search:", "search", callback)
end

def invoke_ack_search()
  start_minibuffer_cmd("", "", :ack_buffer)
end

def ack_buffer(instr, b = nil)
  instr = instr.gsub("'", ".") # TODO
  bufstr = ""
  for path in $vma.get_content_search_paths
    bufstr += run_cmd("ack -Q --type-add=gd=.gd -k --nohtml --nojs --nojson '#{instr}' #{path}")
  end
  if bufstr.size > 5
    create_new_file(nil, bufstr)
  else
    message("No results for input:#{instr}")
  end
end

