# Interface for ack! https://beyondgrep.com/

class FileContentSearch
  def self.start_gui()
    search_paths = vma.get_content_search_paths.join("<br/>")

    nfo = "<html><h2>Search contents of text files</h2>
  <div style='width:300px'>
  <p>Hint: add empty file named .vma_project to dirs you want to search.</p>\n<p>If .vma_project exists in parent dir of current file, searches within that dir</p></div></html>"

    nfo = "<span size='x-large'>Search contents of all files using ack</span>
Will search the following directories:
#{search_paths}
  
<span>Hint: add empty file named .vma_project to directories you want to search in. 
 If .vma_project exists in parent directory of current file, searches within that directory.
  </span>"

    callback = proc { |x| FileContentSearch.search_buffer(x) }
    gui_one_input_action(nfo, "Search:", "search", callback)
  end

  def self.search_buffer(instr, b = nil)
    # instr = Shellwords.escape(instr)
    fext = Set[".txt"]
    dlist = []
    for d in vma.get_content_search_paths
      dlist = dlist + Dir.glob("#{d}/**/*").select { |e| File.file?(e) and fext.include?(File.extname(e)) and File.size(e) < 200e3 }
    end
    bufstr = "Results:\n\n"
    for fp in dlist
      txt = read_file("",fp)
      ind = scan_indexes(txt, /#{instr}/i)
      if !ind.empty?
        for x in ind
        # Ripl.start :binding => binding

          starti = x - 30
          endi = x + 30
          starti = 0 if starti < 0
          endi = txt.size - 1 if endi >= txt.size
          bufstr << "#{fp}:c#{x} "
          bufstr << txt[starti..endi].gsub("\n"," ")
          bufstr << "\n"
        end
      end
    end
    create_new_file(nil, bufstr)
  end
end

def gui_ack()
  search_paths = vma.get_content_search_paths.join("<br/>")

  nfo = "<html><h2>Search contents of all files using ack</h2>
  <div style='width:300px'>
  <p>Hint: add empty file named .vma_project to dirs you want to search.</p>\n<p>If .vma_project exists in parent dir of current file, searches within that dir</p></div></html>"

  nfo = "<span size='x-large'>Search contents of all files using ack</span>
Will search the following directories:
#{search_paths}
  
<span>Hint: add empty file named .vma_project to directories you want to search in. 
 If .vma_project exists in parent directory of current file, searches within that directory.
  </span>"

  callback = proc { |x| ack_buffer(x) }
  gui_one_input_action(nfo, "Search:", "search", callback)
end

def ack_buffer(instr, b = nil)
  instr = Shellwords.escape(instr)
  bufstr = ""
  for path in vma.get_content_search_paths
    bufstr += run_cmd("ack -Q --type-add=gd=.gd -k --nohtml --nojs --nojson '#{instr}' #{path}")
  end
  if bufstr.size > 5
    create_new_file(nil, bufstr)
  else
    message("No results for input:#{instr}")
  end
end

def gui_ack()
  search_paths = vma.get_content_search_paths.join("<br/>")

  nfo = "<html><h2>Search contents of all files using ack</h2>
  <div style='width:300px'>
  <p>Hint: add empty file named .vma_project to dirs you want to search.</p>\n<p>If .vma_project exists in parent dir of current file, searches within that dir</p></div></html>"

  nfo = "<span size='x-large'>Search contents of all files using ack</span>
Will search the following directories:
#{search_paths}
  
<span>Hint: add empty file named .vma_project to directories you want to search in. 
 If .vma_project exists in parent directory of current file, searches within that directory.
  </span>"

  callback = proc { |x| ack_buffer(x) }
  gui_one_input_action(nfo, "Search:", "search", callback)
end

def ack_buffer(instr, b = nil)
  instr = Shellwords.escape(instr)
  bufstr = ""
  for path in vma.get_content_search_paths
    bufstr += run_cmd("ack -Q --type-add=gd=.gd -ki --nohtml --nojs --nojson #{instr} #{path}")
  end
  if bufstr.size > 5
    create_new_file(nil, bufstr)
  else
    message("No results for input:#{instr}")
  end
end
