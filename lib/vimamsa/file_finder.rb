require "parallel"
class FileFinder
  def initialize()
    $hook.register(:shutdown, self.method("save"))
    $dir_list = vma.marshal_load("file_index")
  end

  def save()
    vma.marshal_save("file_index", $dir_list)
  end

  def start_gui()
    if $search_dirs.empty?
      message("FileFinder: No $search_dirs defined")
      return
    end
    l = []
    $select_keys = ["h", "l", "f", "d", "s", "a", "g", "z"]
    if $dir_list == nil
      Thread.new { recursively_find_files() }
    end

    gui_select_update_window(l, $select_keys.collect { |x| x.upcase },
                            "gui_file_finder_select_callback",
                            "gui_file_finder_update_callback")
  end
end

def update_file_index()
  message("Start updating file index")
  Thread.new {
    recursively_find_files()
    message("Finnish updating file index")
  }
end

def recursively_find_files()
  debug("START find files")
  dlist = []

  for d in $search_dirs
    debug("FIND FILEs IN #{d}")
    dlist = dlist + Dir.glob("#{d}/**/*").select { |e| File.file?(e) and $find_extensions.include?(File.extname(e)) }
    debug("FIND FILEs IN #{d} END")
  end
  #$dir_list = Dir.glob('./**/*').select { |e| File.file? e }
  debug("END find files2")
  $dir_list = dlist
  debug("END find files")
  return $dir_list
end

def filter_files(search_str)
  dir_hash = {}
  scores = Parallel.map($dir_list, in_threads: 8) do |file|
    [file, srn_dst(search_str, file)]
  end
  for s in scores
    dir_hash[s[0]] = s[1] if s[1] > 0
  end
  # puts scores
  dir_hash = dir_hash.sort_by { |k, v| -v }
  dir_hash = dir_hash[0..20]
  dir_hash.map do |file, d|
    puts "D:#{d} #{file}"
  end
  return dir_hash
end

def gui_file_finder_update_callback(search_str = "")
  puts "FILE FINDER UPDATE CALLBACK: #{search_str}"
  if (search_str.size > 1)
    files = filter_files(search_str)
    $file_search_list = files
    return files
    #puts files.inspect
    #return files.values
  end
  return []
end

def gui_file_finder_select_callback(search_str, idx)
  selected_file = $file_search_list[idx][0]
  debug "FILE FINDER SELECT CALLBACK: s=#{search_str},i=#{idx}: #{selected_file}"
  gui_select_window_close(0)
  open_new_file(selected_file)
end

def gui_file_finder_handle_char(c)
  puts "BUFFER SELECTOR INPUT CHAR: #{c}"
  buffer_i = $select_keys.index(c)
  if buffer_i != nil
    gui_file_finder_callback(buffer_i)
  end
end

# TODO: delete?
def gui_file_finder_init()
  $kbd.add_mode("Z", :filefinder)
  bindkey "Z enter", "$kbd.set_mode(:command)"
  bindkey "Z return", "$kbd.set_mode(:command)"
end
