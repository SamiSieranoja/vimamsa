

$:.unshift File.dirname(__FILE__) + "/lib"
require 'pathname'


# Globals
$last_event = []
$command_history = []
$clipboard = []
$cnf = {}

$cpos = 0
$lpos = 0
$larger_cpos = 0
$cur_line = nil
$check_modifiers = false
$search_indexes = []


require 'viwbaw/macro'
require 'viwbaw/buffer'
require 'viwbaw/search'
require 'viwbaw/key_bindings'

$macro = Macro.new
$search = Search.new

COMMAND = 1
INSERT = 2
BROWSE = 3
VISUAL = 4
MINIBUFFER = 5

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
$minibuffer = Buffer.new(">","")

def _quit()
    # Shut down the Qt thread before the ruby thread
    qt_quit
    exit
end


def qt_signal(sgnname,param)
    puts "GOT QT-SIGNAL #{sgnname}: #{param}"
end

def system_clipboard_changed(clipboard_contents)
    max_clipboard_items=100
    $clipboard << clipboard_contents
    puts "DEBUG"
    puts $clipboard[-1]
    $clipboard = $clipboard[-([$clipboard.size,max_clipboard_items].min)..-1]
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
    $minibuffer = Buffer.new("","")
    $minibuffer.call_func = method(:execute_search)
    #lambda { |input_str| $minibuffer }
    #$minibuffer = Buffer.new("/","")
end

def invoke_command()
    $at.set_mode(MINIBUFFER)
    $minibuffer = Buffer.new("","")
    $minibuffer.call_func = method(:execute_command)
    #TODO
end

def execute_search(input_str)
    $search = Search.new
    $search.set(input_str,'simple',$buffer)
end

def execute_command(input_str)
    begin
        out_str = eval(input_str)
        $minibuffer.clear
        $minibuffer << out_str.to_s
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
def minibuffer_delete()
    $minibuffer.delete(BACKWARD_CHAR)
end


def message(s)
    $minibuffer = Buffer.new(s,"")
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
    encoding = text.encoding
    content = path.open("r:#{encoding.name}"){|io| io.read }

    unless content.valid_encoding? # take a guess
        GUESS_ENCODING_ORDER.find{|enc|
            content.force_encoding(enc)
            content.valid_encoding?
        }
        content.encode!(Encoding::UTF_8)
    end

    return content.chomp
end

def new_file_opened(filename,file_contents)
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
        buffer = Buffer.new(read_file("",$fname),filename)
        $buffers << buffer
    end
    set_window_title("VIwbaw - #{File.basename(filename)}")
    render_buffer
end

def revert_buffer()
    $buffer = Buffer.new(read_file("",$fname),filename)
end

def debug_print_buffer()
    puts $buffer.inspect
    puts $buffer
end
def debug_dump_clipboard()
    puts $clipboard.inspect
end


def save_file()
    $buffer.save()
end

def render_buffer(buffer=0,reset=0)
    tmpbuf = $buffer.to_s
    puts "lpos:#{$lpos} cpos:[#{$cpos}]"
    pos = $buffer.pos
    puts "rendbff: #{pos}lpos:#{$buffer.lpos} cpos:#{$buffer.cpos}"
    selection_start = $buffer.selection_start
    reset = 1 if $buffer.need_redraw?
    t1 = Time.now
    render_text(tmpbuf,pos,selection_start,reset)
    puts "Render time: #{Time.now - t1}" if Time.now - t1 > 1/50.0
    $buffer.set_redrawed if reset == 1
end

def viwbaw_init
    puts "ARGV"
    puts ARGV.inspect
    build_key_bindings_tree2
    puts "START reading file"
    sleep(0.03)
    $fname = "test.txt"
    $fname = ARGV[1] if ARGV.size >= 2
    buffer = Buffer.new(read_file("",$fname),$fname)
    $buffers << buffer
    puts $at # key map
    render_buffer($buffer,1) 
end

def debug(message)
    puts message
    $stdout.flush
end



# TODO: implement in buffer.rb
#def delete_next_word()
    #l = Line.new($buffer[$lpos])
    #next_pos = 0
    #l.wemarks.each {|m| next_pos = m
        #break if m > $cpos
    #}

    #if $buffer[$lpos][$cpos] != "\n" and next_pos >= $cpos
        #$buffer[$lpos].slice!($cpos..next_pos)
    #end
#end

def encrypt(text,pass_phrase)
    salt = 'uvgixEtU'
    cipher = OpenSSL::Cipher.new 'AES-128-CBC'
    cipher.encrypt
    cipher.pkcs5_keyivgen pass_phrase, salt
    encrypted = cipher.update text
    encrypted << cipher.final
    return encrypted
end

def decrypt(encrypted,pass_phrase)
    salt = 'uvgixEtU'
    cipher = OpenSSL::Cipher.new 'AES-128-CBC'
    cipher.decrypt
    cipher.pkcs5_keyivgen pass_phrase, salt
    plain = cipher.update encrypted
    plain << cipher.final
    return plain
end


#viwbaw_init


t1=Thread.new{main_loop}
t1.join
debug("VIwbaw END")

