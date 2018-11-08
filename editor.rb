

$:.unshift File.dirname(__FILE__) + "/lib"
require 'pathname'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Globals
$last_event = []
$command_history = []
$clipboard = []
$cnf = {}
$search_dirs=['.']

$do_center = 0
$cpos = 0
$lpos = 0
$larger_cpos = 0
$cur_line = nil
$input_char_call_func = nil
$check_modifiers = false
$search_indexes = []

$paint_stack = []
$jump_sequence = []

require 'fileutils'
require 'viwbaw/macro'
require 'viwbaw/buffer'
require 'viwbaw/search'
require 'viwbaw/key_bindings'
require 'viwbaw/hook'
require 'viwbaw/buffer_select'
require 'viwbaw/file_finder'

$macro = Macro.new
$search = Search.new
$hook = Hook.new

COMMAND = 1
INSERT = 2
BROWSE = 3
VISUAL = 4
MINIBUFFER = 5
READCHAR = 6

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
    $clipboard << s
    set_system_clipboard(s)
    puts "SET CLIPBOARD: [#{s}]"
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
    $at.set_mode(MINIBUFFER)
    $minibuffer = Buffer.new("", "")
    $minibuffer.call_func = method(:execute_search)
    #lambda { |input_str| $minibuffer }
    #$minibuffer = Buffer.new("/","")
end

def invoke_command()
    $at.set_mode(MINIBUFFER)
    $minibuffer = Buffer.new("", "")
    $minibuffer.call_func = method(:execute_command)
    #TODO
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

    unless content.valid_encoding? # take a guess
        GUESS_ENCODING_ORDER.find {|enc|
            content.force_encoding(enc)
            content.valid_encoding?
        }
        content.encode!(Encoding::UTF_8)
    end

    return content
    #return content.chomp #TODO:? chomp needed?
end

def create_new_file(filename = nil, file_contents = "\n")
    puts "NEW FILE CREATED"
    buffer = Buffer.new(file_contents)
    $buffers << buffer
end

def load_buffer(fname)
    return if !File.exist?(fname)
    return if $buffers.get_buffer_by_filename(fname) != nil
    puts "LOAD BUFFER: #{fname}"
    buffer = Buffer.new(read_file("", fname), fname)
    $buffers << buffer
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
        #buffer = Buffer.new(read_file("",$fname), filename)
        #$buffers << buffer
    end
    set_window_title("VIwbaw - #{File.basename(filename)}")
    render_buffer #TODO: needed?
end


def debug_print_buffer()
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

    puts "Render time: #{Time.now - t1}" if Time.now - t1 > 1/50.0
    $buffer.set_redrawed if reset == 1
end

def viwbaw_init
    puts "ARGV"
    puts ARGV.inspect
    build_key_bindings_tree
    puts "START reading file"
    sleep(0.03)
    $fname = "test.txt"
    $fname = ARGV[1] if ARGV.size >= 2
    buffer = Buffer.new(read_file("",$fname),$fname)
    $buffers << buffer
    puts $at # key map
    dotfile = read_file("", '~/.viwbawrc')
    eval(dotfile) if dotfile
    render_buffer($buffer, 1)

    gui_select_buffer_init
    gui_file_finder_init
end

def debug(message)
    puts message
    $stdout.flush
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
    return plain
end

def start_ripl
    Ripl.start :binding => binding
end

def get_dot_path(sfx)
    dot_dir = File.expand_path('~/.viwbaw')
    Dir.mkdir(dot_dir) unless File.exist?(dot_dir)
    dpath = "#{dot_dir}/#{sfx}"
    return dpath
end

def save_buffer_list()
    buffn = get_dot_path('buffers.txt')
    f = File.open(buffn, 'w')
    bufstr = $buffers.collect {|buf| buf.fname}.inspect
    f.write(bufstr)
    f.close()
end

def load_buffer_list()
    buffn = get_dot_path('buffers.txt')
    return if !File.exist?(buffn)
    bufstr = IO.read(buffn)
    buflist = eval(bufstr)
    puts buflist
    for buf in buflist
        load_buffer(buf)
        puts buf
    end
end

def start_ripl
    Ripl.start :binding => binding
end

#viwbaw_init


t1 = Thread.new{main_loop}
t1.join
debug("VIwbaw END")
