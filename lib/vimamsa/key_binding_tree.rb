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
  attr_reader :mode_root_state

  def initialize()
    @modes = {}
    @root = State.new("ROOT")
    @cur_state = @root # used for building the tree
    @mode_history = []
    @last_action = nil
    @cur_action = nil
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
    # $next_command_count = nil # TODO: set somewhere else?
  end

  def to_s()
    s = ""
    # @cur_state = @root
    stack = [[@root, ""]]
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
        s += p + " : #{t.action}\n"
      end
    end
    return s
  end
end

# def build_key_bindings_tree
# $kbd = KeyBindingTree.new()
# $default_keys.each { |key, value|
# bindkey(key, value)
# }
# end

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

# Modifies state of key binding tree (move to new state) based on received event
def match_key_conf(c, translated_c, event_type)
  # $cur_key_dict = $key_bind_dict[$context[:mode]]
  print "MATCH KEY CONF: #{[c, translated_c]}"

  # Sometimes we get ASCII-8BIT encoding although content actually UTF-8
  c = c.force_encoding("UTF-8");  # TODO:correct?

  eval_s = nil
  new_state = $kbd.match(translated_c)
  if new_state == nil and translated_c.index("shift") == 0
    new_state = $kbd.match(c)
  end

  if new_state == nil
    s1 = $kbd.match_state[0].children.select { |s| s.key_name.include?("<char>") } # TODO: [0]
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
    s1 = $kbd.match_state[0].children.select { |s|
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

  if new_state == nil
    printf("NO MATCH")
    if event_type == KEY_PRESS and translated_c != "shift"
      # TODO:include other modifiers in addition to shift?
      $kbd.set_state_to_root
      printf(", BACK TO ROOT")
    end

    if event_type == KEY_RELEASE and translated_c == "shift!"
      # Pressing a modifier key (shift) puts state back to root
      # only on key release when no other key has been pressed
      # after said modifier key (shift).
      $kbd.set_state_to_root
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

      eval_s.gsub!("<char>", "'#{c}'") if eval_s.class == String
      puts eval_s
      puts c
      handle_key_bindigs_action(eval_s, c)
      $kbd.set_state_to_root
    end
  end

  return true
end

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
  $method_handles_repeat = false
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

# Experimental, try to clear modifiers when program loses focus
#
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

$keys_pressed = [] # TODO: create a queue

def handle_key_event(event)
  start_profiler
  # puts "GOT KEY EVENT: #{key.inspect}"
  debug "GOT KEY EVENT:: #{event} #{event[2]}"
  $debuginfo["cur_event"] = event

  t1 = Time.now
  event[3] = event[2]

  if ($check_modifiers or true) # TODO: rely on check_modifiers?
    $keys_pressed.delete(Qt::Key_Alt) if event[4] & ALTMODIFIER == 0
    $keys_pressed.delete(Qt::Key_Control) if event[4] & CONTROLMODIFIER == 0
    $keys_pressed.delete(Qt::Key_Shift) if event[4] & SHIFTMODIFIER == 0
    $check_modifiers = false
    # TODO: other modifiers
  end

  $keys_pressed << Qt::Key_Alt if event[1] == KEY_PRESS \
    and !$keys_pressed.include?(Qt::Key_Alt) \
    and event[4] & ALTMODIFIER != 0 # Fix for alt lose focus problem.
  # puts "----D------------"
  # puts $keys_pressed.inspect
  # puts event.inspect
  # puts event[4] & ALTMODIFIER
  # puts "-----------------"

  $keys_pressed << event[0] if event[1] == KEY_PRESS \
    and !$keys_pressed.include?(event[0])
  $keys_pressed.delete(event[0]) if event[1] == KEY_RELEASE

  $keys_pressed.delete(Qt::Key_Enter) # TODO: Delete after timeout?
  $keys_pressed.delete(Qt::Key_Return)

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
    # puts "Translated to: #{event[3]}"
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
  end_profiler
end
