require 'pty'

def exec_in_terminal(cmd)
  # puts "CMD:#{cmd}"
  
  # as global to prevent garbage collect unlink
  $initf = Tempfile.new('bashinit')
  # puts $initf.path
  $initf.write(cmd)
  $initf.write("rm #{$initf.path}\n")
  $initf.write("\nexec bash\n")
  $initf.close
  # PTY.spawn("gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash")
  fork{exec "gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash"}
end


def handle_drag_and_drop(fname)
  debug "EDITOR:handle_drag_and_drop"
  buf.handle_drag_and_drop(fname)
end

class Editor
  attr_reader :file_content_search_paths, :file_name_search_paths
  attr_accessor :converters, :fh, :paint_stack
  #attr_writer :call_func, :update_highlight

  def initialize()
    # Thread.new{10000.times{|x|sleep(3);10000.times{|y|y+2};puts "FOOTHREAD #{x}"}}

    # Search for content inside files (e.g. using ack/grep) in:
    @file_content_search_paths = []

    # Search for files based on filenames in:
    @file_name_search_paths = []

    #Regexp gsubs or other small modifiers of text
    @converters = {}
    @paint_stack = []
    @_plugins = {}
  end

  def start
    # $highlight = {}

    $hook = Hook.new
    register_plugin(:Hook, $hook)
    $macro = Macro.new
    register_plugin(:Macro, $macro)
    $search = Search.new
    register_plugin(:Search, $search)

    $buffers = BufferList.new
    $minibuffer = Buffer.new(">", "")

    require "vimamsa/text_transforms"

    debug "ARGV: " + ARGV.inspect
    # build_key_bindings_tree
    $kbd = KeyBindingTree.new()
    $kbd.add_mode("C", :command)
    $kbd.add_mode("I", :insert)
    $kbd.add_mode("V", :visual)
    $kbd.add_mode("M", :minibuffer)
    $kbd.add_mode("R", :readchar)
    $kbd.add_mode("B", :browse)
    $kbd.set_default_mode(:command)
    require "vimamsa/default_bindings"
    sleep(0.03)

    dot_dir = File.expand_path("~/.vimamsa")
    Dir.mkdir(dot_dir) unless File.exist?(dot_dir)

    $cnf[:theme] = "Twilight_edit"
    $cnf[:syntax_highlight] = true
    settings_path = get_dot_path("settings.rb")
    if File.exist?(settings_path)
      $cnf = eval(IO.read(settings_path))
    end

    set_qt_style(1)

    # Limit file search to these extensions:
    $find_extensions = [".txt", ".h", ".c", ".cpp", ".hpp", ".rb"]

    dotfile = read_file("", "~/.vimamsarc")
    eval(dotfile) if dotfile

    build_options

    fname = "test.txt"
    if conf(:startup_file)
      fname_ = File.expand_path(conf(:startup_file))
      if File.exist?(fname_)
        fname = fname_
      end
    end
    fname = ARGV[1] if ARGV.size >= 2 and File.file?(ARGV[1])
    vma.add_content_search_path(Dir.pwd)
    for fn in ARGV
      fn = File.expand_path(fn)
      if File.directory?(fn)
        vma.add_content_search_path(fn)
        $search_dirs << fn
      end
    end

    buffer = Buffer.new(read_file("", fname), fname)
    $buffers << buffer

    load_theme($cnf[:theme])

    render_buffer($buffer, 1)

    gui_select_buffer_init
    gui_file_finder_init

    #Load plugins
    require "vimamsa/file_history.rb"
    @fh = FileHistory.new
    # @_plugins[:FileFinder] = FileFinder.new
    @_plugins[:FileHistory] = @fh

    register_plugin(:FileHistory, @fh)
    register_plugin(:FileFinder, FileFinder.new)
    # To access via vma.FileFinder
    # self.define_singleton_method(:FileFinder) { @_plugins[:FileFinder] }

    $hook.call(:after_init)
  end

  def register_plugin(name, obj)
    @_plugins[name] = obj
    # To access via e.g. vma.FileFinder
    self.define_singleton_method(name) { obj }
  end

  def buf()
    return $buffer
  end

  def marshal_save(varname, vardata)
    save_var_to_file(varname, Marshal.dump(vardata))
  end

  def marshal_load(varname, default_data = nil)
    mdata = load_var_from_file(varname)
    if mdata
      return Marshal.load(mdata)
    else
      return default_data
    end
  end

  def save_var_to_file(varname, vardata)
    fn = get_dot_path(varname)
    f = File.open(fn, "w")
    File.binwrite(f, vardata)
    f.close
  end

  def load_var_from_file(varname)
    fn = get_dot_path(varname)
    if File.exist?(fn)
      vardata = IO.binread(fn)
      if vardata
        debug("Successfully red #{varname} from file #{fn}")
        return vardata
      end
    end
    return nil
  end

  def plug()
    return @_plugins
  end

  def shutdown()
    $hook.call(:shutdown)
    save_state
  end

  def save_state
  end

  def add_content_search_path(pathstr)
    p = File.expand_path(pathstr)
    if !@file_content_search_paths.include?(p)
      @file_content_search_paths << p
    end
  end

  # Register converter
  def reg_conv(converter, converter_id)
    @converters[converter_id] = converter
    reg_act(converter_id, proc { $buffer.convert_selected_text(converter_id) }, "Converter #{converter_id}", [:selection])
    # reg_act(converter_id, "$buffer.convert_selected_text(:#{converter_id})", "Converter #{converter_id}", [:selection])
  end

  def apply_conv(converter_id, txt)
    @converters[converter_id].apply(txt)
  end

  def get_content_search_paths()
    r = @file_content_search_paths.clone
    p = find_project_dir_of_cur_buffer()

    if p and !@file_content_search_paths.include?(p)
      r.insert(0, p)
    end
    return r
  end
  
   def can_open_extension?(filepath)
    exts = $cnf[:extensions_to_open]
    extname = Pathname.new(filepath).extname.downcase
    can_open = exts.include?(extname)
    puts "CAN OPEN?: #{can_open}"
    return can_open
  end
 
  
end


def _quit()
  # Shut down the Qt thread before the ruby thread
  vma.shutdown
  qt_quit
  exit
end

def file_saveas(filename)
  $buffer.set_filename(filename)
  $buffer.save()
end

def open_file_dialog()
  path = ""
  path = $buffer.fname if $buffer.fname
  qt_open_file_dialog(File.dirname(path))
end

def system_clipboard_changed(clipboard_contents)
  max_clipboard_items = 100
  if clipboard_contents != $clipboard[-1]
    #TODO: HACK
    $paste_lines = false
  end
  $clipboard << clipboard_contents
  # puts $clipboard[-1]
  $clipboard = $clipboard[-([$clipboard.size, max_clipboard_items].min)..-1]
end

def set_clipboard(s)
  if !(s.class <= String) or s.size == 0
    puts s.inspect
    puts [s, s.class, s.size]
    log_error("s.class != String or s.size == 0")
    Ripl.start :binding => binding
    return
  end
  $clipboard << s
  set_system_clipboard(s)
  $register[$cur_register] = s
  debug "SET CLIPBOARD: [#{s}]"
  debug "REGISTER: #{$cur_register}:#{$register[$cur_register]}"
end

def set_cursor_pos(new_pos)
  buf.set_pos(new_pos)
  #render_buffer($buffer)
  debug "New pos: #{new_pos}lpos:#{$buffer.lpos} cpos:#{$buffer.cpos}"
end

def set_last_command(cmd)
  $command_history << cmd
end

def can_save_to_directory?(dpath)
  return false if !File.exist?(dpath)
  return false if !File.directory?(dpath)
  return false if !File.writable?(dpath)
  return true
end

def repeat_last_action()
  cmd = $command_history.last
  cmd[:method].call *cmd[:params] if cmd != nil
end

def repeat_last_find()
  return if !defined? $last_find_command
  $buffer.jump_to_next_instance_of_char($last_find_command[:char],
                                        $last_find_command[:direction])
end

def set_next_command_count(num)
  if $next_command_count != nil
    $next_command_count = $next_command_count * 10 + num.to_i
  else
    $next_command_count = num.to_i
  end
  debug("NEXT COMMAND COUNT: #{$next_command_count}")
end

def start_minibuffer_cmd(bufname, bufstr, cmd)
  $kbd.set_mode(:minibuffer)
  $minibuffer = Buffer.new(bufstr, "")
  $minibuffer.call_func = method(cmd)
end

def show_key_bindings()
  kbd_s = "❙Key bindings❙\n"
  kbd_s << "=======================================\n"
  kbd_s << $kbd.to_s
  kbd_s << "\n=======================================\n"
  create_new_file(nil, kbd_s)
end

def diff_buffer()
  bufstr = ""
  orig_path = $buffer.fname
  infile = Tempfile.new("out")
  infile = Tempfile.new("in")
  infile.write($buffer.to_s)
  infile.flush
  cmd = "diff -w '#{orig_path}' #{infile.path}"
  # puts cmd
  bufstr << run_cmd(cmd)
  # puts bufstr
  infile.close; infile.unlink
  create_new_file(nil, bufstr)
end

def invoke_command()
  start_minibuffer_cmd("", "", :execute_command)
end

def execute_command(input_str)
  begin
    out_str = eval(input_str, TOPLEVEL_BINDING) #TODO: Other binding?
    $minibuffer.clear
    $minibuffer << out_str.to_s #TODO: segfaults, why?
  rescue SyntaxError
    debug("SYNTAX ERROR with eval cmd #{action}: " + $!.to_s)
  end
end

def minibuffer_end()
  debug "minibuffer_end"
  $kbd.set_mode(:command)
  minibuffer_input = $minibuffer.to_s[0..-2]
  return $minibuffer.call_func.call(minibuffer_input)
end

def minibuffer_cancel()
  debug "minibuffer_cancel"
  $kbd.set_mode(:command)
  minibuffer_input = $minibuffer.to_s[0..-2]
  # $minibuffer.call_func.call('')
end

def minibuffer_new_char(c)
  if c == "\r"
    raise "Should not come here"
    debug "MINIBUFFER END"
  else
    $minibuffer.insert_txt(c)
    debug "MINIBUFFER: #{c}"
  end
  #$buffer = $minibuffer
end

def readchar_new_char(c)
  $input_char_call_func.call(c)
end

def minibuffer_delete()
  $minibuffer.delete(BACKWARD_CHAR)
end

def message(s)
  s = "[#{DateTime.now().strftime("%H:%M")}] #{s}"
  $minibuffer = Buffer.new(s, "")
end

GUESS_ENCODING_ORDER = [
  Encoding::US_ASCII,
  Encoding::UTF_8,
  Encoding::Shift_JIS,
  Encoding::EUC_JP,
  Encoding::EucJP_ms,
  Encoding::Big5,
  Encoding::UTF_16BE,
  Encoding::UTF_16LE,
  Encoding::UTF_32BE,
  Encoding::UTF_32LE,
  Encoding::CP949,
  Encoding::Emacs_Mule,
  Encoding::EUC_KR,
  Encoding::EUC_TW,
  Encoding::GB18030,
  Encoding::GBK,
  Encoding::Stateless_ISO_2022_JP,
  Encoding::CP51932,
  Encoding::EUC_CN,
  Encoding::GB12345,
  Encoding::Windows_31J,
  Encoding::MacJapanese,
  Encoding::UTF8_MAC,
  Encoding::BINARY,
]

def create_new_file(filename = nil, file_contents = "\n")
  debug "NEW FILE CREATED"
  buffer = Buffer.new(file_contents)
  $buffers << buffer
  return buffer
end

def filter_buffer(buf)
  i = 0
  while i < buf.size
    if buf[i].ord == 160
      buf[i] = " "
      #TODO: hack. fix properly
    end
    i += 1
  end
  return buf
end

def load_buffer(fname)
  return if !File.exist?(fname)
  existing_buffer = $buffers.get_buffer_by_filename(fname)
  if existing_buffer != nil
    $buffer_history << existing_buffer
    return
  end
  debug("LOAD BUFFER: #{fname}")
  buffer = Buffer.new(read_file("", fname), fname)
  qt_set_current_buffer(buffer.id)
  debug("DONE LOAD: #{fname}")
  #buf = filter_buffer(buffer)
  #    debug("END FILTER: #{fname}")
  $buffers << buffer
  #$buffer_history << $buffers.size - 1
end

def jump_to_file(filename, linenum = 0)
  open_new_file(filename)
  if linenum > 0
    $buffer.jump_to_line(linenum)
    center_on_current_line
  end
end

#TODO: needed?
def open_existing_file(filename)
  open_new_file(filename)
end

def open_new_file(filename, file_contents = "")
  #TODO: expand path
  filename = File.expand_path(filename)
  b = $buffers.get_buffer_by_filename(filename)
  # File is already opened to existing buffer
  if b != nil
    message "Switching to: #{filename}"
    $buffers.set_current_buffer(b)
  else
    message "New file opened: #{filename}"
    fname = filename
    load_buffer(fname)
  end
  set_window_title("Vimamsa - #{File.basename(filename)}")
  render_buffer #TODO: needed?
  qt_process_events
end

def scan_word_start_marks(search_str)
  wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}|\Z/) # \Z = end of string, just before last newline.
  wsmarks2 = scan_indexes(search_str, /\n[ \t]*\n/) # "empty" lines that have whitespace
  wsmarks2 = wsmarks2.collect { |x| x + 1 }
  wsmarks = (wsmarks2 + wsmarks).sort.uniq
  return wsmarks
end

def draw_text(str, x, y)
  vma.paint_stack << [4, x, y, str]
end

def get_visible_area()
  return cpp_function_wrapper(2, [])
end

def center_on_current_line()
  center_where_cursor
end

def hook_draw()
  # TODO: as hook.register
  easy_jump_draw()
end

def render_buffer(buffer = 0, reset = 0)
  tmpbuf = $buffer.to_s
  debug "pos:#{$buffer.pos} L:#{$buffer.lpos} C:#{$buffer.cpos}"
  pos = $buffer.pos
  selection_start = $buffer.selection_start

  if $buffer.need_redraw?
    reset = 1
  end
  t1 = Time.now
  hook_draw()

  render_text(tmpbuf, pos, selection_start, reset)

  if $buffer.need_redraw?
    hpt_scan_images() if $debug #experimental
  end

  $buffer.highlight
  if Time.now - t1 > 1 / 100.0
    debug "SLOW render"
    debug "Render time: #{Time.now - t1}"
  end
  $buffer.set_redrawed if reset == 1
end

def get_dot_path(sfx)
  dot_dir = File.expand_path("~/.vimamsa")
  Dir.mkdir(dot_dir) unless File.exist?(dot_dir)
  dpath = "#{dot_dir}/#{sfx}"
  return dpath
end

def get_file_line_pointer(s)
  #"/code/vimamsa/lib/vimamsa/buffer_select.rb:31:def"
  #    m = s.match(/(~[a-z]*)?\/.*\//)
  m = s.match(/((~[a-z]*)?\/.*\/\S+):(\d+)/)
  if m != nil
    if File.exist?(File.expand_path(m[1]))
      return [m[1], m[3].to_i]
    end
  end
  return nil
end

def open_url(url)
  system("xdg-open", url)
end

def open_with_default_program(url)
  system("xdg-open", url)
end


def run_cmd(cmd)
  tmpf = Tempfile.new("vmarun", "/tmp").path
  cmd = "#{cmd} > #{tmpf}"
  puts "CMD:\n#{cmd}"
  system("bash", "-c", cmd)
  res_str = File.read(tmpf)
  return res_str
end

def set_register(char)
  $cur_register = char
  message("Set register #{char}")
end

def paste_register(char)
  $c = $register[char]
  message("Paste: #{$c}")
end

def find_project_dir_of_fn(fn)
  pcomp = Pathname.new(fn).each_filename.to_a
  parent_dirs = (0..(pcomp.size - 2)).collect { |x| "/" + pcomp[0..x].join("/") }.reverse
  projdir = nil
  for pdir in parent_dirs
    candfn = "#{pdir}/.vma_project"
    if File.exist?(candfn)
      projdir = pdir
      break
    end
  end
  return projdir
end

def find_project_dir_of_cur_buffer()
  # Find "project dir" of current file. If currently editing file in path "/foo/bar/baz/fn.txt" and file named "/foo/bar/.vma_project" exists, then dir /foo/bar is treated as project dir and subject to e.g. ack search.
  pdir = nil
  if $buffer.fname
    pdir = find_project_dir_of_fn($buffer.fname)
  end
  # puts "Proj dir of current file: #{pdir}"
  return pdir
end

