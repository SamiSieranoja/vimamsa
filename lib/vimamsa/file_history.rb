# History of previously opened files

class FileHistory
  attr_accessor :history

  def initialize()
    # puts self.method("update")
    # x = self.method("update")
    # x.call("ASFASF")

    $hook.register(:change_buffer, self.method("update"))
    $hook.register(:shutdown, self.method("save"))

    reg_act(:fhist_remove_nonexisting, proc { remove_nonexisting }, "Cleanup history, remove non-existing files")

    @history = vma.marshal_load("file_history", {})
    $search_list = []
  end

  # def self.init()
  # end

  def update(buf)
    puts "FileHistory.update(buf=#{buf.fname})"
    return if !buf.fname
    @history[buf.fname] if !@history[buf.fname]
    if !@history[buf.fname]
      @history[buf.fname] = 1
    else
      @history[buf.fname] += 1
    end
    puts @history

    # puts "FileHistory.update(buf=#{buf})"
  end

  def save()
    vma.marshal_save("file_history", @history)
  end

  def remove_nonexisting()
    size_orig = @history.size
    for k, v in @history
      if !File.exist?(k)
        @history.delete(k)
        log_message("Delete #{k} from history")
      end
    end
    size_new = @history.size
    message("History size #{size_orig} => #{size_new}")
  end

  def start_gui()
    return if $vma.fh.history.empty?
    l = []
    $select_keys = ["h", "l", "f", "d", "s", "a", "g", "z"]

    gui_select_update_window(l, $select_keys.collect { |x| x.upcase },
                            "gui_file_history_select_callback",
                            "gui_file_history_update_callback")
  end
end

def fuzzy_filter(search_str, list, maxfinds)
  h = {}
  scores = Parallel.map(list, in_threads: 8) do |l|
    [l, srn_dst(search_str, l)]
  end
  for s in scores
    h[s[0]] = s[1] if s[1] > 0
  end
  h = h.sort_by { |k, v| -v }
  h = h[0..maxfinds]
  # h.map do |i, d|
  # puts "D:#{d} #{i}"
  # end
  return h
end

def gui_file_history_update_callback(search_str = "")
  puts "gui_file_history_update_callback: #{search_str}"
  return [] if $vma.fh.history.empty?
  $search_list = []
  files = $vma.fh.history.keys.sort.collect { |x| [x, 0] }

  if (search_str.size > 1)
    files = fuzzy_filter(search_str, $vma.fh.history.keys, 40)
  end
  $search_list = files
  return files
end

def gui_file_history_select_callback(search_str, idx)
  # selected_file = $file_search_list[idx][0]
  selected_file = $search_list[idx][0]

  debug "FILE HISTORY SELECT CALLBACK: s=#{search_str},i=#{idx}: #{selected_file}"
  gui_select_window_close(0)
  open_new_file(selected_file)
end
