
#scriptdir=File.expand_path(File.dirname(__FILE__))
$:.unshift File.dirname(__FILE__) + "/lib"
require 'pathname'
require 'date'
require 'ripl/multi_line'
require 'openssl'
require 'json'
load 'vendor/ver/lib/ver/vendor/textpow.rb'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Globals
$last_event = []
$command_history = []
$clipboard = []
$register = Hash.new('')
$cnf = {}
$search_dirs=['.']
$errors =[]

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

$cnf[:syntax_highlight] = false

def debug(message)
    puts "[#{DateTime.now().strftime("%H:%M:%S:%L")}] #{message}"
    $stdout.flush
end

require 'fileutils'
require 'vimamsa/macro'
require 'vimamsa/buffer'
require 'vimamsa/search'
require 'vimamsa/key_bindings'
require 'vimamsa/buffer_select'
require 'vimamsa/file_finder'
require 'vimamsa/actions'
require 'vimamsa/hook'
require 'vimamsa/error_handling'

$macro = Macro.new
$search = Search.new
$hook = Hook.new

COMMAND = 1
INSERT = 2
BROWSE = 3
VISUAL = 4
MINIBUFFER = 5
READCHAR = 6
BROWSE = 7

NEXT_MARK = 1001
PREVIOUS_MARK = 1002
BACKWARD = 1003
FORWARD = 1004
BEFORE = 1005
AFTER = 1006
SELECTION = 1007

FORWARD_CHAR = 2001
BACKWARD_CHAR = 2002
FORWARD_LINE = 2003
BACKWARD_LINE = 2004
CURRENT_CHAR_FORWARD = 2005
CURRENT_CHAR_BACKWARD = 2006
START_OF_BUFFER = 2007
END_OF_BUFFER = 2008
BACKWARD = 2009
FORWARD = 2010
END_OF_LINE = 2011
BEGINNING_OF_LINE = 2012
WORD_START = 2013
WORD_END = 2014
FIRST_NON_WHITESPACE = 2014

DELETE = 3001
REPLACE = 3002

KEY_PRESS = 6
KEY_RELEASE = 7 # QEvent::KeyRelease   


# http://qt-project.org/doc/qt-5.0/qtcore/qt.html#KeyboardModifier-enum
ALTMODIFIER = 0x08000000
NOMODIFIER = 0x00000000 #	No modifier key is pressed.
SHIFTMODIFIER = 0x02000000 #	A Shift key on the keyboard is pressed.
CONTROLMODIFIER = 0x04000000 #	A Ctrl key on the keyboard is pressed.
ALTMODIFIER = 0x08000000 #	An Alt key on the keyboard is pressed.
METAMODIFIER = 0x10000000 #	A Meta key on the keyboard is pressed.
KEYPADMODIFIER = 0x20000000 #	A keypad button is pressed.

$buffers = BufferList.new
$minibuffer = Buffer.new(">", "")

def _quit()
    # Shut down the Qt thread before the ruby thread
    qt_quit
    exit
end

class Processor
    attr_reader :highlights

    def start_parsing(name)
        puts "start_parsing"
        @marks=[]
        @lineno = -1
        @tags = {}

        @hltags={}
        @hltags["storage.type.c"] = 3
        @hltags["string.quoted.double.c"] = 2
        @hltags["constant.other.placeholder.c"] = 1
        @hltags["constant.numeric.c"] = 2
        #        @hltags["support.function.C99.c"] = 4
        @hltags["keyword.operator.sizeof.c"] = 4
        @hltags["keyword.control.c"] = 4

        $highlight ={}
        @highlights ={}
    end

    def end_parsing(name)
        #        Ripl.start :binding => binding
        #        puts "end_parsing"
    end

    def new_line(line)
        #        puts "new_line:#{@lineno} #{line}"
        @lineno += 1
    end

    def open_tag(name, pos)
        format = get_format(name)
        #        puts "open_tag:#{name} pos:#{pos}"
        #        if name == "string.quoted.double.c"
        if format
            @tags[name] = [@lineno, pos]
        end
    end

    def close_tag(name, mark)
        #        puts "close_tag:#{name} mark:#{mark}"
        format = get_format(name)
        if format
            if @tags[name] and @tags[name][0] == @lineno
                startpos = @tags[name][1]
                endpos = mark
                @highlights[@lineno] = [] if @highlights[@lineno] == nil
                @highlights[@lineno] << [startpos, endpos, format]
                @highlights[@lineno].sort!
            end
        end
    end
end

def get_format(name)
    format = nil
    #format = 4 if name.match(/keyword.operator/)
    format = 4 if name.match(/keyword.control/)
    format = 3 if name.match(/storage.type/)
    format = 2 if name.match(/string.quoted/)
    format = 2 if name.match(/constant.numeric/)
    format = 1 if name.match(/constant.other.placeholder/)
    return format

end

def toggle_highlight
    $cnf[:syntax_highlight] = !$cnf[:syntax_highlight]
end

def qt_signal(sgnname, param)
    puts "GOT QT-SIGNAL #{sgnname}: #{param}"
    if sgnname == "saveas"
        file_saveas(param)
    end
end

def file_saveas(filename)
    $buffer.set_filename(filename)
    $buffer.save()
end

def system_clipboard_changed(clipboard_contents)
    max_clipboard_items = 100
    if clipboard_contents != $clipboard[-1]
        #TODO: HACK
        $paste_lines = false
    end
    $clipboard << clipboard_contents
    puts "DEBUG"
    puts $clipboard[-1]
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
    puts "SET CLIPBOARD: [#{s}]"
    puts "REGISTER: #{$cur_register}:#{$register[$cur_register]}"
end


def set_cursor_pos(new_pos)
    $buffer.set_pos(new_pos)
    #render_buffer($buffer)
    puts "New pos: #{new_pos}lpos:#{$buffer.lpos} cpos:#{$buffer.cpos}"
end
def set_last_command(cmd)
    $command_history << cmd
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
        $next_command_count = $next_command_count*10 + num.to_i
    else
        $next_command_count = num.to_i
    end
    debug("NEXT COMMAND COUNT: #{$next_command_count}")
end

def invoke_search()
    start_minibuffer_cmd("", "",:execute_search)
end

def start_minibuffer_cmd(bufname, bufstr, cmd)
    $at.set_mode(MINIBUFFER)
    $minibuffer = Buffer.new(bufstr, "")
    $minibuffer.call_func = method(cmd)
end

def ack_buffer(instr)
    instr = instr.gsub("'",".") # TODO
    bufstr = ""
    for path in $file_content_search_paths
        bufstr += run_cmd("ack --type-add=gd=.gd -k --nohtml --nojs --nojson '#{instr}' #{path}")
    end
    create_new_file(nil, bufstr)
end

def invoke_ack_search()
    start_minibuffer_cmd("", "",:ack_buffer)
end

def grep_cur_buffer(search_str)

    puts "grep_cur_buffer(search_str)"
    lines = $buffer.split("\n")
    r = Regexp.new(Regexp.escape(search_str), Regexp::IGNORECASE)
    fpath = $buffer.pathname.expand_path.to_s
    #    Ripl.start :binding => binding
    res_str = ""
    lines.each_with_index{|l, i|
        if r.match(l)
            res_str << "#{fpath}:#{i+1}:#{l}\n"
        end
    }
    create_new_file(nil, res_str)
end

def invoke_grep_search()
    start_minibuffer_cmd("", "",:grep_cur_buffer)
end


def diff_buffer()
    puts "diff_bufferZZ"
    bufstr = ""
    orig_path = $buffer.fname
    infile = Tempfile.new('out')
    infile = Tempfile.new('in')
    infile.write($buffer.to_s)
    infile.flush
    cmd = "diff -w '#{orig_path}' #{infile.path}"
    puts cmd
    bufstr << run_cmd(cmd)
    puts bufstr
    infile.close;  infile.unlink
    create_new_file(nil, bufstr)
end

def invoke_replace()
    start_minibuffer_cmd("", "",:buf_replace_string)
end

# Requires instr in form "FROM/TO"
# Replaces all occurences of FROM with TO
def buf_replace_string(instr)
    puts "buf_replace_string(instr=#{instr})"

    a = instr.split("/")
    if a.size != 2
        return
    end

    if $buffer.visual_mode?
        r = $buffer.get_visual_mode_range
        txt = $buffer[r]
        txt.gsub!(a[0], a[1])
        $buffer.replace_range(r, txt)
        $buffer.end_visual_mode
    else
        repbuf = $buffer.to_s.clone
        repbuf.gsub!(a[0], a[1])
        tmppos = $buffer.pos
        message("Replace #{a[0]} with #{a[1]}.")
        if repbuf == $buffer.to_s.clone
            message("Replacing #{a[0]} with #{a[1]}. NO CHANGE.")
        else
            $buffer.set_content(repbuf)
            $buffer.set_pos(tmppos)
            $do_center = 1
            message("Replacing #{a[0]} with #{a[1]}.")
        end
    end
end


def invoke_command()
    start_minibuffer_cmd("", "",:execute_command)
end

def execute_search(input_str)
    $search = Search.new
    $search.set(input_str, 'simple',$buffer)
end

def execute_command(input_str)
    begin
        out_str = eval(input_str)
        $minibuffer.clear
        $minibuffer << out_str.to_s #TODO: segfaults, why?
    rescue SyntaxError
        debug("SYNTAX ERROR with eval cmd #{action}: " + $!.to_s)
    end
end


def minibuffer_end()
    puts "MINIBUFFER END2"
    $at.set_mode(COMMAND)
    minibuffer_input = $minibuffer.to_s[0..-2]
    $minibuffer.call_func.call(minibuffer_input)
end

def minibuffer_cancel()
    puts "MINIBUFFER END2"
    $at.set_mode(COMMAND)
    minibuffer_input = $minibuffer.to_s[0..-2]
    # $minibuffer.call_func.call('')
end

def minibuffer_new_char(c)
    if c == "\r"
        raise "Should not come here"
        puts "MINIBUFFER END"
    else
        $minibuffer.insert_char(c)
        puts "MINIBUFFER: #{c}"
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
    puts $minibuffer.to_s
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
    content = path.open("r:#{encoding.name}") {|io| io.read }

    debug("GUESS ENCODING")
    unless content.valid_encoding? # take a guess
        GUESS_ENCODING_ORDER.find {|enc|
            content.force_encoding(enc)
            content.valid_encoding?
        }
        content.encode!(Encoding::UTF_8)
    end
    debug("END GUESS ENCODING")

    #    content = filter_buffer(content)
    debug("END FILTER")
    return content
end

def create_new_file(filename = nil, file_contents = "\n")
    puts "NEW FILE CREATED"
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
    $buffer.jump_to_line(linenum) if linenum > 0
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
        puts "File is already opened to existing buffer: #{filename}"
        $buffers.set_current_buffer(b)
    else
        puts "NEW FILE OPENED: #{filename} \n CONTENTS: #{file_contents}"
        $fname = filename
        load_buffer($fname)
    end
    set_window_title("Vimamsa - #{File.basename(filename)}")
    render_buffer #TODO: needed?
end


def debug_print_buffer(c)
    puts $buffer.inspect
    puts $buffer
end
def debug_dump_clipboard()
    puts $clipboard.inspect
end

def debug_dump_deltas()
    puts $buffer.edit_history.inspect
end

def save_file()
    $buffer.save()
end


def scan_word_start_marks(search_str)
    wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}|\Z/) # \Z = end of string, just before last newline.
    wsmarks2 = scan_indexes(search_str, /\n[ \t]*\n/) # "empty" lines that have whitespace
    wsmarks2 = wsmarks2.collect {|x| x+1}
    wsmarks = (wsmarks2 + wsmarks).sort.uniq
    return wsmarks
end

def draw_text(str, x, y)
    $paint_stack << [4, x, y, str]
    #cpp_function_wrapper(1,[str,x,y]);
end

def get_visible_area()
    return cpp_function_wrapper(2,[]);
end
def center_on_current_line()
    return cpp_function_wrapper(3,[]);
end
def make_jump_sequence(num_items)
    left_hand = "asdfvgbqwertzxc123".upcase.split("")
    right_hand = "jklhnnmyuiop890".upcase.split("")

    sequence = []
    left_hand_fast = "asdf".upcase.split("")
    right_hand_fast = "jkl;".upcase.split("")

    left_hand_slow = "wergc".upcase.split("") # v
    right_hand_slow = "uiophnm,".upcase.split("")

    left_hand_slow2 = "tzx23".upcase.split("")
    right_hand_slow2 = "yb9'".upcase.split("")

    # Rmoved characters that can be mixed: O0Q, 8B, I1, VY

    left_fast_slow = Array.new(left_hand_fast).concat(left_hand_slow)
    right_fast_slow = Array.new(right_hand_fast).concat(right_hand_slow)

    left_hand_all = Array.new(left_hand_fast).concat(left_hand_slow).concat(left_hand_slow2)
    right_hand_all = Array.new(right_hand_fast).concat(right_hand_slow).concat(right_hand_slow2)

    left_hand_fast.each {|x|
        left_hand_fast.each {|y|
            sequence << "#{x}#{y}"
        }
    }

    right_hand_fast.each {|x|
        right_hand_fast.each {|y|
            sequence << "#{x}#{y}"
        }
    }

    right_hand_fast.each {|x|
        left_hand_fast.each {|y|
            sequence << "#{x}#{y}"
        }
    }

    left_hand_fast.each {|x|
        right_hand_fast.each {|y|
            sequence << "#{x}#{y}"
        }
    }

    left_hand_slow.each {|x|
        right_fast_slow.each {|y|
            sequence << "#{x}#{y}"
        }
    }

    right_hand_slow.each {|x|
        left_fast_slow.each {|y|
            sequence << "#{x}#{y}"
        }
    }

    left_hand_slow2.each {|x|
        right_hand_all.each {|y|
            left_hand_all.each {|z|
                sequence << "#{x}#{y}#{z}"
            }
        }
    }

    right_hand_slow2.each {|x|
        left_hand_all.each {|y|
            right_hand_all.each {|z|
                sequence << "#{x}#{y}#{z}"
            }
        }
    }

    #printf("Size of sequence: %d\n",sequence.size)
    #puts sequence.inspect
    return sequence

end


def easy_jump(direction)
    puts "EASY JUMP"
    $easy_jump_wsmarks = scan_word_start_marks($buffer)
    visible_range = get_visible_area()
    $easy_jump_wsmarks = $easy_jump_wsmarks.select {|x|
    x >= visible_range[0] && x <= visible_range[1] }


    $easy_jump_wsmarks.sort_by!{|x| (x-$buffer.pos).abs }

    printf("VISIBLE RANGE: #{visible_range.inspect}\n")
    printf("vsmarks: #{$easy_jump_wsmarks.inspect}\n")
    $jump_sequence = make_jump_sequence($easy_jump_wsmarks.size)
    #puts $jump_sequence.inspect
    $input_char_call_func = method(:easy_jump_input_char)
    $at.set_mode(READCHAR)
    $easy_jump_input = ""
    puts "========="
end

def easy_jump_input_char(c)
    puts "EASY JUMP: easy_jump_input_char [#{c}]"
    $easy_jump_input << c.upcase
    if $jump_sequence.include?($easy_jump_input)
        jshash = Hash[$jump_sequence.map.with_index.to_a]
        nthword = jshash[$easy_jump_input]+1
        puts "nthword:#{nthword} #{$easy_jump_wsmarks[nthword]}"
        $buffer.set_pos($easy_jump_wsmarks[nthword])
        $at.set_mode(COMMAND)
        $input_char_call_func = nil
        $jump_sequence = []
    end
    if $easy_jump_input.size > 2
        $at.set_mode(COMMAND)
        $input_char_call_func = nil
        $jump_sequence = []
    end
end



def easy_jump_draw()
    return if $jump_sequence.empty?
    puts "EASY JUMP DRAW"
    #wsmarks = scan_word_start_marks($buffer)
    screen_cord = cpp_function_wrapper(0,[$easy_jump_wsmarks]);
    screen_cord = screen_cord[1..$jump_sequence.size]
    #puts $jump_sequence
    #puts screen_cord.inspect
    screen_cord.each_with_index {|point, i|
        mark_str = $jump_sequence[i]
        #puts "draw #{point[0]}x#{point[1]}"
        draw_text(mark_str, point[0], point[1])
        #break if m > $cpos
    }
end

def hook_draw()
    puts "========= hook draw ======="
    easy_jump_draw()
    puts "==========================="
end

def render_buffer(buffer = 0, reset = 0)
    tmpbuf = $buffer.to_s
    puts "pos:#{$buffer.pos} L:#{$buffer.lpos} C:#{$buffer.cpos}"
    pos = $buffer.pos
    selection_start = $buffer.selection_start
    reset = 1 if $buffer.need_redraw?
    t1 = Time.now
    hook_draw()

    render_text(tmpbuf, pos, selection_start, reset)
    #$hook.call(:buffer_changed) #TODO: actually check if changed

    $buffer.highlight
    puts "Render time: #{Time.now - t1}" if Time.now - t1 > 1/50.0
    $buffer.set_redrawed if reset == 1
end

def vimamsa_init
    $highlight ={}

    puts $highlights
    puts "ARGV"
    puts ARGV.inspect
    build_key_bindings_tree
    require 'vimamsa/default_bindings'
    puts "START reading file"
    sleep(0.03)
    $fname = "test.txt"
    $fname = ARGV[1] if ARGV.size >= 2 and File.file?(ARGV[1])
    $file_content_search_paths = [Dir.pwd]
    for fn in ARGV
        fn = File.expand_path(fn)
        if File.directory?(fn)
            $file_content_search_paths << fn
            $search_dirs << fn
        end
    end

    buffer = Buffer.new(read_file("",$fname),$fname)
    $buffers << buffer
    puts $at # key map
    set_qt_style(1)
    $search_dirs << File.expand_path('~/Documents/')
    
    # Limit file search to these extensions:
    $find_extensions =[".txt", ".h", ".c", ".cpp", ".hpp", ".rb"]


    dotfile = read_file("", '~/.vimamsarc')
    eval(dotfile) if dotfile
    render_buffer($buffer, 1)

    gui_select_buffer_init
    gui_file_finder_init
end



def run_tests()
    run_test("01")
    run_test("02")
end

def run_test(test_id)
    target_results = read_file("", "tests/test_#{test_id}_output.txt")
    old_buffer = $buffer
    $buffer = Buffer.new("", "")
    load "tests/test_#{test_id}.rb"
    test_ok = $buffer.to_s.strip == target_results.strip
    puts "##################"
    puts target_results
    puts "##################"
    puts $buffer.to_s
    puts "##################"
    puts "TEST OK" if test_ok
    puts "TEST FAILED" if !test_ok
    puts "##################"
    $buffer = old_buffer

end


def encrypt(text, pass_phrase)
    salt = 'uvgixEtU'
    cipher = OpenSSL::Cipher.new 'AES-128-CBC'
    cipher.encrypt
    cipher.pkcs5_keyivgen pass_phrase, salt
    encrypted = cipher.update text
    encrypted << cipher.final
    return encrypted
end

def decrypt(encrypted, pass_phrase)
    salt = 'uvgixEtU'
    cipher = OpenSSL::Cipher.new 'AES-128-CBC'
    cipher.decrypt
    cipher.pkcs5_keyivgen pass_phrase, salt
    plain = cipher.update encrypted
    plain << cipher.final
    # OpenSSL::Cipher::CipherError: bad decrypt

    return plain
end

def start_ripl
    Ripl.start :binding => binding
end

def get_dot_path(sfx)
    dot_dir = File.expand_path('~/.vimamsa')
    Dir.mkdir(dot_dir) unless File.exist?(dot_dir)
    dpath = "#{dot_dir}/#{sfx}"
    return dpath
end

def save_buffer_list()
    message("Save buffer list")
    buffn = get_dot_path('buffers.txt')
    f = File.open(buffn, 'w')
    bufstr = $buffers.collect {|buf| buf.fname}.inspect
    f.write(bufstr)
    f.close()
end

def load_buffer_list()
    message("Load buffer list")
    buffn = get_dot_path('buffers.txt')
    return if !File.exist?(buffn)
    bufstr = IO.read(buffn)
    buflist = eval(bufstr)
    puts buflist
    for buf in buflist
        load_buffer(buf) if buf != nil and File.file?(buf)
        puts buf
    end
end

def start_ripl
    Ripl.start :binding => binding
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
    tmpf = Tempfile.new('ack', '/tmp').path
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
    $c=$register[char]
    message("Paste: #{$c}")
end





#vimamsa_init


t1 = Thread.new{main_loop}
t1.join
debug("END")
