
# Similar feature as Vim EasyMotion https://github.com/easymotion/vim-easymotion

def easy_jump(direction)
  message "EASY JUMP"
  $easy_jump_wsmarks = scan_word_start_marks($buffer)
  visible_range = get_visible_area()
  $easy_jump_wsmarks = $easy_jump_wsmarks.select { |x|
    x >= visible_range[0] && x <= visible_range[1]
  }

  $easy_jump_wsmarks.sort_by! { |x| (x - $buffer.pos).abs }

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
    nthword = jshash[$easy_jump_input] + 1
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
  screen_cord = cpp_function_wrapper(0, [$easy_jump_wsmarks])
  screen_cord = screen_cord[1..$jump_sequence.size]
  #puts $jump_sequence
  #puts screen_cord.inspect
  screen_cord.each_with_index { |point, i|
    mark_str = $jump_sequence[i]
    #puts "draw #{point[0]}x#{point[1]}"
    draw_text(mark_str, point[0], point[1])
    #break if m > $cpos
  }
end


