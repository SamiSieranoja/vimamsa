
# Similar feature as Vim EasyMotion https://github.com/easymotion/vim-easymotion
class EasyJump
  def initialize()
  make_jump_sequence
  end
end

def easy_jump(direction)
  message "EASY JUMP"
  visible_range = get_visible_area()
  visible_text = $buffer[visible_range[0]..visible_range[1]]
  wsmarks = scan_word_start_marks(visible_text)
  $easy_jump_wsmarks = wsmarks.collect{|x|x+visible_range[0]}
  
  $easy_jump_wsmarks.sort_by! { |x| (x - $buffer.pos).abs }
  $jump_sequence = make_jump_sequence($easy_jump_wsmarks.size)
  $input_char_call_func = method(:easy_jump_input_char)
  $kbd.set_mode(:readchar)
  $easy_jump_input = ""
end

def easy_jump_input_char(c)
  vma.paint_stack=[]
  puts "EASY JUMP: easy_jump_input_char [#{c}]"
  $easy_jump_input << c.upcase
  if $jump_sequence.include?($easy_jump_input)
    jshash = Hash[$jump_sequence.map.with_index.to_a]
    nthword = jshash[$easy_jump_input] + 1
    puts "nthword:#{nthword} #{$easy_jump_wsmarks[nthword]}"
    $buffer.set_pos($easy_jump_wsmarks[nthword])
    $kbd.set_mode(:command)
    $input_char_call_func = nil
    $jump_sequence = []
  end
  if $easy_jump_input.size > 2
    $kbd.set_mode(:command)
    $input_char_call_func = nil
    $jump_sequence = []
  end
end

def easy_jump_draw()
  return if $jump_sequence.empty?
  puts "EASY JUMP DRAW"
  screen_cord = cpp_function_wrapper(0, [$easy_jump_wsmarks])
  screen_cord = screen_cord[1..$jump_sequence.size]
  screen_cord.each_with_index { |point, i|
    mark_str = $jump_sequence[i]
    #puts "draw #{point[0]}x#{point[1]}"
    draw_text(mark_str, point[0], point[1])
    #break if m > $cpos
  }
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

  left_hand_fast.each { |x|
    left_hand_fast.each { |y|
      sequence << "#{x}#{y}"
    }
  }

  right_hand_fast.each { |x|
    right_hand_fast.each { |y|
      sequence << "#{x}#{y}"
    }
  }

  right_hand_fast.each { |x|
    left_hand_fast.each { |y|
      sequence << "#{x}#{y}"
    }
  }

  left_hand_fast.each { |x|
    right_hand_fast.each { |y|
      sequence << "#{x}#{y}"
    }
  }

  left_hand_slow.each { |x|
    right_fast_slow.each { |y|
      sequence << "#{x}#{y}"
    }
  }

  right_hand_slow.each { |x|
    left_fast_slow.each { |y|
      sequence << "#{x}#{y}"
    }
  }

  left_hand_slow2.each { |x|
    right_hand_all.each { |y|
      left_hand_all.each { |z|
        sequence << "#{x}#{y}#{z}"
      }
    }
  }

  right_hand_slow2.each { |x|
    left_hand_all.each { |y|
      right_hand_all.each { |z|
        sequence << "#{x}#{y}#{z}"
      }
    }
  }

  #printf("Size of sequence: %d\n",sequence.size)
  #puts sequence.inspect
  return sequence
end

