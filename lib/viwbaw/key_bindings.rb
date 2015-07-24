

# This file has everyting related to binding key (and other) events
# into actions.

#TODO: override default bindings with data from ~/.viwbaw

# First letter is mode (C=Command, I=Insert)
# 
#
# Examples:
#
# Change mode from insert into COMMAND when shift key is released immediately
# after it has been pressed (there are no other key events between key press and key release).
#    'I shift!'=> 'change_mode(COMMAND)',
#
# In command mode: press keys "," "r" "v" and "b" sequentially.
# 'C , r v b'=> 'revert_buffer',
#
# In insert mode: press and hold ctrl, press "a"
# 'I ctrl-a'=> '$buffer.jump(BEGINNING_OF_LINE)',
#


# The default keymap
$cnf = {}#TODO

$cnf['key_bindigs'] = {
    #'C q'=> 'quit',

    # File handling
    'C ctrl-s'=> 'save_file',
    'C W'=> 'save_file',
    'C , s a'=> 'save_file_as', #TODO
    'C , f o' => 'open_file_dialog',
    'CI ctrl-o' => 'open_file_dialog',
    #'C a'=> 'txt.goto_line_start',
    #'C e'=> 'txt.goto_line_end',

    'C B'=> '$buffers.switch',
    'C , r v b'=> 'revert_buffer',

    # MOVING
    'VC h'=> '$buffer.move(BACKWARD_CHAR)',
    'VC l'=> '$buffer.move(FORWARD_CHAR)',
    'VC j'=> '$buffer.move(FORWARD_LINE)',
    'VC k'=> '$buffer.move(BACKWARD_LINE)',

    'VC left'=> '$buffer.move(BACKWARD_CHAR)',
    'VC right'=> '$buffer.move(FORWARD_CHAR)',
    'VC down'=> '$buffer.move(FORWARD_LINE)',
    'VC up'=> '$buffer.move(BACKWARD_LINE)',

    'VC w'=> '$buffer.jump_word(FORWARD,WORD_START)',
    'VC b'=> '$buffer.jump_word(BACKWARD,WORD_START)',
    'VC e'=> '$buffer.jump_word(FORWARD,WORD_END)',
#    'C '=> '$buffer.jump_word(BACKWARD,END)',#TODO
    'VC f <char>'=> '$buffer.jump_to_next_instance_of_char(<char>)',
    'VC F <char>'=> '$buffer.jump_to_next_instance_of_char(<char>,BACKWARD)',
    'VC /' => 'invoke_search',
    'VC /[1-9]/'=> 'set_next_command_count(<char>)',
    'VC ^'=> '$buffer.jump(BEGINNING_OF_LINE)',
    'VC 0($next_command_count!=nil)'=> 'set_next_command_count(<char>)',
    'VC 0($next_command_count==nil)'=> '$buffer.jump(BEGINNING_OF_LINE)',
    #'C 0'=> '$buffer.jump(BEGINNING_OF_LINE)',
    'VC g g'=> '$buffer.jump(START_OF_BUFFER)',
    'VC G'=> '$buffer.jump(END_OF_BUFFER)',
    'C , D'=> 'debug_print_buffer',#TODO:binding does not work?
    'C , d b'=> 'debug_print_buffer',
    'C , d c'=> 'debug_dump_clipboard',
    'VC O'=> '$buffer.jump(END_OF_LINE)',
    'VC $'=> '$buffer.jump(END_OF_LINE)',

    'C o' => '$buffer.jump(END_OF_LINE);$buffer.insert_char("\n");$at.set_mode(INSERT)',
    'C A' => '$buffer.jump(END_OF_LINE);$at.set_mode(INSERT)',
    'C a' => '$buffer.move(FORWARD_CHAR);$at.set_mode(INSERT)',
    'C J' => '$buffer.join_lines()',


    'C ^'=> '$buffer.jump(BEGINNING_OF_LINE)',
    'C /[1-9]/'=> 'set_next_command_count(<char>)',

    # Command mode only:
   'C r <char>'=> 'replace_char(<char>)',
   'C v'=> '$buffer.start_visual_mode', 
   'C p'=> '$buffer.paste', #TODO: implement as replace for visual mode
   'C space <char>' => '$buffer.insert_char(<char>)',
    #### Deleting
    'C x' =>'$buffer.delete(CURRENT_CHAR_FORWARD)',
    'C d k'=> 'delete_line(BACKWARD)', #TODO
    'C d j'=> 'delete_line(FORWARD)', #TODO
    'C d d'=> '$buffer.delete_cur_line',
    'C d w'=> 'delete_next_word', 
    'C d e'=> 'delete_next_word', 
    'C d <num> e'=> 'delete_next_word', 

    #'C 0($next_command_count==nil)'=> 'jump_to_beginning_of_line',

    # Visual mode only:
    'V esc'=> '$buffer.end_visual_mode', 
    'V y'=> '$buffer.copy_active_selection', #TODO: s/C/V/
    'V d'=> '$buffer.delete(SELECTION)', #TODO: s/C/V/

    'CI ctrl-v'=> '$buffer.paste', 
    'CI backspace' =>'$buffer.delete(BACKWARD_CHAR)',

    #'C space' => '$buffer.insert_char(" ")',
    #'C r <char>' => 'replace_char',

    #'CI backspace' =>'delete_backwards', #TODO
    #'C backspace' =>'$buffer.delete(CURRENT_CHAR_BACKWARD)',

    #'C o'=> 'open_new_line', #TODO

    # Marks
    'CV m <char>'=> 'mark_current_position', #TODO
    'CV \' <char>' =>'jump_to_mark(<char>)', #TODO
    "CV ''" =>'jump_to_mark(NEXT_MARK)', #TODO

    
    # Macros
    'C i'=> '$at.set_mode(INSERT)', #TODO: implement for visual mode?
    'C ctrl!'=> '$at.set_mode(INSERT)',
    'C q a'=> '$macro.start_recording("a")',
    'C q($macro.is_recording==true) '=> '$macro.end_recording', #TODO
    #'C q'=> '$macro.end_recording', #TODO
    'C q v'=> '$macro.end_recording',
    #'C v'=> '$macro.end_recording',
    'C R'=> '$macro.run_macro("a")',
    #'C <number>'=> 'repeat_next(<number>)',

    # Text transform
    #'C g U w' => 'upper_case(WORD)', #TODO
    'C .' => 'repeat_last_action',
    'CV Q' => '_quit',
    'CV , R' => 'restart_application',
    'I C^{last_down_key=C}'=> 'change_mode(COMMAND)',
    'I ctrl!'=> '$at.set_mode(COMMAND)',
    'I shift!'=> '$at.set_mode(COMMAND)',
    'I <char>'=> '$buffer.insert_char(<char>)',
    'I esc'=> '$at.set_mode(COMMAND)',
    
    #'C ; Ctrl!'=> 'change_mode(COMMAND)',


    'I ctrl-d'=> 'delete(1)', #TODO
    
    # INSERT MODE: Moving
    'I ctrl-a'=> '$buffer.jump(BEGINNING_OF_LINE)',
    'I ctrl-b'=> '$buffer.move(BACKWARD_CHAR)',
    'I ctrl-f'=> '$buffer.move(FORWARD_CHAR)',
    'I ctrl-n'=> '$buffer.move(FORWARD_LINE)',
    'I ctrl-p'=> '$buffer.move(BACKWARD_LINE)',
    'I ctrl-e'=> '$buffer.jump(END_OF_LINE)', #context: mode:I, buttons down: {C}
    'I alt-f'=> '$buffer.jump_word(FORWARD,WORD_START)',
    'I alt-b'=> '$buffer.jump_word(BACKWARD,WORD_START)',
    #'I l{S,C}'=> 'jump_line_end', #context: mode:I, buttons down: {C}

   #'I Ctrl(j l)' # Press and hold control, press J, press l
    #'I Ctrl(j(l))'# Press and hold control, press and hold J, press and hold L

    #'C w'=> ('txt.move',sje.FORWARD,sje.WORD),
    #'C b'=> 'txt.move_backward_word',

    #'C o'=> ('txt.insert_new_line',sje.BELOW),
    #'C O'=> ('txt.insert_new_line',sje.ABOVE),
    #'C d h'=> ('txt.delete',sje.BACKWARD),
    #'C d l'=> ('txt.delete',sje.FORWARD),
    #'C d j'=> ('txt.delete',sje.BELOW),
}

class State
    attr_accessor :key_name, :eval_rule, :children, :action
    def initialize(key_name,eval_rule="")
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
        @root.children << @C << @I << @V
        @cur_state = @root #used for building the tree
        @match_state = [@C] #used for matching input
        @mode_root_state = @C

    end
    def find_state(key_name,eval_rule)
        @cur_state.children.each{|s|
            if s.key_name == key_name and s.eval_rule == eval_rule
                #TODO check eval
                return s
            end
        }
        return nil
    end
    def match(key_name)
        new_state = []
        @match_state.each{|parent|
            parent.children.each{|c|
                #puts [c.key_name, key_name].inspect
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
            #return true
        else # No match found
            #@match_state = [@C] #TODO
            return nil
        end

    end
    def set_mode(mode)
        @mode_root_state = @C if mode == COMMAND
        @mode_root_state = @I if mode == INSERT
        @mode_root_state = @V if mode == VISUAL

    end
    def set_state(key_name,eval_rule="")
        new_state = find_state(key_name,eval_rule)
        if new_state != nil
            @cur_state = new_state
        else
            @cur_state = @mode_root_state #TODO
        end
    end
    def set_state_to_root
        @match_state = [@mode_root_state]
        #$next_command_count = nil # TODO: set somewhere else?
    end

    def to_s()
        s = ""
        #@cur_state = @root
        stack = [[@root,"#"]]
        while stack.any?
            t,p = *stack.pop #t = current state, p = current path
            if t.children.any?
                t.children.each{|c|
                    if c.eval_rule.size > 0
                        new_p = "#{p} -> #{c.key_name}(#{c.eval_rule})"
                    else
                        new_p = "#{p} -> #{c.key_name}"
                    end
                    stack << [c,new_p]
                }
                #stack.concat[t.children]
            else
                s += p +" : #{t.action}\n"

            end

        end
        return s
    end
end

def build_key_bindings_tree2
    #$context = {mode:'C',last_down_key:nil,input:{}}
    $at = AutomataTree.new()
    #$key_bind_dict = {}
    #$cur_key_dict = {}
    $cnf['key_bindigs'].each {|key, value|
        #dict_i = $key_bind_dict
        k_arr = key.split
        modes = k_arr.shift # modes = "C" or "I" or "CI"
        modes.each_char{|m|
            $at.set_state(m,"") #TODO: check is ok?


            k_arr.each { |i|
                #check if key has rules for context like q has in
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
                s1 = $at.find_state(key_name,eval_rule)
                #if key_name == "0"
                    #puts "KEY0"
                    #puts s1
                #end
                if s1 == nil
                    new_state = State.new(key_name,eval_rule)
                    $at.cur_state.children << new_state
                end

                $at.set_state(key_name,eval_rule) #TODO: check is ok?
            }
            $at.cur_state.action = value
            $at.cur_state = $at.root
        }

    }
end


if __FILE__ == $PROGRAM_NAME

    build_key_bindings_tree2
    puts $at
    exit
    

    #b.foo
    #puts b.line(2)
end





# Build tree shaped automata that matches key event inputs to actions
def build_key_bindings_tree
    $context = {mode:'C',last_down_key:nil,input:{}}
    $key_bind_dict = {}
    $cur_key_dict = {}
    $cnf['key_bindigs'].each {|key, value|
        #dict_i = $key_bind_dict
        k_arr = key.split
        modes = k_arr.shift # modes = "C" or "I" or "CI"
        modes.each_char{|m| 
            dict_i = $key_bind_dict
            dict_i[m] = {} if !dict_i.include?(m)
            dict_i = dict_i[m]
            k_arr.each { |i|
                dict_i[i] = {} if !dict_i.include?(i)
                #m = method("foo"); m.call(*params)
                #match /(\w)-(\w)/ context: 
                dict_i = dict_i[i]
            }
            dict_i['action'] = value
        }

    }
    puts $key_bind_dict.inspect

$cur_key_dict = $key_bind_dict['C']
end



# ref: http://qt-project.org/doc/qt-5.0/qtcore/qt.html#Key-enum
#Qt::Key_Enter
#Qt::Key_Return
#Qt::Key_Tab
#Qt::Key_Meta
$event_keysym_translate_table = {
    Qt::Key_Backspace	=> "backspace",
    Qt::Key_Space => "space",
    Qt::Key_Control  => "ctrl",
    Qt::Key_Alt  => "alt",
    Qt::Key_Escape  => "esc",
    Qt::Key_Up  => "up",
    Qt::Key_Down  => "down",
    Qt::Key_Left  => "left",
    Qt::Key_Right  => "right",
    Qt::Key_Shift  => "shift"
};


def match_key_conf(c,translated_c,event_type)
    #$cur_key_dict = $key_bind_dict[$context[:mode]]
    print "MATCH KEY CONF: #{[c,translated_c]}"

    #Sometimes we get ASCII-8BIT although actually UTF-8
    c=c.force_encoding("UTF-8"); #TODO:correct?

    #found_match =
    eval_s = nil
    new_state = $at.match(c)
    if new_state == nil
        new_state = $at.match(translated_c)
    end
    #if new_state == nil
        #new_state = $at.match(translated_c)
    #end

    if new_state == nil
        s1 = $at.match_state[0].children.select{|s| s.key_name.include?('<char>')} #TODO: [0]
        if s1.any? and (c.size == 1) and event_type == KEY_PRESS
            eval_s = s1.first.action.clone
            #eval_s.gsub!("<char>","'#{c}'") #TODO: remove
            new_state = [s1.first]
        end
    end


    if new_state == nil
        #Child is regexp like /[1-9]/ in:
        #'C /[1-9]/'=> 'set_next_command_count(<char>)',
        #Execute child regexps one until matches
        s1 = $at.match_state[0].children.select{|s|
            s.key_name =~ /^\/.*\/$/
            } #TODO: [0]

            if s1.any? and c.size == 1
                s1.each{|x|

                    m = /^\/(.*)\/$/.match(x.key_name)
                    if m != nil
                        m2 = Regexp.new(m[1]).match(c)
                        if m2 != nil
                            eval_s = x.action.clone
                            #eval_s.gsub!("<char>","'#{c}'") #TODO: remove
                            new_state = [x]
                            break
                        end

                        return true
                    end

            }
            #eval_s = s1.first.action.clone
            #eval_s.gsub!("<char>","'#{c}'")
            #new_state = [s1.first]
        end
    end


    if new_state == nil
        printf("NO MATCH")
        if event_type == KEY_PRESS and translated_c != 'shift'
            #TODO:include other modifiers in addition to shift?
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
        s_act = new_state.select{|s| s.action != nil}
        if s_act.any?
            eval_s = s_act.first.action if eval_s == nil
            puts "FOUND MATCH:#{eval_s}"
            puts "CHAR: #{c}"
            c.gsub!("'","#{'\\'*4}'") # Escape ' -chars
            eval_s.gsub!("<char>","'#{c}'")
            handle_key_bindigs_action(eval_s,c)
            $at.set_state_to_root
        end

    end

    #elsif $cur_key_dict.include?('<char>') and c.size == 1
        #$cur_key_dict = $cur_key_dict['<char>']
        ##$context[:input] << c
        #eval_s = $cur_key_dict['action'].clone
        #eval_s.gsub!("<char>","'#{c}'")
    #else
        #$cur_key_dict = $key_bind_dict[$context[:mode]] if event_type == KEY_PRESS
        #return false
    #end


    return true

 end


def handle_key_bindigs_action(action,c)
    n = 1
    if $next_command_count and !action.include?("set_next_command_count")
        n = $next_command_count
        $next_command_count = nil
        debug("COUNT command #{n} times")
    end

    begin
        n.times do
            if $macro.is_recording
                eval(action)
                $macro.record_action(action)
            else #TODO: try catch eval errors?
                eval(action)
            end
        end

    rescue SyntaxError
        debug("SYNTAX ERROR with eval cmd #{action}: " + $!.to_s)
    rescue NoMethodError
        debug("NoMethodError with eval cmd #{action}: " + $!.to_s)
    rescue NameError
        #raise
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
    #$keys_pressed = [] 
    $check_modifiers = true
    # TODO: Clear key binding matching?
end

def change_mode(mode)
    debug("CHANGING MODE FROM #{$context[:mode]} TO #{mode}")
    $context[:mode] = "C" if mode == COMMAND
    $context[:mode] = "I" if mode == INSERT
    $context[:mode] = "B" if mode == BROWSE
    $context[:mode] = "V" if mode == VISUAL
end


#$active_modifiers = {ctrl: false, shift: false, 
$keys_pressed = [] #TODO: create a queue

def handle_key_event(event)
    #puts "GOT KEY EVENT: #{key.inspect}"
    debug "GOT KEY EVENT:: #{event} #{event[2]}"

    t1 = Time.now
    event[3] = event[2]

    if($check_modifiers or true) #TODO: rely on check_modifiers?
       # debug("CHECKING key modifiers")

#        debug($keys_pressed)
       $keys_pressed.delete(Qt::Key_Alt) if event[4] & ALTMODIFIER == 0
       $keys_pressed.delete(Qt::Key_Control) if event[4] & CONTROLMODIFIER == 0
       $keys_pressed.delete(Qt::Key_Shift) if event[4] & SHIFTMODIFIER == 0
       $check_modifiers = false
       #TODO: other modifiers
    end

    $keys_pressed << event[0] if event[1] == KEY_PRESS \
        and !$keys_pressed.include?(event[0])
    $keys_pressed.delete(event[0]) if event[1] == KEY_RELEASE

    #$keys_pressed[event[0]] = true if event[1] == "KEY_PRESS"
    #$keys_pressed[event[0]] = false if event[1] == "KEY_RELEASE"

    # TODO
    #if $keys_pressed.any?
        #uval = keyval_to_unicode(event[0])
        #event[3] = [uval].pack('c*').force_encoding('UTF-8') #TODO: 32bit?
        #debug("key_code_to_uval: uval: #{uval} uchar:#{event[3]}")
    #end
    key_prefix = ""
    $keys_pressed.each {|pressed_key|
        if $event_keysym_translate_table[pressed_key]
            key_prefix += $event_keysym_translate_table[pressed_key] + "-"
        end
    }
    event[3] = key_prefix+event[3]

    #if $keys_pressed[GDK_KEY_Control_L]
    #uval = keyval_to_unicode(event[0])
    #event[3] = [uval].pack('c*').force_encoding('UTF-8') #TODO: 32bit?
    #debug("key_code_to_uval: uval: #{uval} uchar:#{event[3]}")
    #event[3] = "ctrl-"+event[3]
    #end

    if $event_keysym_translate_table.include?(event[0])
        event[3] = $event_keysym_translate_table[event[0]]
    end

    if event[2] != "" or event[3] != ""
        if event[0] == $last_event[0] and event[1] == KEY_RELEASE
            match_key_conf(event[2]+"!",event[3]+"!",event[1])
        else
            match_key_conf(event[2],event[3],event[1]) if event[1] == KEY_PRESS
        end
        $last_event = event
    end

    event_handle_time = Time.now - t1
    debug "RB key event handle time: #{event_handle_time}" if event_handle_time > 1/40.0
    render_buffer($buffer)
  
end

