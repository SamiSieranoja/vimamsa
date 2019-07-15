# This file has everyting related to binding key (and other) events
# into actions.

# First letter is mode (C=Command, I=Insert, V=Visual)
#
# Examples:
#
# Change mode from INSERT into COMMAND when ctrl key is released immediately
# after it has been pressed (there are no other key events between key press and key release).
#        'I ctrl!'=> '$kbd.set_mode(:command)',
#        'C ctrl!'=> '$kbd.set_mode(:insert)',

#
# In command mode: press keys "," "r" "v" and "b" sequentially.
# 'C , r v b'=> 'revert_buffer',
#
# In insert mode: press and hold ctrl, press "a"
# 'I ctrl-a'=> '$buffer.jump(BEGINNING_OF_LINE)',
#

$cnf = {} # TODO

def conf(id)
  return $cnf[id]
end

def set_conf(id, val)
  $cnf[id] = val
end

def setcnf(id, val)
  set_conf(id, val)
end

setcnf :indent_based_on_last_line, true
setcnf :extensions_to_open, [".txt", ".h", ".c", ".cpp", ".hpp", ".rb", ".inc", ".php", ".sh", ".m", ".gd"]

class State
  attr_accessor :key_name, :eval_rule, :children, :action, :label

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

class KeyBindingTree
  attr_accessor :C, :I, :cur_state, :root, :match_state, :last_action, :cur_action
  attr_reader :mode_root_state, :state_trail

  def initialize()
    @modes = {}
    @root = State.new("ROOT")
    @cur_state = @root # used for building the tree
    @mode_history = []
    @state_trail = []
    @last_action = nil
    @cur_action = nil

    @modifiers = [] # TODO: create a queue
    @last_event = [nil, nil, nil, nil, nil]
  end

  def set_default_mode(id)
    @match_state = [@modes[id]] # used for matching input
    @mode_root_state = @modes[id]
  end

  def add_mode(id, label)
    mode = State.new(id)
    @modes[label] = mode
    @root.children << mode
  end

  def clear_modifiers()
    @modifiers = []
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

  def set_mode(label)
    @mode_history << @mode_root_state

    # Check if label in form :label
    if @modes.has_key?(label)
      @mode_root_state = @modes[label]
    else
      # Check if label matches mode name in string format
      for mode in @root.children
        if mode.key_name == label
          @mode_root_state = mode
        end
      end
    end
  end

  def cur_mode_str()
    return @mode_root_state.key_name
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
    @state_trail = [@mode_root_state]
    # puts get_state_trail_str()
    # $next_command_count = nil # TODO: set somewhere else?
  end

  # Print key bindings to show as documentation or for debugging
  def to_s()
    s = ""
    # @cur_state = @root
    stack = [[@root, ""]]
    lines = []
    while stack.any?
      t, p = *stack.pop # t = current state, p = current path
      if t.children.any?
        t.children.reverse.each { |c|
          if c.eval_rule.size > 0
            new_p = "#{p} #{c.key_name}(#{c.eval_rule})"
          else
            new_p = "#{p} #{c.key_name}"
          end
          stack << [c, new_p]
        }
        # stack.concat[t.children]
      else
        # s += p + " : #{t.action}\n"
        lines << p + " : #{t.action}"
      end
    end
    s = lines.sort.join("\n")
    return s
  end

  def get_state_trail_str
    s = ""
    s_trail = ""
    last_state = @state_trail.last
    last_state = last_state[0] if last_state.class==Array
    for st in @state_trail
      st = st[0] if st.class == Array
      s_trail << " #{st.to_s}"
    end
    s << "CUR STATE: #{s_trail}\n"
    for cstate in last_state.children
      act_s = "..."
      act_s = cstate.action.to_s if cstate.action != nil
      s << "  #{cstate.to_s} #{act_s}\n"
    end
    return s
  end

  # Modifies state of key binding tree (move to new state) based on received event
  # Checks child nodes of current state if they match received event
  # if yes, change state to child
  # if no, go back to root
  def match_key_conf(c, translated_c, event_type)
    # $cur_key_dict = $key_bind_dict[$context[:mode]]
    print "MATCH KEY CONF: #{[c, translated_c]}" if $debug

    # Sometimes we get ASCII-8BIT encoding although content actually UTF-8
    c = c.force_encoding("UTF-8");  # TODO:correct?

    eval_s = nil
    new_state = match(translated_c)
    if new_state == nil and translated_c.index("shift") == 0
      new_state = match(c)
    end

    if new_state == nil
      s1 = match_state[0].children.select { |s| s.key_name.include?("<char>") } # TODO: [0]
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
      s1 = match_state[0].children.select { |s|
        s.key_name =~ /^\/.*\/$/
      } # TODO: [0]

      if s1.any? and c.size == 1
        s1.each { |x|
          m = /^\/(.*)\/$/.match(x.key_name)
          if m != nil
            m2 = Regexp.new(m[1]).match(c)
            if m2 != nil
              eval_s = x.action.clone
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

    if new_state != nil
      @state_trail << new_state
      puts get_state_trail_str()
      # # puts "CUR STATE: #{@state_trail.collect{|x| x.to_s}.join}"
      # s_trail = ""
      # for st in @state_trail
        # st = st[0] if st.class == Array
        # s_trail << " #{st.to_s}"
      # end
      # puts "CUR STATE: #{s_trail}"
      # for cstate in new_state[0].children
        # act_s = "..."
        # act_s = cstate.action.to_s if cstate.action != nil
        # puts "  #{cstate.to_s} #{act_s}"
      # end
      # Ripl.start :binding => binding
      # new_state[0].children.collect{|x|x.to_s}
    end

    if new_state == nil
      printf("NO MATCH") if $debug
      if event_type == KEY_PRESS and c != "shift"
        # TODO:include other modifiers in addition to shift?
        set_state_to_root
        printf(", BACK TO ROOT") if $debug
      end

      if event_type == KEY_RELEASE and c == "shift!"
        # Pressing a modifier key (shift) puts state back to root
        # only on key release when no other key has been pressed
        # after said modifier key (shift).
        set_state_to_root
        printf(", BACK TO ROOT") if $debug
      end

      printf("\n") if $debug
    else
      s_act = new_state.select { |s| s.action != nil }
      if s_act.any?
        eval_s = s_act.first.action if eval_s == nil
        puts "FOUND MATCH:#{eval_s}"
        puts "CHAR: #{c}"
        c.gsub!("\\", %q{\\\\} * 4) # Escape \ -chars
        c.gsub!("'", "#{'\\' * 4}'") # Escape ' -chars

        eval_s.gsub!("<char>", "'#{c}'") if eval_s.class == String
        puts eval_s
        puts c
        handle_key_bindigs_action(eval_s, c)
        set_state_to_root
      end
    end

    return true
  end

  # Receive keyboard event from Qt
  def handle_key_event(event)
    start_profiler
    # puts "GOT KEY EVENT: #{key.inspect}"
    debug "GOT KEY EVENT:: #{event} #{event[2]}"
    debug "|#{event.inspect}|"
    $debuginfo["cur_event"] = event

    t1 = Time.now

    keycode = event[0]
    event_type = event[1]
    modifierinfo = event[4]

    event[3] = event[2]
    # String representation of received key
    key_str = event[2]

    @modifiers.delete(Qt::Key_Alt) if event[4] & ALTMODIFIER == 0
    @modifiers.delete(Qt::Key_Control) if event[4] & CONTROLMODIFIER == 0
    @modifiers.delete(Qt::Key_Shift) if event[4] & SHIFTMODIFIER == 0

    # Add as modifier if ctrl, alt or shift
    if modifierinfo & ALTMODIFIER != 0 or modifierinfo & CONTROLMODIFIER != 0 or modifierinfo & SHIFTMODIFIER != 0
      # And keypress and not already a modifier
      if event_type == KEY_PRESS and !@modifiers.include?(keycode)
        @modifiers << keycode
      end
    end

    # puts "----D------------"
    # puts @modifiers.inspect
    # puts event.inspect
    # puts event[4] & ALTMODIFIER
    # puts "-----------------"

    @modifiers.delete(keycode) if event_type == KEY_RELEASE

    # uval = keyval_to_unicode(event[0])
    # event[3] = [uval].pack('c*').force_encoding('UTF-8') #TODO: 32bit?
    # debug("key_code_to_uval: uval: #{uval} uchar:#{event[3]}")

    if $event_keysym_translate_table.include?(keycode)
      key_str = $event_keysym_translate_table[keycode]
    end

    # Prefix string representation with modifiers, e.g. ctrl-shift-a
    key_prefix = ""
    @modifiers.each { |pressed_key|
      if $event_keysym_translate_table[pressed_key]
        key_prefix += $event_keysym_translate_table[pressed_key] + "-"
      end
    }

    # Get char based on keycode
    # to produce prefixed_key_str "shift-ctrl-a" instead of "shift-ctrl-\x01"
    key_str2 = key_str
    if $translate_table.include?(keycode)
      key_str2 = $translate_table[keycode].downcase
    end
    # puts "key_str=|#{key_str}| key_str=|#{key_str.inspect}| key_str2=|#{key_str2}|"
    prefixed_key_str = key_prefix + key_str2

    # if keycode == @last_event[0] and event_type == KEY_RELEASE
    # puts "KEY! key_str=|#{key_str}| prefixed_key_str=|#{prefixed_key_str}|"
    # end

    if key_str != "" or prefixed_key_str != ""
      if keycode == @last_event[0] and event_type == KEY_RELEASE
        # If key is released immediately after pressed with no other events between
        match_key_conf(key_str + "!", prefixed_key_str + "!", event_type)
      elsif event_type == KEY_PRESS
        match_key_conf(key_str, prefixed_key_str, event_type)
      end
      @last_event = event #TODO: outside if?
    end

    event_handle_time = Time.now - t1
    debug "RB key event handle time: #{event_handle_time}" if event_handle_time > 1 / 40.0
    render_buffer($buffer)
    end_profiler
  end
end

$action_list = []

def bindkey(key, action)
  $action_list << { :action => action, :key => key }

  k_arr = key.split
  modes = k_arr.shift # modes = "C" or "I" or "CI"
  modes.each_char { |m|
    $kbd.set_state(m, "") # TODO: check is ok?

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
      s1 = $kbd.find_state(key_name, eval_rule)
      if s1 == nil
        new_state = State.new(key_name, eval_rule)
        $kbd.cur_state.children << new_state
      end

      $kbd.set_state(key_name, eval_rule) # TODO: check is ok?
    }
    $kbd.cur_state.action = action
    $kbd.cur_state = $kbd.root
  }
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
  Qt::Key_Tab => "tab",
}

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

}

def exec_action(action)
  $kbd.last_action = $kbd.cur_action
  $kbd.cur_action = action
  if action.class == Symbol
    return call(action)
  elsif action.class == Proc
    return action.call
  else
    return eval(action)
  end
end

def handle_key_bindigs_action(action, c)
  $method_handles_repeat = false #TODO:??
  n = 1
  if $next_command_count and !(action.class == String and action.include?("set_next_command_count"))
    n = $next_command_count
    # $next_command_count = nil
    debug("COUNT command #{n} times")
  end

  begin
    n.times do
      ret = exec_action(action)

      if $macro.is_recording and ret != false
        $macro.record_action(action)
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
  rescue Exception => e
    puts "BACKTRACE"
    puts e.backtrace
    puts e.inspect
    puts "BACKTRACE END"
    if $!.class == SystemExit
      exit
    else
      crash("Error with action: #{action}: ", e)
    end
  end

  if action.class == String and !action.include?("set_next_command_count")
    $next_command_count = nil
  end
end

# Try to clear modifiers when program loses focus
# e.g. after alt-tab
def focus_out
  debug "RB Clear modifiers"
  $kbd.clear_modifiers()
end

def handle_key_event(event)
  $kbd.handle_key_event(event)
end
