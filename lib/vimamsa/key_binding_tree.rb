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
# 'I ctrl-a'=> 'vma.buf.jump(BEGINNING_OF_LINE)',
#


class State
  attr_accessor :key_name, :eval_rule, :children, :action, :label, :major_modes, :level, :cursor_type
  attr_reader :cur_mode, :scope

  def initialize(key_name, eval_rule = "", ctype = :command, scope: :buffer)
    @key_name = key_name
    @eval_rule = eval_rule
    @children = []
    @scope = scope
    @major_modes = []
    @action = nil
    @level = 0
    @cursor_type = ctype
  end

  def to_s()
    return @key_name
  end
end

class KeyBindingTree
  attr_accessor :C, :I, :cur_state, :root, :match_state, :last_action, :cur_action, :modifiers, :next_command_count, :method_handles_repeat, :default_mode
  attr_reader :mode_root_state, :state_trail, :act_bindings, :default_mode_stack

  def initialize()
    @next_command_count = nil
    @modes = {}
    @root = State.new("ROOT")
    @cur_state = @root # used for building the tree
    @default_mode = nil
    @default_mode_stack = []
    @mode_history = []
    @state_trail = []
    @last_action = nil
    @cur_action = nil
    @method_handles_repeat = false

    @modifiers = { :ctrl => false, :shift => false, :alt => false } # TODO: create a queue
    @last_event = [nil, nil, nil, nil, nil]

    @override_keyhandling_callback = nil
    # Allows h["foo"]["faa"]=1
    @act_bindings = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
  end

  def set_mode(label)
    return if get_mode == :label
    @match_state = [@modes[label]] # used for matching input
    @mode_root_state = @modes[label]
    # @default_mode = label
    @default_mode_stack << label

    __set_mode(label)
    if !vma.buf.nil?
      # vma.buf.mode_stack = @default_mode_stack.clone
    end
  end

  def set_default_mode(label)
    @match_state = [@modes[label]]
    @mode_root_state = @modes[label]
    @default_mode = label
    set_mode_stack [label]
  end

  def set_mode_stack(ms)
    debug "set_mode_stack(#{ms})", 2
    show_caller if cnf.debug? # TODO: remove 
    @default_mode_stack = ms
    label = @default_mode_stack[-1]
    @match_state = [@modes[label]]
    @mode_root_state = @modes[label]
  end

  def dump_state
    debug "dump_state", 2
    pp ["@default_mode_stack", @default_mode_stack]
    pp ["@default_mode", @default_mode]
    pp ["vma.buf.mode_stack", vma.buf.mode_stack]
    pp ["scope", self.get_scope]
    # pp ["@mode_root_state", @mode_root_state]
    # pp ["@match_state", @match_state]
  end

  def set_mode_to_default()
    # set_mode(@default_mode)
    set_mode_stack [@default_mode_stack[0]]
    __set_mode(@default_mode_stack[0])
  end

  def to_previous_mode()
    debug "to_previous_mode",2
    debug @default_mode_stack
    if @default_mode_stack.size > 1
      @default_mode_stack.pop
    end
    debug @default_mode_stack
    __set_mode(@default_mode_stack[-1])
  end

  def add_mode(id, label, cursortype = :command, name: nil, scope: :buffer)
    mode = State.new(id, "", cursortype, scope: scope)
    mode.level = 1
    @modes[label] = mode
    @root.children << mode
    if @default_mode == nil
      set_default_mode(label)
    end
  end

  # Add keyboard key binding mode based on another mode
  def add_minor_mode(id, label, major_mode_label)
    mode = State.new(id)
    @modes[label] = mode
    if @root.nil?
      show_caller
      Ripl.start :binding => binding
    end
    @root.children << mode
    mode.major_modes << major_mode_label
  end

  def clear_modifiers()
    # @modifiers = [] #TODO:remove?
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

  def set_keyhandling_override(_callback)
    @override_keyhandling_callback = _callback
  end

  def remove_keyhandling_override()
    @override_keyhandling_callback = nil
  end

  def match(key_name)
    new_state = []
    @match_state.each { |parent|
      parent.children.each { |c|
        # printf(" KEY MATCH: ")
        # debug [c.key_name, key_name].inspect
        if c.key_name == key_name and c.eval_rule == ""
          new_state << c
        elsif c.key_name == key_name and c.eval_rule != ""
          debug "CHECK EVAL: #{c.eval_rule}"
          if eval(c.eval_rule)
            new_state << c
            debug "EVAL TRUE"
          else
            debug "EVAL FALSE"
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

  def show_state_trail
    (st, children) = get_state_trail_str()
    vma.gui.statnfo.markup = "<span weight='ultrabold'>#{st}</span>"
  end

  def __set_mode(label)
    debug "__set_mode(#{label})"
    @mode_history << @mode_root_state

    # Check if label in form :label
    if @modes.has_key?(label)
      @mode_root_state = @modes[label]
      set_state_to_root
    else
      # Check if label matches mode name in string format
      for mode in @root.children
        if mode.key_name == label
          @mode_root_state = mode
        end
      end
    end
    @cur_mode = label

    if self.get_scope != :editor and !vma.buf.nil?
      vma.buf.mode_stack = @default_mode_stack.clone
    end

    if !vma.gui.view.nil?
      vma.gui.view.draw_cursor()  #TODO: handle outside this class
    end
  end

  def get_scope
    @mode_root_state.scope
  end

  def cur_mode_str()
    return @mode_root_state.key_name
  end

  def get_cursor_type
    @mode_root_state.cursor_type
  end

  def get_mode
    return @cur_mode
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
    if @mode_root_state.major_modes.size == 1
      modelabel = @mode_root_state.major_modes[0]
      mmode = @modes[modelabel]
      @match_state = [@mode_root_state, mmode]
    else
      @match_state = [@mode_root_state]
    end

    @state_trail = [@mode_root_state]
  end

  # Print key bindings to show as documentation or for debugging
  def to_s()
    # return self.class.to_s
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
            if c.level == 1
              new_p = "#{p} [#{c.key_name}]"
            else
              new_p = "#{p} #{c.key_name}"
            end
          end
          stack << [c, new_p]
        }
        # stack.concat[t.children]
      else
        method_desc = t.action
        if t.action.class == Symbol
          if vma.actions.include?(t.action)
            a = vma.actions[t.action].method_name
            if !a.nil? and !a.empty?
              method_desc = a
            end
          end
        end

        lines << p + " : #{method_desc}"
      end
    end
    s = lines.sort.join("\n")
    return s
  end

  def get_state_trail_str
    s_trail = ""
    last_state = @state_trail.last
    last_state = last_state[0] if last_state.class == Array
    first = true
    for st in @state_trail
      st = st[0] if st.class == Array
      if first
        trailpfx = ""
        if !st.major_modes.empty?
          mmid = st.major_modes.first
          trailpfx = "#{@modes[mmid].to_s}>"
        end
        s_trail << "[#{trailpfx}#{st.to_s}]"
      else
        s_trail << " #{st.to_s}"
      end
      first = false
    end
    children = ""
    for cstate in last_state.children
      act_s = "..."
      act_s = cstate.action.to_s if cstate.action != nil
      children << "  #{cstate.to_s} #{act_s}\n"
    end
    if !@next_command_count.nil?
      s_trail << " #{@next_command_count}"
    end
    return [s_trail, children]
  end

  def set_next_command_count(num)
    if @next_command_count != nil
      @next_command_count = @next_command_count * 10 + num.to_i
    else
      @next_command_count = num.to_i
    end
    debug("NEXT COMMAND COUNT: #{@next_command_count}")
  end

  # Modifies state of key binding tree (move to new state) based on received event
  # Checks child nodes of current state if they match received event
  # if yes, change state to child
  # if no, go back to root
  def match_key_conf(c, translated_c, event_type)
    debug "MATCH KEY CONF: #{[c, translated_c]}"

    if !@override_keyhandling_callback.nil?
      ret = @override_keyhandling_callback.call(c, event_type)
      return if ret
    end

    eval_s = nil

    new_state = match(c)
    # #TODO:
    # new_state = match(translated_c)
    # if new_state == nil and translated_c.index("shift") == 0
    # new_state = match(c)
    # end

    if new_state == nil
      s1 = match_state[0].children.select { |s| s.key_name.include?("<char>") } # TODO: [0]
      if s1.any? and (c.size == 1) and event_type == :key_press
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
    end

    if new_state == nil
      debug("NO MATCH")
      if event_type == :key_press and c != "shift"
        # TODO:include other modifiers in addition to shift?
        set_state_to_root
        printf(", BACK TO ROOT") if cnf.debug?
      end

      if event_type == :key_release and c == "shift!"
        # Pressing a modifier key (shift) sets state back to root
        # only on key release when no other key has been pressed
        # after said modifier key (shift).
        set_state_to_root
        printf(", BACK TO ROOT") if cnf.debug?
      end

      printf("\n") if cnf.debug?
    else

      # Don't execute action if one of the states has children
      state_with_children = new_state.select { |s| s.children.any? }
      s_act = new_state.select { |s| s.action != nil }

      if s_act.any? and !state_with_children.any?
        eval_s = s_act.first.action if eval_s == nil
        debug "FOUND MATCH:#{eval_s}"
        debug "CHAR: #{c}"
        c.gsub!("\\", %q{\\\\} * 4) # Escape \ -chars
        c.gsub!("'", "#{'\\' * 4}'") # Escape ' -chars

        eval_s.gsub!("<char>", "'#{c}'") if eval_s.class == String
        debug eval_s
        debug c
        handle_key_bindigs_action(eval_s, c)
        set_state_to_root
      end
    end

    show_state_trail #TODO: check if changed

    return true
  end

  def bindkey(key, action)
    if key.class != Array
      # Handle syntax like :
      # "X esc || X ctrl!" => "vma.kbd.to_previous_mode",
      key = key.split("||")
    end

    a = action
    if action.class == Array
      label = a[0]
      a = label
      proc = action[1]
      msg = action[2]
      reg_act(label, proc, msg)
    end
    key.each { |k| _bindkey(k, a) }
  end

  def _bindkey(key, action)
    key.strip!
    key.gsub!(/\s+/, " ")

    # if key.class == Array
    # key.each { |k| bindkey(k, action) }
    # return
    # end
    # $action_list << { :action => action, :key => key }
    if !vma.actions.include?(action)
      if action.class == String
        reg_act(action, proc { eval(action) }, action)
      end
    end

    m = key.match(/^(\S+)\s(\S.*)$/)
    # Match/split e.g. "VC , , s" to "VC" and ", , s"
    if m
      modetmp = m[1]
      debug [key, modetmp, m].inspect

      # If all of first word are uppercase, e.g. in
      # "VCIX left" => "buf.move(BACKWARD_CHAR)",
      # interpret as each char representing a mode
      modes = modetmp.split("") if modetmp.match(/^\p{Lu}+$/) # Uppercase

      # If all of first word is down case, like in:
      # bindkey "audio space", :audio_stop
      # interpret as whole word representing a mode.
      modes = [modetmp] if modetmp.match(/^\p{Ll}+$/) # Lowercase
      keydef = m[2]
    else
      fatal_error("Error in keydef #{key.inspect}")
    end

    modes.each { |mode_id|
      mode_bind_key(mode_id, keydef, action)
      @act_bindings[mode_id][action] = keydef
    }
  end

  # Binds a keyboard key combination to an action,
  # for a given keyboard mode like insert ("I") or command ("C")
  def mode_bind_key(mode_id, keydef, action)
    # debug "mode_bind_key #{mode_id.inspect}, #{keydef.inspect}, #{action.inspect}", 2
    # Example:
    # bindkey "C , f", :gui_file_finder
    # mode_id = "C", keydef = ", f"
    # and action = :gui_file_finder

    set_state(mode_id, "") # TODO: check is ok?
    start_state = @cur_state

    k_arr = keydef.split

    prev_state = nil
    s1 = start_state

    k_arr.each_with_index { |k, idx|
      # check if key has rules for context like q has in
      # "C q(cntx.recording_macro==true)"
      last_item = false
      if k_arr.size - 1 == idx
        last_item = true
      end
      match = /(.+)\((.*)\)/.match(k)
      eval_rule = ""
      if match
        key_name = match[1]
        eval_rule = match[2]
      else
        key_name = k
      end

      prev_state = s1
      # Create a new state for key if it doesn't exist
      s1 = find_state(key_name, eval_rule)
      if s1 == nil or last_item
        new_state = State.new(key_name, eval_rule)
        if last_item
          # Override existing key definition
          @cur_state.children.delete(s1)
        end
        s1 = new_state
        @cur_state.children << new_state
      end

      set_state(key_name, eval_rule) # TODO: check is ok?
    }
    if action == :delete_state
      prev_state.children.delete(cur_state)
    else
      @cur_state.action = action
    end
    @cur_state = @root
  end

  def handle_key_bindigs_action(action, c)
    # $acth << action #TODO:needed here?
    @method_handles_repeat = false #TODO:??
    n = 1
    if @next_command_count and !(action.class == String and action.include?("set_next_command_count"))
      n = @next_command_count
      debug("COUNT command #{n} times")
    end

    begin
      n.times do
        ret = exec_action(action)

        if vma.macro.is_recording and ret != false
          debug "RECORD ACTION:#{action}", 2
          vma.macro.record_action(action)
        end
        break if @method_handles_repeat
        # Some methods have specific implementation for repeat,
        #   like '5yy' => copy next five lines. (copy_line())
        # By default the same command is just repeated n times
        #   like '20j' => go to next line 20 times.
        # But methods can also handle the number input themselves if vma.kbd.method_handles_repeat=true is set,
      end
      # run_as_idle proc { vma.buf.refresh_cursor; vma.buf.refresh_cursor }, delay: 0.05
    rescue SyntaxError
      message("SYNTAX ERROR with eval cmd #{action}: " + $!.to_s)
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

    if !(action.class == String and action.include?("set_next_command_count"))
      @next_command_count = nil
    end
  end
end

def bindkey(key, action)
  $kbd.bindkey(key, action)
end

def exec_action(action)
  $kbd.last_action = $kbd.cur_action
  $kbd.cur_action = action
  if action.class == Symbol
    return call_action(action)
  elsif action.class == Proc
    return action.call
  else
    return eval(action)
  end
end

# Try to clear modifiers when program loses focus
# e.g. after alt-tab
# TODO
# def focus_out
  # debug "RB Clear modifiers"
  # $kbd.clear_modifiers()
# end

# def handle_key_event(event)
  # $kbd.handle_key_event(event)
# end
