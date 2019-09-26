
#scriptdir=File.expand_path(File.dirname(__FILE__))
$:.unshift File.dirname(__FILE__) + "/lib"
require "pathname"
require "date"
require "ripl/multi_line"
require "json"

# require 'benchmark/ips'

load "vendor/ver/lib/ver/vendor/textpow.rb"
load "vendor/ver/lib/ver/syntax/detector.rb"
load "vendor/ver/config/detect.rb"

require "differ"

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Globals
# $last_event = []
$command_history = []
$clipboard = []
$register = Hash.new("")
$cnf = {}
$search_dirs = ["."]
$errors = []

$do_center = 0
$cur_register = "a"
#$cpos = 0
#$lpos = 0
#$larger_cpos = 0
#$cur_line = nil
$input_char_call_func = nil
$check_modifiers = false
$search_indexes = []
$debuginfo = {}

$paint_stack = []
$jump_sequence = []

$debug = false

def debug(message)
  if $debug
    puts "[#{DateTime.now().strftime("%H:%M:%S")}] #{message}"
    $stdout.flush
  end
end

require "fileutils"
require "vimamsa/constants"
require "vimamsa/macro"
require "vimamsa/buffer"
require "vimamsa/search"
require "vimamsa/search_replace"
require "vimamsa/key_binding_tree"
require "vimamsa/buffer_select"
require "vimamsa/file_finder"
require "vimamsa/actions"
require "vimamsa/hook"
require "vimamsa/debug"
require "vimamsa/highlight"
require "vimamsa/easy_jump"
require "vimamsa/encrypt"
require "vimamsa/profiler"
require "vimamsa/hyper_plain_text.rb"

class Converter
  def initialize(obj, type, id = nil)
    @obj = obj
    @type = type
    if id != nil
      $vma.reg_conv(self, id)
    end
  end

  def apply(txt)
    if @type == :gsub
      return txt.gsub(@obj[0], @obj[1])
    elsif @type == :lambda
      return @obj.call(txt)
    end
  end
end

# Example:
# c=Converter.new([/(.*):(\d+)/,'\1 => [\2]'],:gsub)
# c.apply('foo:23')
# "foo => [23]"

class Editor
  attr_reader :file_content_search_paths, :file_name_search_paths
  attr_accessor :converters, :fh
  #attr_writer :call_func, :update_highlight

  def initialize()
    # Thread.new{10000.times{|x|sleep(3);10000.times{|y|y+2};puts "FOOTHREAD #{x}"}}

    # Search for content inside files (e.g. using ack/grep) in:
    @file_content_search_paths = []

    # Search for files based on filenames in:
    @file_name_search_paths = []

    #Regexp gsubs or other small modifiers of text
    @converters = {}
  end

  def start
    $highlight = {}
    $macro = Macro.new
    $search = Search.new
    $hook = Hook.new

    $buffers = BufferList.new
    $minibuffer = Buffer.new(">", "")

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
    # load_theme("Amy")
    # load_theme("Espresso Libre")
    # load_theme("SovietCockpit")

    # Limit file search to these extensions:
    $find_extensions = [".txt", ".h", ".c", ".cpp", ".hpp", ".rb"]

    dotfile = read_file("", "~/.vimamsarc")
    eval(dotfile) if dotfile

    build_options

    $fname = "test.txt"
    if conf(:startup_file)
      fname_ = File.expand_path(conf(:startup_file))
      if File.exist?(fname_)
        $fname = fname_
      end
    end
    $fname = ARGV[1] if ARGV.size >= 2 and File.file?(ARGV[1])
    $vma.add_content_search_path(Dir.pwd)
    for fn in ARGV
      fn = File.expand_path(fn)
      if File.directory?(fn)
        $vma.add_content_search_path(fn)
        $search_dirs << fn
      end
    end

    buffer = Buffer.new(read_file("", $fname), $fname)
    $buffers << buffer

    load_theme($cnf[:theme])

    render_buffer($buffer, 1)

    gui_select_buffer_init
    gui_file_finder_init

    #Load plugins
    require "vimamsa/file_history.rb"
    @fh = FileHistory.new
    
  end
  
  def shutdown()
    $hook.call(:shutdown)
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
end

$vma = Editor.new

def _quit()
  # Shut down the Qt thread before the ruby thread
  $vma.shutdown
  qt_quit
  exit
end

def qt_signal(sgnname, param)
  debug "GOT QT-SIGNAL #{sgnname}: #{param}"
  if sgnname == "saveas"
    file_saveas(param)
  elsif sgnname == "filenew"
    create_new_file
    render_buffer
  elsif sgnname == "save"
    $buffer.save
  end
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
  $buffer.set_pos(new_pos)
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

def invoke_search()
  start_minibuffer_cmd("", "", :execute_search)
end

def start_minibuffer_cmd(bufname, bufstr, cmd)
  $kbd.set_mode(:minibuffer)
  $minibuffer = Buffer.new(bufstr, "")
  $minibuffer.call_func = method(cmd)
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

def gui_ack()
  nfo = "Search contents of all files using ack\n\nHint: add empty file named .vma_project to dirs you want to search.\nIf .vma_project exists in parent dir of current file, searches in that dir"
  gui_one_input_action(nfo, "Search:", "search", "ack_buffer")
end

def invoke_ack_search()
  start_minibuffer_cmd("", "", :ack_buffer)
end

def show_key_bindings()
  kbd_s = "❙Key bindings❙\n"
  kbd_s << "=======================================\n"
  kbd_s << $kbd.to_s
  kbd_s << "\n=======================================\n"
  create_new_file(nil, kbd_s)
end

def grep_cur_buffer(search_str, b = nil)
  debug "grep_cur_buffer(search_str)"
  lines = $buffer.split("\n")
  r = Regexp.new(Regexp.escape(search_str), Regexp::IGNORECASE)
  fpath = ""
  fpath = $buffer.pathname.expand_path.to_s + ":" if $buffer.pathname
  res_str = ""
  lines.each_with_index { |l, i|
    if r.match(l)
      res_str << "#{fpath}#{i + 1}:#{l}\n"
    end
  }
  create_new_file(nil, res_str)
end

def invoke_grep_search()
  start_minibuffer_cmd("", "", :grep_cur_buffer)
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

def execute_search(input_str)
  $search = Search.new
  return $search.set(input_str, "simple", $buffer)
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

def read_file(text, path)
  path = Pathname(path.to_s).expand_path
  FileUtils.touch(path) unless File.exist?(path)
  if !File.exist?(path)
    #TODO: fail gracefully
    return
  end

  encoding = text.encoding
  content = path.open("r:#{encoding.name}") { |io| io.read }

  debug("GUESS ENCODING")
  unless content.valid_encoding? # take a guess
    GUESS_ENCODING_ORDER.find { |enc|
      content.force_encoding(enc)
      content.valid_encoding?
    }
    content.encode!(Encoding::UTF_8)
  end
  debug("END GUESS ENCODING")

  #TODO: Should put these as option:
  content.gsub!(/\r\n/, "\n")
  content.gsub!(/\t/, "    ")

  #    content = filter_buffer(content)
  debug("END FILTER")
  return content
end

def create_new_file(filename = nil, file_contents = "\n")
  debug "NEW FILE CREATED"
  buffer = Buffer.new(file_contents)
  $buffers << buffer
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
  debug("DONE LOAD: #{fname}")
  #buf = filter_buffer(buffer)
  #    debug("END FILTER: #{fname}")
  $buffers << buffer
  #$buffer_history << $buffers.size - 1
end

def jump_to_file(filename, linenum)
  new_file_opened(filename)
  if linenum > 0
    $buffer.jump_to_line(linenum)
    center_on_current_line
  end
end

def open_existing_file(filename)
  new_file_opened(filename)
end

def new_file_opened(filename, file_contents = "")
  #TODO: expand path
  filename = File.expand_path(filename)
  b = $buffers.get_buffer_by_filename(filename)
  # File is already opened to existing buffer
  if b != nil
    message "Switching to: #{filename}"
    $buffers.set_current_buffer(b)
  else
    message "New file opened: #{filename}"
    $fname = filename
    load_buffer($fname)
  end
  set_window_title("Vimamsa - #{File.basename(filename)}")
  render_buffer #TODO: needed?
end

def scan_word_start_marks(search_str)
  wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}|\Z/) # \Z = end of string, just before last newline.
  wsmarks2 = scan_indexes(search_str, /\n[ \t]*\n/) # "empty" lines that have whitespace
  wsmarks2 = wsmarks2.collect { |x| x + 1 }
  wsmarks = (wsmarks2 + wsmarks).sort.uniq
  return wsmarks
end

def draw_text(str, x, y)
  $paint_stack << [4, x, y, str]
  #cpp_function_wrapper(1,[str,x,y]);
end

def get_visible_area()
  return cpp_function_wrapper(2, [])
end

def center_on_current_line()
  $do_center = 1
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
  reset = 1 if $buffer.need_redraw?
  t1 = Time.now
  hook_draw()

  render_text(tmpbuf, pos, selection_start, reset)

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

def is_url(s)
  return s.match(/(https?|file):\/\/.*/) != nil
end

def is_existing_file(s)
  if is_path(s) and File.exist?(File.expand_path(s))
    return true
  end
  return false
end

def is_path(s)
  m = s.match(/(~[a-z]*)?\/.*\//)
  if m != nil
    return true
  end
  return false
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

def run_cmd(cmd)
  tmpf = Tempfile.new("ack", "/tmp").path
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

t1 = Thread.new { main_loop }
t1.join
debug("END")
