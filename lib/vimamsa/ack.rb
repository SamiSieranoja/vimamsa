# Interface for ack! https://beyondgrep.com/

class FileContentSearch
  def self.start_gui()
    search_paths = vma.get_content_search_paths.join("<br/>")

    nfo = "<span size='x-large'>Search contents of text files</span>
Will search all .txt files in the following directories:
#{search_paths}
  
<span>Hint: add empty file named .vma_project to directories you want to search in. 
 If .vma_project exists in parent directory of current file, searches within that directory.
  </span>"

    callback = proc { |x| FileContentSearch.search_buffer(x) }

    params = {}
    params["inputs"] = {}
    params["inputs"]["search"] = { :label => "Search:", :type => :entry }
    params["inputs"]["extensions"] = { :label => "Limit to file extensions:", :type => :entry }
    params["inputs"]["extensions"][:initial_text] = cnf.default_search_extensions!.join(",")
    params["inputs"]["btn1"] = { :label => "Search", :type => :button }

    params[:callback] = callback
    PopupFormGenerator.new(params).run
  end

  def self.search_buffer(formdata, b = nil)
    # instr = Shellwords.escape(instr)

    fext = Set[".txt"]
    # Include only word characters and dot
    extstmp = formdata["extensions"].split(",").collect { |x| "." + x.gsub(/[^\w\.]/, "") }
    fext = extstmp.to_set
    if fext.empty?
      return
    end
    instr = formdata["search"]

    dlist = []
    for d in vma.get_content_search_paths
      # Search for files with extension .txt and size < 200k
      dlist = dlist + Dir.glob("#{d}/**/*").select { |e| File.file?(e) and fext.include?(File.extname(e)) and File.size(e) < 200e3 }
    end
    bufstr = "Results:\n\n"
    b = create_new_buffer(bufstr, "contentsearch")
    lno = 1
    @linep = {}
    for fp in dlist
      txt = read_file("", fp)
      ind = scan_indexes(txt, /#{instr}/i)
      if !ind.empty?
        # bufstr << "#{fp}\n"
        # buf.insert_txt("#{fp}\n", AFTER)
        b.append("#{fp}\n")
        lno += 1

        for x in ind
          starti = x - 30
          endi = x + 30
          starti = 0 if starti < 0
          endi = txt.size - 1 if endi >= txt.size
          b.append "  "
          b.append txt[starti..endi].gsub("\n", " ")
          b.append "\n"
          @linep[lno] = { :fname => fp, :ind => x }
          lno += 1
        end
      end
    end

    b.line_action_handler = proc { |lineno|
      puts "SEARCH HANDLER:#{lineno}"
      puts @linep[lineno]
      lp = @linep[lineno]
      if !lp.nil?
        if lp.has_key?(:ind) and lp.has_key?(:fname)
          jump_to_file(lp[:fname], lp[:ind], "c")
        end
      end

      # if jumpto.class == Integer
      # vma.buffers.set_current_buffer($grep_bufid, update_history = true)
      # buf.jump_to_line(jumpto)
      # end
    }
    # buf.insert_txt("\n")
    # create_new_file(nil, bufstr)
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

  callback = proc { |x| Ack.new.ack_buffer(x) }
  gui_one_input_action(nfo, "Search:", "search", callback)
end

def group_by_folder(list)
  bh = {}
  for b in list
    fpath = b[:fpath]
    if !fpath.nil?
      bname = File.basename(b[:fpath])
      dname = File.dirname(b[:fpath])
    else
      #TODO
    end
    bh[dname] ||= {}
    bh[dname][:files] ||= []
    bh[dname][:files] << { bname: bname, nfo: b }
  end
  arr = []

  for k in bh.keys.sort
    tp = tilde_path(k)
    arr << { type: :dir, path: tp }
    for f in bh[k][:files].sort_by { |x| x[:bname] }
      arr << { type: :file, bname: f[:bname], nfo: f[:nfo] }
    end
  end
  return arr
end

class Ack
  attr_reader :buf
  @@cur = nil # Current object of class

  def self.cur()
    return @@cur
  end

  def self.init()
  end

  def initialize()
    @buf = nil
    @line_to_id = {}
  end

  def ack_buffer(_instr, b = nil)
    instr = Shellwords.escape(_instr)
    bufstr = ""
    for path in vma.get_content_search_paths
      bufstr += run_cmd("ack -Q --type-add=gd=.gd -ki --nohtml --nojs --nojson #{instr} #{path}")
    end

    b = ""
    list = []
    for x in bufstr.lines
      if x.match(/(.*?):(\d+):(.+)/) # non greedy: *?
        fn = $1
        lineno = $2
        matchpart = $3
        pp [fn, lineno, matchpart]
        b << "[#{fn},#{lineno},#{matchpart}]\n"
        list << { fpath: fn, lineno: lineno, matchpart: matchpart }
      end
    end

    gb = group_by_folder(list)
    s = ""
    @line_to_nfo = {}
    i = 0
    for x in gb
      if x[:type] == :file
        s << "╰─#{x[:bname]}:#{x[:nfo][:lineno]}:#{x[:nfo][:matchpart]}\n"
        @line_to_nfo[i] = x
      end
      if x[:type] == :dir
        s << "📂#{x[:path]}:\n"
      end
      i += 1
    end

    if s.size > 5
      @buf = create_new_buffer(s, "ack")
      @buf.module = self
      @buf.line_action_handler = self.method("select_line")
      Gui.highlight_match(@buf, _instr, color: cnf.match.highlight.color!)
    else
      message("No results for input:#{instr}")
    end
  end

  def select_line(lineno)
    debug "def select_line #{lineno}", 2
    nfo = @line_to_nfo[lineno][:nfo]
    jump_to_file(nfo[:fpath], nfo[:lineno].to_i)
  end
end
