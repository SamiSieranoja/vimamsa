def gui_find_macro_update_callback(search_str = "")
  debug "gui_find_macro_update_callback: #{search_str}"
  heystack = $macro.named_macros
  return [] if heystack.empty?
  $macro_search_list = []
  files = heystack.keys.sort.collect { |x| [x, 0] }

  if (search_str.size > 1)
    files = fuzzy_filter(search_str, heystack.keys, 40)
  end
  $macro_search_list = files
  return files
end

def gui_find_macro_select_callback(search_str, idx)
  debug "gui_find_macro_select_callback"
  selected = $macro_search_list[idx]
  m = $macro.named_macros[selected[0]].clone
  debug "SELECTED MACRO:#{selected}, #{m}"
  id = $macro.last_macro
  $macro.recorded_macros[id] = m
  $macro.run_macro(id)
end

class Macro
  attr_reader :running_macro
  attr_accessor :recorded_macros, :recording, :named_macros, :last_macro

  def initialize()
    @recording = false
    # @recorded_macros = {}
    @current_recording = []
    @current_name = nil
    @last_macro = "a"
    @running_macro = false

    #TODO:
    @recorded_macros = vma.marshal_load("macros", {})
    @named_macros = vma.marshal_load("named_macros", {})
    vma.hook.register(:shutdown, self.method("save"))
  end

  def save()
    vma.marshal_save("macros", @recorded_macros)
    vma.marshal_save("named_macros", @named_macros)
  end

  def gui_name_macro()
    callback = self.method("name_macro")
    # gui_one_input_action("Grep", "Search:", "grep", "grep_cur_buffer")
    gui_one_input_action("Name last macro", "Name:", "Set", callback)
  end

  def find_macro_gui()
    l = $macro.named_macros.keys.sort.collect { |x| [x, 0] }
    $macro_search_list = l
    $select_keys = ["h", "l", "f", "d", "s", "a", "g", "z"]

    gui_select_update_window(l, $select_keys.collect { |x| x.upcase },
                             "gui_find_macro_select_callback",
                             "gui_find_macro_update_callback")
  end

  def name_macro(name, id = nil)
    debug "NAME MACRO #{name}"
    if id.nil?
      id = @last_macro
    end
    @named_macros[name] = @recorded_macros[id].clone
  end

  def start_recording(name)
    @recording = true
    @current_name = name
    @current_recording = []
    message("Start recording macro [#{name}]")

    # Returning false prevents from putting start_recording to start of macro
    return false
  end

  def end_recording()
    if @recording == true
      @recorded_macros[@current_name] = @current_recording
      @last_macro = @current_name
      @current_name = @current_recording = nil
      @recording = false
      message("Stop recording macro [#{@last_macro}]")
    else
      message("Not recording macro")
    end
  end

  def is_recording
    return @recording
  end

  def record_action(eval_str)
    if @recording
      if eval_str == "repeat_last_action"
        @current_recording << $command_history.last
      else
        @current_recording << eval_str
      end
    end
  end

  # Allow method to specify the macro action instead of recording from keyboard input
  def overwrite_current_action(eval_str)
    if @recording
      @current_recording[-1] = eval_str
    end
  end

  def run_last_macro
    run_macro(@last_macro)
  end

  # Run the provided list of actions
  def run_actions(acts)
    isok = true
    if acts.kind_of?(Array) and acts.any?
      @running_macro = true
      # TODO:needed?
      # set_last_command({ method: $macro.method("run_macro"), params: [name] })
      for a in acts
        ret = exec_action(a)
        if ret == false
          error "Error while running macro"
          isok=false
          break
        end
      end
    end
    @running_macro = false
    buf.set_pos(buf.pos)
    return isok
  end

  def run_macro(name)
    if $macro.is_recording == true
      message("Can't run a macro that runs a macro (recursion risk)")
      return false
    end
    message("Start running macro [#{name}]")
    if @recorded_macros.has_key?(name)
      @last_macro = name
    end
    acts = @recorded_macros[name]
    return run_acts(acts)
  end

  def dump_last_macro()
    puts "======MACRO START======="
    puts @recorded_macros[@last_macro].inspect
    puts "======MACRO END========="
  end

  def save_macro(name)
    m = @recorded_macros[name]
    return if !(m.kind_of?(Array) and m.any?)
    contents = m.join(";")
    dot_dir = File.expand_path("~/.vimamsa")
    Dir.mkdir(dot_dir) unless File.exist?(dot_dir)
    save_fn = "#{dot_dir}/macro_#{name}.rb"

    Thread.new {
      File.open(save_fn, "w+") do |io|
        #io.set_encoding(self.encoding)

        begin
          io.write(contents)
        rescue Encoding::UndefinedConversionError => ex
          # this might happen when trying to save UTF-8 as US-ASCII
          # so just warn, try to save as UTF-8 instead.
          warn("Saving as UTF-8 because of: #{ex.class}: #{ex}")
          io.rewind

          io.set_encoding(Encoding::UTF_8)
          io.write(contents)
        end
      end
      sleep 3 #TODO:remove
    }
  end
end
