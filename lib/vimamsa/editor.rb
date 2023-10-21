require "pty"

def exec_in_terminal(cmd, autoclose = false)
  # debug "CMD:#{cmd}"

  # global to prevent garbage collect unlink
  $initf = Tempfile.new("bashinit")
  # debug $initf.path
  $initf.write(cmd)
  if autoclose
    $initf.write("\nsleep 10; exit;\n")
    $initf.write("rm #{$initf.path}\n")
  else
    $initf.write("rm #{$initf.path}\n")
    $initf.write("\nexec bash\n")
  end
  $initf.close
  # PTY.spawn("gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash")
  # fork { exec "gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash" }
  # Just another execution
  fork { exec "gnome-terminal", "--tab", "--", "bash", "-i", $initf.path, "-c", "exec bash" }
end

def handle_drag_and_drop(fname)
  debug "EDITOR:handle_drag_and_drop"
  buf.handle_drag_and_drop(fname)
end

def mkdir_if_not_exists(_dirpath)
  dirpath = File.expand_path(_dirpath)
  Dir.mkdir(dirpath) unless File.exist?(dirpath)
end

class Editor
  attr_reader :file_content_search_paths, :file_name_search_paths, :gui, :hook, :macro
  attr_accessor :converters, :fh, :paint_stack, :kbd, :langsrv
  #attr_writer :call_func, :update_highlight

  def initialize()
    # Thread.new{10000.times{|x|sleep(3);10000.times{|y|y+2};debug "FOOTHREAD #{x}"}}

    # Search for content inside files (e.g. using ack/grep) in:
    @file_content_search_paths = []

    # Search for files based on filenames in:
    @file_name_search_paths = []

    #Regexp gsubs or other small modifiers of text
    @converters = {}
    @paint_stack = []
    @_plugins = {}
  end

  def open_file_listener(added)
    if !added.empty?
      for fp in added
        sleep 0.1
        x = IO.read(fp)
        File.delete(fp)
        for f in x.lines
          f.gsub!("\n", "")
          if File.exist?(f)
            if file_is_text_file(f)
              jump_to_file(f)
            end
          end
        end
      end
    end
  end

  def start
    @gui = $vmag #TODO

    $hook = Hook.new
    @hook = $hook
    register_plugin(:Hook, @hook)
    @macro = Macro.new
    $macro = @macro
    register_plugin(:Macro, $macro)
    $search = Search.new
    register_plugin(:Search, $search)

    $buffers = BufferList.new
    $minibuffer = Buffer.new(">", "")
    @langsrv = {}

    require "vimamsa/text_transforms"

    debug "ARGV: " + ARGV.inspect
    # build_key_bindings_tree
    @kbd = KeyBindingTree.new()
    $kbd = @kbd
    require "vimamsa/key_bindings_vimlike"
    sleep(0.03)
    

    FileManager.init
    BufferManager.init
    
    @gui.init_menu

    mkdir_if_not_exists("~/.vimamsa")
    mkdir_if_not_exists("~/.vimamsa/backup")
    mkdir_if_not_exists("~/.vimamsa/listen")
    listen_dir = File.expand_path "~/.vimamsa/listen"
    listener = Listen.to(listen_dir) do |modified, added, removed|
      debug([modified: modified, added: added, removed: removed])
      open_file_listener(added)
    end
    listener.start

    custom_fn = File.expand_path("~/.vimamsa/custom.rb")
    if !File.exist?(custom_fn)
      example_custom = IO.read(ppath("custom_example.rb"))
      IO.write(custom_fn, example_custom)
    end

    mkdir_if_not_exists("~/.vimamsa/custom.rb")

    $cnf[:theme] = "Twilight_edit"
    $cnf[:syntax_highlight] = true
    settings_path = get_dot_path("settings.rb")
    if File.exist?(settings_path)
      $cnf = eval(IO.read(settings_path))
    end

    # set_gui_style(1)

    #TODO: remove
    dotfile = read_file("", "~/.vimamsarc")
    eval(dotfile) if dotfile

    custom_script = read_file("", custom_fn)
    eval(custom_script) if custom_script

    if conf(:enable_lsp)
      require "vimamsa/langservp"
      @langsrv["ruby"] = LangSrv.new("ruby")
      @langsrv["cpp"] = LangSrv.new("cpp")
    end

    # build_options

    fname = nil
    if conf(:startup_file)
      fname_ = File.expand_path(conf(:startup_file))
      if File.exist?(fname_)
        fname = fname_
      end
    else
      fname = ppath("demo.txt")
    end
    fname = ARGV[0] if ARGV.size >= 1 and File.file?(File.expand_path(ARGV[0]))
    # vma.add_content_search_path(Dir.pwd)
    for fn in ARGV
      fn = File.expand_path(fn)
      if File.directory?(fn)
        vma.add_content_search_path(fn)
        $search_dirs << fn
      end
    end

    if fname
      open_new_file(fname)
    else
      create_new_buffer(file_contents = "\n")
    end

    #Load plugins
    require "vimamsa/file_history.rb"
    @fh = FileHistory.new
    @_plugins[:FileHistory] = @fh

    register_plugin(:FileHistory, @fh)
    register_plugin(:FileFinder, FileFinder.new)
    # To access via vma.FileFinder
    # self.define_singleton_method(:FileFinder) { @_plugins[:FileFinder] }

    @hook.call(:after_init)
  end

  def register_plugin(name, obj)
    @_plugins[name] = obj
    # To access via e.g. vma.FileFinder
    self.define_singleton_method(name) { obj }
  end

  def buf()
    return $buffer
  end

  def buf=(aa)
    $buffer = aa
  end

  def buffers()
    return $buffers
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
    @hook.call(:shutdown)
    save_state
    @gui.quit
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
    reg_act(converter_id, proc { vma.buf.convert_selected_text(converter_id) }, "Converter #{converter_id}", { :scope => [:selection] })
  end

  def apply_conv(converter_id, txt)
    @converters[converter_id].apply(txt)
  end

  # Used only by ack module at the moment
  def get_content_search_paths()
    r = @file_content_search_paths.clone
    p = find_project_dir_of_cur_buffer()
    if p.nil?
      p = vma.buffers.last_dir
    end

    if p and !@file_content_search_paths.include?(p)
      r.insert(0, p)
    end

    return r
  end

  def can_open_extension?(filepath)
    exts = $cnf[:extensions_to_open]
    extname = Pathname.new(filepath).extname.downcase
    can_open = exts.include?(extname)
    debug "CAN OPEN?: #{can_open}"
    return can_open
  end
end

def _quit()
  vma.shutdown
  # Gtk.main_quit
end

def fatal_error(msg)
  debug msg
  exit!
end

def file_saveas(filename)
  buf.save_as_callback(filename)
end

def open_file_dialog()
  path = ""
  path = vma.buf.fname if vma.buf.fname
  gui_open_file_dialog(File.dirname(path))
end

#TODO:delete?
def system_clipboard_changed(clipboard_contents)
  max_clipboard_items = 100
  if clipboard_contents != $clipboard[-1]
    #TODO: HACK
    $paste_lines = false
  end
  $clipboard << clipboard_contents
  # debug $clipboard[-1]
  $clipboard = $clipboard[-([$clipboard.size, max_clipboard_items].min)..-1]
end

def get_clipboard()
  return $clipboard[-1]
end

def set_clipboard(s)
  if !(s.class <= String) or s.size == 0
    debug s.inspect
    debug [s, s.class, s.size]
    log_error("s.class != String or s.size == 0")
    # Ripl.start :binding => binding
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
  #render_buffer(vma.buf)
  debug "New pos: #{new_pos}lpos:#{vma.buf.lpos} cpos:#{vma.buf.cpos}"
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
  vma.buf.jump_to_next_instance_of_char($last_find_command[:char],
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
  vma.kbd.set_mode(:minibuffer)
  $minibuffer = Buffer.new(bufstr, "")
  $minibuffer.call_func = method(cmd)
end

def show_key_bindings()
  kbd_s = "❙Key bindings❙\n"
  kbd_s << "\n⦁[Mode] keys : action⦁\n"

  kbd_s << "[B]=Browse, [C]=Command, [I]=Insert, [V]=Visual\n"
  kbd_s << "key!: Press key once, release before pressing any other keys\n"

  kbd_s << "===============================================\n"
  kbd_s << vma.kbd.to_s
  kbd_s << "\n"
  kbd_s << "===============================================\n"
  b = create_new_file(nil, kbd_s)
  gui_set_file_lang(b.id, "hyperplaintext")
  #
end

def diff_buffer()
  bufstr = ""
  orig_path = vma.buf.fname
  infile = Tempfile.new("out")
  infile = Tempfile.new("in")
  infile.write(vma.buf.to_s)
  infile.flush
  cmd = "diff -w '#{orig_path}' #{infile.path}"
  # debug cmd
  bufstr << run_cmd(cmd)
  # debug bufstr
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
  #vma.buf = $minibuffer
end

# def readchar_new_char(c)
# $input_char_call_func.call(c)
# end

def minibuffer_delete()
  $minibuffer.delete(BACKWARD_CHAR)
end

def message(s)
  s = "[#{DateTime.now().strftime("%H:%M")}] #{s}"
  debug s

  $vmag.add_to_minibuf(s)
  # $minibuffer = Buffer.new(s, "")
  # $minibuffer[0..-1] = s # TODO
  #render_minibuffer
end

GUESS_ENCODING_ORDER = [
  Encoding::US_ASCII,
  Encoding::UTF_8,
  Encoding::ISO_8859_1,
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
  buffer = Buffer.new(file_contents)

  debug "NEW FILE CREATED: #{buffer.id}"
  vma.buffers.add(buffer)
  vma.kbd.set_mode_to_default
  vma.buffers.set_current_buffer_by_id(buffer.id)

  # Do set_content twice (once in Buffer.new) to force redraw and work around a bug 
  # The bug: if switching a child of scrolledWindow to a textview with a file smaller than the window, it won't get drawn properly if in previous (larger) file the ScrolledWindow was scrolled down.
  buffer.set_content(file_contents)

  return buffer
end

def create_new_buffer(file_contents = "\n",prefix="buf", setcurrent=true)
  debug "NEW BUFFER CREATED"
  buffer = Buffer.new(file_contents,nil,prefix)
  vma.buffers.add(buffer)
  vma.buffers.set_current_buffer_by_id(buffer.id) if setcurrent
  buffer.set_content(file_contents)

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
  # If file already open in existing buffer
  existing_buffer = vma.buffers.get_buffer_by_filename(fname)
  if existing_buffer != nil
    vma.buffers.add_buf_to_history(existing_buffer)
    return
  end
  return if !File.exist?(fname)
  debug("LOAD BUFFER: #{fname}")
  buffer = Buffer.new(read_file("", fname), fname)
  # gui_set_current_buffer(buffer.id)
  buffer.set_active
  debug("DONE LOAD: #{fname}")
  #buf = filter_buffer(buffer)
  #    debug("END FILTER: #{fname}")
  vma.buffers << buffer
  #$buffer_history << vma.buffers.size - 1
  return buffer
end

def jump_to_file(filename, linenum = nil, charn = nil)
  open_new_file(filename)

  # Link to character position
  if !charn.nil?
    if charn == "c"
      buf.jump_to_pos(linenum)
      center_on_current_line
      return
    end
  end

  # Link to line
  if !linenum.nil?
    buf.jump_to_line(linenum)
    center_on_current_line
    return
  end
end

#TODO: needed?
def open_existing_file(filename)
  open_new_file(filename)
end

def open_new_file(filename, file_contents = "")
  #TODO: expand path
  filename = File.expand_path(filename)
  b = vma.buffers.get_buffer_by_filename(filename)
  # File is already opened to existing buffer
  if b != nil
    message "Switching to: #{filename}"
    vma.buffers.set_current_buffer(b)
  else
    message "New file opened: #{filename}"
    fname = filename
    bf = load_buffer(fname)
    vma.buffers.set_current_buffer_by_id(bf.id)
  end
end

def scan_word_start_marks(search_str)
  # \Z = end of string, just before last newline.
  wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}|\Z/)
  return wsmarks
end

def hook_draw()
  # TODO: as hook.register
  # easy_jump_draw()
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
  m = s.match(/((~[a-z]*)?\/.*\/\S+):(c?)(\d+)/)
  if m != nil
    if File.exist?(File.expand_path(m[1]))
      return [m[1], m[4].to_i, m[3]]
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
  debug "CMD:\n#{cmd}"
  system("bash", "-c", cmd)
  res_str = File.read(tmpf)
  return res_str
end

require "open3"

def exec_cmd(bin_name, arg1 = nil, arg2 = nil, arg3 = nil, arg4 = nil, arg5 = nil)
  assert_binary_exists(bin_name)
  if !arg5.nil?
    p = Open3.popen2(bin_name, arg1, arg2, arg3, arg4, arg5)
  elsif !arg4.nil?
    p = Open3.popen2(bin_name, arg1, arg2, arg3, arg4)
  elsif !arg3.nil?
    p = Open3.popen2(bin_name, arg1, arg2, arg3)
  elsif !arg2.nil?
    p = Open3.popen2(bin_name, arg1, arg2)
  elsif !arg1.nil?
    p = Open3.popen2(bin_name, arg1)
  else
    p = Open3.popen2(bin_name)
  end

  ret_str = p[1].read
  return ret_str
end

def file_is_text_file(fpath)
  debug "file_is_text_file(#{fpath})"
  fpath = File.expand_path(fpath)
  return false if !File.exist?(fpath)
  r = exec_cmd("file", fpath)
  debug "DEBUG:#{r}"
  return true if r.match(/UTF-8.*text/)
  return true if r.match(/ASCII.*text/)
  return false
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
  if vma.buf.fname
    pdir = find_project_dir_of_fn(vma.buf.fname)
  end
  # debug "Proj dir of current file: #{pdir}"
  return pdir
end
