# This file has everyting related to binding key (and other) events
# into actions.

# First letter is mode (C=Command, I=Insert, V=Visual)
#
# Examples:
#
# Change mode from INSERT into COMMAND when ctrl key is released immediately
# after it has been pressed (there are no other key events between key press and key release).
#        'I ctrl!'=> '$at.set_mode(COMMAND)',
#        'C ctrl!'=> '$at.set_mode(INSERT)',

#
# In command mode: press keys "," "r" "v" and "b" sequentially.
# 'C , r v b'=> 'revert_buffer',
#
# In insert mode: press and hold ctrl, press "a"
# 'I ctrl-a'=> '$buffer.jump(BEGINNING_OF_LINE)',
#

# The default keymap
$cnf = {} # TODO


def conf(id)
return $cnf[id]
end
def set_conf(id,val)
   $cnf[id] = val
end

set_conf(:indent_based_on_last_line, true)
$cnf[:extensions_to_open] = [".txt",".h",".c",".cpp",".hpp",".rb",".inc",".php",".sh",".m"]


$cnf['modes'] = { 'R' => 'READCHAR', 'M' => 'MINIBUFFER', 'C' => 'COMMAND', 'V' => 'VISUAL', 'I' => 'INSERT', 'B'=>'BROWSE' }

$cnf['key_bindigs'] = {
    # 'C q'=> 'quit',

    # File handling
    'C ctrl-s' => 'save_file',
    'C W' => 'save_file',
    #    'C , s a'=> 'save_file_as', #TODO
    'C , f o' => 'open_file_dialog',
    'C , o' => 'open_file_dialog',
    'CI ctrl-o' => 'open_file_dialog',

    # Buffer handling
    'C B' => '$buffers.switch',
    'C tab' => '$buffers.switch_to_last_buf',
    #    'C , s'=> 'gui_select_buffer',
    'C , f f' => 'gui_file_finder',
    'C , r v b' => '$buffer.revert',
    'C , c b' => '$buffers.close_current_buffer',
    'C , b' => '$at.set_mode("S");gui_select_buffer',
    'C , n b' => 'create_new_file()',
    'C , .' => '$buffer.backup()',
    'C , , .' => 'backup_all_buffers()',
    'C , a' => 'invoke_ack_search()',
    'C enter' => '$buffer.get_cur_word()',
    'C return' => '$buffer.get_cur_nonwhitespace_word()',


    # MOVING
#    'VC h' => '$buffer.move(BACKWARD_CHAR)',
    'VC l' => '$buffer.move(FORWARD_CHAR)',
    'VC j' => '$buffer.move(FORWARD_LINE)',
    'VC k' => '$buffer.move(BACKWARD_LINE)',
    'VC pagedown' => '$buffer.move(:forward_page)',
    'VC pagedown!' => 'top_where_cursor()',

    'VC pageup' => '$buffer.move(:backward_page)', # TODO
    'VC pageup!' => 'bottom_where_cursor()', # TODO

    'VC left' => '$buffer.move(BACKWARD_CHAR)',
    'VC right' => '$buffer.move(FORWARD_CHAR)',
    'VC down' => '$buffer.move(FORWARD_LINE)',
    'VC up' => '$buffer.move(BACKWARD_LINE)',

    'VC w' => '$buffer.jump_word(FORWARD,WORD_START)',
    'VC b' => '$buffer.jump_word(BACKWARD,WORD_START)',
    'VC e' => '$buffer.jump_word(FORWARD,WORD_END)',
    #    'C '=> '$buffer.jump_word(BACKWARD,END)',#TODO
    'VC f <char>' => '$buffer.jump_to_next_instance_of_char(<char>)',
    'VC F <char>' => '$buffer.jump_to_next_instance_of_char(<char>,BACKWARD)',
    'VC /[1-9]/' => 'set_next_command_count(<char>)',
    #    'VC number=/[0-9]/+ g'=> 'jump_to_line(<number>)',
    #    'VC X=/[0-9]/+ * Y=/[0-9]/+ '=> 'x_times_y(<X>,<Y>)',
    'VC G($next_command_count!=nil)' => '$buffer.jump_to_line()',
    'VC ^' => '$buffer.jump(BEGINNING_OF_LINE)',
    'VC 0($next_command_count!=nil)' => 'set_next_command_count(<char>)',
    'VC 0($next_command_count==nil)' => '$buffer.jump(BEGINNING_OF_LINE)',
    # 'C 0'=> '$buffer.jump(BEGINNING_OF_LINE)',
    'VC g g' => '$buffer.jump(START_OF_BUFFER)',
    'VC g ;' => '$buffer.jump_to_last_edit',
    'VC G' => '$buffer.jump(END_OF_BUFFER)',
#    'VC z z' => 'center_on_current_line',
    'VC *' => '$buffer.jump_to_next_instance_of_word',
    'C s' => 'easy_jump(:visible_area)',

    # MINIBUFFER bindings
    'VC /' => 'invoke_search',
    # 'VC :' => 'invoke_command', #TODO
    'VC , e' => 'invoke_command', # Currently eval
    'M enter' => 'minibuffer_end()',
    'M return' => 'minibuffer_end()',
    'M esc' => 'minibuffer_cancel()',
    'M backspace' => 'minibuffer_delete()',
    'M <char>' => 'minibuffer_new_char(<char>)',
    'M ctrl-v' => '$minibuffer.paste(BEFORE)',

    # READCHAR bindings

    'R <char>' => 'readchar_new_char(<char>)',

    'C n' => '$search.jump_to_next()',
    'C N' => '$search.jump_to_previous()',

    # Debug
    'C , d r p' => 'start_ripl',
    'C , c s' => '$buffers.close_scrap_buffers',
    'C , D' => 'debug_print_buffer',
    'C , d b' => 'debug_print_buffer',
    'C , d c' => 'debug_dump_clipboard',
    'C , d d' => 'debug_dump_deltas',
    'VC O' => '$buffer.jump(END_OF_LINE)',
    'VC $' => '$buffer.jump(END_OF_LINE)',

    'C o' => '$buffer.jump(END_OF_LINE);$buffer.insert_char("\n");$at.set_mode(INSERT)',
    'C X' => '$buffer.jump(END_OF_LINE);$buffer.insert_char("\n");',
    'C A' => '$buffer.jump(END_OF_LINE);$at.set_mode(INSERT)',
    'C I' => '$buffer.jump(FIRST_NON_WHITESPACE);$at.set_mode(INSERT)',
    'C a' => '$buffer.move(FORWARD_CHAR);$at.set_mode(INSERT)',
    'C J' => '$buffer.join_lines()',
    'C u' => '$buffer.undo()',

    'C ^' => '$buffer.jump(BEGINNING_OF_LINE)',
    'C /[1-9]/' => 'set_next_command_count(<char>)',

    # Command mode only:
    'C ctrl-r' => '$buffer.redo()', # TODO:???
    'C R' => '$buffer.redo()',
    'C v' => '$buffer.start_visual_mode',
    'C p' => '$buffer.paste(AFTER)', # TODO: implement as replace for visual mode
    'C P' => '$buffer.paste(BEFORE)', # TODO: implement as replace for visual mode
    'C space <char>' => '$buffer.insert_char(<char>)',
    'C y y' => '$buffer.copy_line',
    'C y O' => '$buffer.copy(:to_line_end)',
    'C y 0' => '$buffer.copy(:to_line_start)',
    'C y e' => '$buffer.copy(:to_word_end)', # TODO
    #### Deleting
    'C x' => '$buffer.delete(CURRENT_CHAR_FORWARD)',
    # 'C d k'=> 'delete_line(BACKWARD)', #TODO
    # 'C d j'=> 'delete_line(FORWARD)', #TODO
    # 'C d d'=> '$buffer.delete_cur_line',
    'C d d' => '$buffer.delete_line',
    'C d w' => '$buffer.delete2(:to_word_end)',
    'C d e' => '$buffer.delete2(:to_word_end)',
    'C d O' => '$buffer.delete2(:to_line_end)',
    'C d $' => '$buffer.delete2(:to_line_end)',
    'C d 0' => '$buffer.delete2(:to_line_start)',
    #    'C d e'=> '$buffer.delete_to_next_word_end',
    'C d <num> e' => 'delete_next_word',
    'C r <char>' => '$buffer.replace_with_char(<char>)', # TODO
    'C , l b' => 'load_buffer_list',
    'C , l l' => 'save_buffer_list',

    'C ctrl-c' => '$buffer.comment_line()',
    'C ctrl-x' => '$buffer.comment_line(:uncomment)',

    # 'C 0($next_command_count==nil)'=> 'jump_to_beginning_of_line',

    # Visual mode only:
    'V esc' => '$buffer.end_visual_mode',
    'V ctrl!' => '$buffer.end_visual_mode',
    'V y' => '$buffer.copy_active_selection',
    'V d' => '$buffer.delete(SELECTION)',
    'V x' => '$buffer.delete(SELECTION)',
    'V ctrl-c' => '$buffer.comment_selection',
    'V ctrl-x' => '$buffer.comment_selection(:uncomment)',

    'CI ctrl-v' => '$buffer.paste(BEFORE)',
    'CI backspace' => '$buffer.delete(BACKWARD_CHAR)',

    # 'C space' => '$buffer.insert_char(" ")',
    # 'C r <char>' => 'replace_char',

    # 'CI backspace' =>'delete_backwards', #TODO
    # 'C backspace' =>'$buffer.delete(CURRENT_CHAR_BACKWARD)',

    # 'C o'=> 'open_new_line', #TODO

    # Marks
    'CV m <char>' => '$buffer.mark_current_position(<char>)', # TODO
    'CV \' <char>' => '$buffer.jump_to_mark(<char>)', # TODO
    # "CV ''" =>'jump_to_mark(NEXT_MARK)', #TODO

    'C i' => '$at.set_mode(INSERT)',
    'C ctrl!' => '$at.set_mode(INSERT)',

    # Macros
    'C q a' => '$macro.start_recording("a")',
    'C q($macro.is_recording==true) ' => '$macro.end_recording', # TODO
    # 'C q'=> '$macro.end_recording', #TODO
    'C q v' => '$macro.end_recording',
    # 'C v'=> '$macro.end_recording',
    'C M' => '$macro.run_macro("a")',
    'C , m s' => '$macro.save_macro("a")',
    'C , t r' => 'run_tests()',

    # 'C <number>'=> 'repeat_next(<number>)',

    # Text transform
    # 'C g U w' => 'upper_case(WORD)', #TODO
    'C .' => 'repeat_last_action',
    'C ;' => 'repeat_last_find',
    'CV Q' => '_quit',
    'CV , R' => 'restart_application',
    'I ctrl!' => '$at.set_mode(COMMAND)',
    'I shift!' => '$at.set_mode(COMMAND)',
    'C shift!' => 'save_file',
    'I <char>' => '$buffer.insert_char(<char>)',
    'I esc' => '$at.set_mode(COMMAND)',

    # 'C ; Ctrl!'=> 'change_mode(COMMAND)',

    'I ctrl-d' => '$buffer.delete(CURRENT_CHAR_FORWARD)',

    # INSERT MODE: Moving
    'I ctrl-a' => '$buffer.jump(BEGINNING_OF_LINE)',
    'I ctrl-b' => '$buffer.move(BACKWARD_CHAR)',
    'I ctrl-f' => '$buffer.move(FORWARD_CHAR)',
    'I ctrl-n' => '$buffer.move(FORWARD_LINE)',
    'I ctrl-p' => '$buffer.move(BACKWARD_LINE)',
    'I ctrl-e' => '$buffer.jump(END_OF_LINE)', # context: mode:I, buttons down: {C}
    'I alt-f' => '$buffer.jump_word(FORWARD,WORD_START)',
    'I alt-b' => '$buffer.jump_word(BACKWARD,WORD_START)',
    # 'I l{S,C}'=> 'jump_line_end', #context: mode:I, buttons down: {C}
    
    
    'I tab' => '$buffer.insert_char("    ")',
    

    # 'I Ctrl(j l)' # Press and hold control, press J, press l
    # 'I Ctrl(j(l))'# Press and hold control, press and hold J, press and hold L

}

class State
    attr_accessor :key_name, :eval_rule, :children, :action
    def initialize(key_name, eval_rule = "")
        @key_name = key_name
        @eval_rule = eval_rule
        @children = []
        @action = nil
    end

    def to_s()
        return @key_name
    end
end

class AutomataTree
    attr_accessor :C, :I, :cur_state, :root, :match_state
    def initialize()
        @root = State.new("ROOT")
        @C = State.new("C")
        @I = State.new("I")
        @V = State.new("V")
        @M = State.new("M")
        @R = State.new("R")
        @B = State.new("B")
        @root.children << @C << @I << @V << @M << @R << @B
        @cur_state = @root # used for building the tree
        @match_state = [@C] # used for matching input
        @mode_root_state = @C
        @mode_history = []
    end

    def add_mode(id)
        @mode = State.new(id)
        @root.children << @mode
    end

    def find_state(key_name, eval_rule)
        @cur_state.children.each { |s|
            if s.key_name == key_name and s.eval_rule == eval_rule
                # TODO check eval
                return s
            end
        }
        return nil
    end

    def match(key_name)
        new_state = []
        @match_state.each { |parent|
            parent.children.each { |c|
                # printf(" KEY MATCH: ")
                # puts [c.key_name, key_name].inspect
                if c.key_name == key_name and c.eval_rule == ""
                    new_state << c
                elsif c.key_name == key_name and c.eval_rule != ""
                    puts "CHECK EVAL: #{c.eval_rule}"
                    if eval(c.eval_rule)
                        new_state << c
                        puts "EVAL TRUE"
                    else
                        puts "EVAL FALSE"
                    end

                end
            }
        }
        if new_state.any? # Match found
            @match_state = new_state
            return new_state
            # return true
        else # No match found
            # @match_state = [@C] #TODO
            return nil
        end
    end

    def set_mode(mode_s)
        @mode_history << @mode_root_state
        @mode_root_state = @C if mode_s == COMMAND
        @mode_root_state = @I if mode_s == INSERT
        @mode_root_state = @V if mode_s == VISUAL
        @mode_root_state = @M if mode_s == MINIBUFFER
        @mode_root_state = @R if mode_s == READCHAR
        @mode_root_state = @B if mode_s == BROWSE
        for mode in @root.children
            if mode.key_name == mode_s
                @mode_root_state = mode
            end
        end
    end

    def is_command_mode()
        # debug $at.mode_root_state.inspect
        if @mode_root_state.to_s() == "C"
            debug "IS COMMAND MODE"
            return 1
        else
            debug "IS NOT COMMAND MODE"
            return 0
        end
    end
    
     def is_visual_mode()
        return 1 if @mode_root_state.to_s() == "V"
        return 0
    end   

    def set_state(key_name, eval_rule = "")
        new_state = find_state(key_name, eval_rule)
        if new_state != nil
            @cur_state = new_state
        else
            @cur_state = @mode_root_state # TODO
        end
    end

    def set_state_to_root
        @match_state = [@mode_root_state]
        # $next_command_count = nil # TODO: set somewhere else?
    end

    def to_s()
        s = ""
        # @cur_state = @root
        stack = [[@root, "#"]]
        while stack.any?
            t, p = *stack.pop # t = current state, p = current path
            if t.children.any?
                t.children.each { |c|
                    if c.eval_rule.size > 0
                        new_p = "#{p} -> #{c.key_name}(#{c.eval_rule})"
                    else
                        new_p = "#{p} -> #{c.key_name}"
                    end
                    stack << [c, new_p]
                }
                # stack.concat[t.children]
            else
                s += p + " : #{t.action}\n"

            end

        end
        return s
    end
end

def build_key_bindings_tree
    # $context = {mode:'C',last_down_key:nil,input:{}}
    $at = AutomataTree.new()
    # $key_bind_dict = {}
    # $cur_key_dict = {}
    $cnf['key_bindigs'].each { |key, value|
        bindkey(key, value)
    }
end

def bindkey(key, action)
    # dict_i = $key_bind_dict
    k_arr = key.split
    modes = k_arr.shift # modes = "C" or "I" or "CI"
    modes.each_char { |m|
        $at.set_state(m, "") # TODO: check is ok?

        k_arr.each { |i|
            # check if key has rules for context like q has in
            # "C q(cntx.recording_macro==true)"
            match = /(.+)\((.*)\)/.match(i)
            eval_rule = ""
            if match
                key_name = match[1]
                eval_rule = match[2]
            else
                key_name = i
            end

            # Create a new state for key if it doesn't exist
            s1 = $at.find_state(key_name, eval_rule)
            if s1 == nil
                new_state = State.new(key_name, eval_rule)
                $at.cur_state.children << new_state
            end

            $at.set_state(key_name, eval_rule) # TODO: check is ok?
        }
        $at.cur_state.action = action
        $at.cur_state = $at.root
    }
end

if __FILE__ == $PROGRAM_NAME

    build_key_bindings_tree
    puts $at
    exit
end

# ref: http://qt-project.org/doc/qt-5.0/qtcore/qt.html#Key-enum
# Qt::Key_Enter
# Qt::Key_Return
# Qt::Key_Tab
# Qt::Key_Meta
$event_keysym_translate_table = {
    Qt::Key_Backspace => "backspace",
    Qt::Key_Space => "space",
    Qt::Key_Control => "ctrl",
    Qt::Key_Alt => "alt",
    Qt::Key_Escape => "esc",
    Qt::Key_Up => "up",
    Qt::Key_Down => "down",
    Qt::Key_PageUp => "pageup",
    Qt::Key_PageDown => "pagedown",
    Qt::Key_Left => "left",
    Qt::Key_Right => "right",
    Qt::Key_Enter => "enter",
    Qt::Key_Return => "return",
    Qt::Key_Shift => "shift",
    Qt::Key_Tab => "tab"
};

$translate_table = {
    Qt::Key_A => "A",
    Qt::Key_B => "B",
    Qt::Key_C => "C",
    Qt::Key_D => "D",
    Qt::Key_E => "E",
    Qt::Key_F => "F",
    Qt::Key_G => "G",
    Qt::Key_H => "H",
    Qt::Key_I => "I",
    Qt::Key_J => "J",
    Qt::Key_K => "K",
    Qt::Key_L => "L",
    Qt::Key_M => "M",
    Qt::Key_N => "N",
    Qt::Key_O => "O",
    Qt::Key_P => "P",
    Qt::Key_Q => "Q",
    Qt::Key_R => "R",
    Qt::Key_S => "S",
    Qt::Key_T => "T",
    Qt::Key_U => "U",
    Qt::Key_V => "V",
    Qt::Key_W => "W",
    Qt::Key_X => "X",
    Qt::Key_Y => "Y",
    Qt::Key_Z => "Z",

};

def match_key_conf(c, translated_c, event_type)
    # $cur_key_dict = $key_bind_dict[$context[:mode]]
    print "MATCH KEY CONF: #{[c, translated_c]}"

    # Sometimes we get ASCII-8BIT although actually UTF-8
    c = c.force_encoding("UTF-8"); # TODO:correct?

    # found_match =
    eval_s = nil
    new_state = $at.match(translated_c)
    if new_state == nil and translated_c.index('shift') == 0
        new_state = $at.match(c)
    end
    # if new_state == nil
    # new_state = $at.match(translated_c)
    # end

    if new_state == nil
        s1 = $at.match_state[0].children.select { |s| s.key_name.include?('<char>') } # TODO: [0]
        if s1.any? and (c.size == 1) and event_type == KEY_PRESS
            eval_s = s1.first.action.clone
            # eval_s.gsub!("<char>","'#{c}'") #TODO: remove
            new_state = [s1.first]
        end
    end

    if new_state == nil
        # Child is regexp like /[1-9]/ in:
        # 'C /[1-9]/'=> 'set_next_command_count(<char>)',
        # Execute child regexps one until matches
        s1 = $at.match_state[0].children.select { |s|
            s.key_name =~ /^\/.*\/$/
        } # TODO: [0]

        if s1.any? and c.size == 1
            s1.each { |x|
                m = /^\/(.*)\/$/.match(x.key_name)
                if m != nil
                    m2 = Regexp.new(m[1]).match(c)
                    if m2 != nil
                        eval_s = x.action.clone
                        # eval_s.gsub!("<char>","'#{c}'") #TODO: remove
                        new_state = [x]
                        break
                    end

                    return true
                end
            }
            # eval_s = s1.first.action.clone
            # eval_s.gsub!("<char>","'#{c}'")
            # new_state = [s1.first]
        end
    end

    if new_state == nil
        printf("NO MATCH")
        if event_type == KEY_PRESS and translated_c != 'shift'
            # TODO:include other modifiers in addition to shift?
            $at.set_state_to_root
            printf(", BACK TO ROOT")
        end

        if event_type == KEY_RELEASE and translated_c == 'shift!'
            # Pressing a modifier key (shift) puts state back to root
            # only on key release when no other key has been pressed
            # after said modifier key (shift).
            $at.set_state_to_root
            printf(", BACK TO ROOT")
        end

        printf("\n")
    else
        s_act = new_state.select { |s| s.action != nil }
        if s_act.any?
            eval_s = s_act.first.action if eval_s == nil
            puts "FOUND MATCH:#{eval_s}"
            puts "CHAR: #{c}"
            c.gsub!("\\", %q{\\\\} * 4) # Escape \ -chars
            c.gsub!("'", "#{'\\' * 4}'") # Escape ' -chars
            
            eval_s.gsub!("<char>", "'#{c}'") if eval_s.class==String
            puts eval_s
            puts c
            handle_key_bindigs_action(eval_s, c)
            $at.set_state_to_root
        end

    end

    # elsif $cur_key_dict.include?('<char>') and c.size == 1
    # $cur_key_dict = $cur_key_dict['<char>']
    # #$context[:input] << c
    # eval_s = $cur_key_dict['action'].clone
    # eval_s.gsub!("<char>","'#{c}'")
    # else
    # $cur_key_dict = $key_bind_dict[$context[:mode]] if event_type == KEY_PRESS
    # return false
    # end

    return true
end

def handle_key_bindigs_action(action, c)
    $method_handles_repeat = false
    n = 1
    if $next_command_count and !action.include?("set_next_command_count")
        n = $next_command_count
        # $next_command_count = nil
        debug("COUNT command #{n} times")
    end

    begin
        n.times do
            if $macro.is_recording
                eval(action)
                $macro.record_action(action)
            else # TODO: try catch eval errors?
                if action.class == Symbol
                    call(action)
                else
                    eval(action)
                end
            end
            break if $method_handles_repeat
            # Some methods have specific implementation for repeat,
            #   like '5yy' => copy next five lines. (copy_line())
            # By default the same command is just repeated n times
            #   like '20j' => go to next line 20 times.
        end
    rescue SyntaxError
        debug("SYNTAX ERROR with eval cmd #{action}: " + $!.to_s)
        # rescue NoMethodError
        # debug("NoMethodError with eval cmd #{action}: " + $!.to_s)
        # rescue NameError
        # debug("NameError with eval cmd #{action}: " + $!.to_s)
        # raise
    end

    if action.class==String and !action.include?("set_next_command_count")
        $next_command_count = nil
    end
end

# When pressing for example alt-tab, the program receives key press
# event, loses focus and doesn't receive the key release event for alt.
# So we need to clear modifiers after focus out event.
#
# Another headache is that in Ubuntu 13.04 Unity interface the program loses
# focus (for a short time) every time you press alt key (for example alt-e
# in insert mode).
#
def focus_out
    # Clear ctrl, alt etc. modifers when widget loses focus.
    debug "RB Clear modifiers"
    $keys_pressed = []
    $check_modifiers = true
    # TODO: Clear key binding matching?
end

# def change_mode(mode)
# debug("CHANGING MODE FROM #{$context[:mode]} TO #{mode}")
# $context[:mode] = "C" if mode == COMMAND
# $context[:mode] = "I" if mode == INSERT
# $context[:mode] = "B" if mode == BROWSE
# $context[:mode] = "V" if mode == VISUAL
# end

# $active_modifiers = {ctrl: false, shift: false,
$keys_pressed = [] # TODO: create a queue

def handle_key_event(event)
    # puts "GOT KEY EVENT: #{key.inspect}"
    debug "GOT KEY EVENT:: #{event} #{event[2]}"

    t1 = Time.now
    event[3] = event[2]

    if ($check_modifiers or true) # TODO: rely on check_modifiers?
        # debug("CHECKING key modifiers")

        #        debug($keys_pressed)
        $keys_pressed.delete(Qt::Key_Alt) if event[4] & ALTMODIFIER == 0
        $keys_pressed.delete(Qt::Key_Control) if event[4] & CONTROLMODIFIER == 0
        $keys_pressed.delete(Qt::Key_Shift) if event[4] & SHIFTMODIFIER == 0
        $check_modifiers = false
        # TODO: other modifiers
    end

    $keys_pressed << Qt::Key_Alt if event[1] == KEY_PRESS \
    and !$keys_pressed.include?(Qt::Key_Alt) \
    and event[4] & ALTMODIFIER != 0 # Fix for alt lose focus problem.
    puts "----D------------"
    puts $keys_pressed.inspect
    puts event.inspect
    puts event[4] & ALTMODIFIER
    puts "-----------------"

    $keys_pressed << event[0] if event[1] == KEY_PRESS \
    and !$keys_pressed.include?(event[0])
    $keys_pressed.delete(event[0]) if event[1] == KEY_RELEASE

    $keys_pressed.delete(Qt::Key_Enter) # TODO: Delete after timeout?
    $keys_pressed.delete(Qt::Key_Return)

    # $keys_pressed[event[0]] = true if event[1] == "KEY_PRESS"
    # $keys_pressed[event[0]] = false if event[1] == "KEY_RELEASE"

    # TODO
    # if $keys_pressed.any?
    # uval = keyval_to_unicode(event[0])
    # event[3] = [uval].pack('c*').force_encoding('UTF-8') #TODO: 32bit?
    # debug("key_code_to_uval: uval: #{uval} uchar:#{event[3]}")
    # end
    key_prefix = ""
    $keys_pressed.each { |pressed_key|
        if $event_keysym_translate_table[pressed_key]
            key_prefix += $event_keysym_translate_table[pressed_key] + "-"
        end
    }
    if $translate_table.include?(event[0])
        event[3] = $translate_table[event[0]].downcase
        puts "Translated to: #{event[3]}"
    end
    event[3] = key_prefix + event[3]

    # if $keys_pressed[GDK_KEY_Control_L]
    # uval = keyval_to_unicode(event[0])
    # event[3] = [uval].pack('c*').force_encoding('UTF-8') #TODO: 32bit?
    # debug("key_code_to_uval: uval: #{uval} uchar:#{event[3]}")
    # event[3] = "ctrl-"+event[3]
    # end

    if $event_keysym_translate_table.include?(event[0])
        event[3] = $event_keysym_translate_table[event[0]]
    end

    if event[2] != "" or event[3] != ""
        if event[0] == $last_event[0] and event[1] == KEY_RELEASE
            match_key_conf(event[2] + "!", event[3] + "!", event[1])
        else
            match_key_conf(event[2], event[3], event[1]) if event[1] == KEY_PRESS
        end
        $last_event = event
    end

    event_handle_time = Time.now - t1
    debug "RB key event handle time: #{event_handle_time}" if event_handle_time > 1 / 40.0
    render_buffer($buffer)
end
