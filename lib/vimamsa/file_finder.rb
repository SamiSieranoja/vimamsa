require "parallel"
require "stridx"

# Limit file search to these extensions:
cnf.find_extensions = [".txt", ".h", ".c", ".cpp", ".hpp", ".rb", ".java", ".js", ".py"]
cnf.search_dirs = []

class StringIndex
  def initialize()
    @idx = StrIdx::StringIndex.new
    @idx.setDirSeparator("/")
  end

  def find(str, minChars: 2)
    minChars = 3 if minChars.class != Integer
    minChars = 2 if minChars < 2
    minChars = 6 if minChars > 6 #TODO: implement option in C++

    @idx.find(str)
  end

  def add(str, id)
    @idx.add(str, id)
  end
end

# ruby -e "$:.unshift File.dirname(__FILE__); require 'stridx'; idx = CppStringIndex.new(2); idx.add('foobar00',3); idx.add('fo0br',5); pp idx.find('foo');"

class FileFinder
  @@idx_updating = true
  @@dir_list = []

  def self.update_index()
    message("Start updating file index")
    Thread.new {
      recursively_find_files()
    }
  end

  def initialize()
    vma.hook.register(:shutdown, self.method("save"))
    @@dir_list = vma.marshal_load("file_index")
    @@dir_list ||= []
    update_search_idx
  end

  def self.update_search_idx
    Thread.new {
      sleep 0.1
      @@idx = StringIndex.new
      @@idx_updating = true

      aa = []; @@dir_list.each_with_index { |x, i| aa << [x, i] }

      # Parallel.map(aa, in_threads: 8) do |(x, i)|
      # @@idx.add(x, i)
      # end

      i = 0
      for x in @@dir_list
        i += 1
        # str_idx_addToIndex(x, i)
        @@idx.add(x, i)
      end
      @@idx_updating = false
      message("Finish updating file index")
    }
  end

  def updating?
    @@idx_updating
  end

  def update_search_idx
    FileFinder.update_search_idx
  end

  def save()
    debug "SAVE FILE INDEX", 2
    vma.marshal_save("file_index", @@dir_list)
  end

  def start_gui()
    if cnf.search_dirs!.empty?
      message("FileFinder: No cnf.search_dirs defined")
      return
    end
    l = []
    $select_keys = ["h", "l", "f", "d", "s", "a", "g", "z"]
    if @@dir_list == nil
      Thread.new { FileFinder.recursively_find_files() }
    end

    # select_callback = proc { |search_str, idx| gui_file_finder_select_callback(search_str, idx) }
    select_callback = self.method("gui_file_finder_select_callback")
    update_callback = self.method("gui_file_finder_update_callback")


    opt = { :title => "Fuzzy filename search",
            :desc => "Search for files in folders defined in cnf.search_dirs" ,
            :columns => [{:title=>'Filename',:id=>0}]
            }
                             
    gui_select_update_window(l, $select_keys.collect { |x| x.upcase },
                             select_callback,
                             update_callback, opt)
  end

  def gui_file_finder_update_callback(search_str = "")
    debug "FILE FINDER UPDATE CALLBACK: #{search_str}"
    if (search_str.size >= 3)
      files = filter_files(search_str)
      @file_search_list = files
      if files.size > 1
        files = files.collect{|x|[tilde_path(x[0])]}
      end

      return files
      #return files.values
    end
    return []
  end

  def gui_file_finder_select_callback(search_str, idx)
    selected_file = @file_search_list[idx][0]
    debug "FILE FINDER SELECT CALLBACK: s=#{search_str},i=#{idx}: #{selected_file}"
    gui_select_window_close(0)
    open_new_file(selected_file)
  end

  def self.recursively_find_files()
    debug("START find files")
    dlist = []

    for d in cnf.search_dirs!
      debug("FIND FILEs IN #{d}")
      dlist = dlist + Dir.glob("#{d}/**/*").select { |e| File.file?(e) and cnf.find_extensions!.include?(File.extname(e)) }
      debug("FIND FILEs IN #{d} END")
    end
    @@dir_list = dlist
    update_search_idx
    debug("END find files")
    return @@dir_list
  end

  def filter_files(search_str)
    puts "search list: #{@@dir_list.size}"
    dir_hash = {}

    res = @@idx.find(search_str)
    resultarr = []
    for (idx, score) in res
      fn = @@dir_list[idx - 1]
      puts "#{idx} #{score} #{fn}"
      resultarr << [fn, score]
    end
    return resultarr

    # Ripl.start :binding => binding

    scores = Parallel.map(@@dir_list, in_threads: 8) do |file|
      [file, srn_dst(search_str, file)]
    end
    for s in scores
      dir_hash[s[0]] = s[1] if s[1] > 0
    end
    # debug scores
    dir_hash = dir_hash.sort_by { |k, v| -v }
    dir_hash = dir_hash[0..20]
    dir_hash.map do |file, d|
      debug "D:#{d} #{file}"
    end
    return dir_hash
  end
end
