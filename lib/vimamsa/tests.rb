require "digest"

def run_tests()
  # DelayExecutioner.exec(id: :run_tests, wait: 0.7, callable: proc { run_tests_0 })

  # Reload class
  # if Object.constants.include?(:EditorTests)
  # Object.send(:remove_const, :EditorTests)
  # end
  load __FILE__

  run_edit_tests
end

def run_tests_0()
  tests = ["test_write_0"]
  stats = []
  for t in tests
    r = eval(t)
    if r == true
      stats << "test #{t} OK"
    else
      stats << "test #{t} FAILED"
    end
  end
  debug "TEST RESULTS:", 2
  puts stats.join("\n")
  puts "===================="
end

def run_edit_tests()
  edt = EditorTests.new
  tests = edt.methods.select { |x| x.match(/test_.*/) }.collect { |x| { :method => edt.method(x), :name => x } }
  for t in tests
    b = create_new_buffer(file_contents = "\n", prefix = "buf", setcurrent = true)

    edits = t[:method].call
    # next if t[:name] != :test_create_close_buf
    errors = 0
    edits.each_with_index do |x, i|
      if x.class == Array
        (act, target) = x
        
        vma.macro.run_actions(act)
        # bufc = b.to_s
        bufc = vma.buf.to_s
        if bufc != target
          puts "ERROR[#{t[:name]}:#{i}] act=#{act.inspect} content=#{bufc.inspect} != #{target.inspect}"
          errors += 1
        end
      else
        vma.macro.run_actions(x)
      end
    end
    if errors == 0
      puts "TEST #{t[:name]} passed"
    else
    end
  end
end

class EditorTests
  def test_write
    #[[action to run, expected buffer contents after], ...]
    [['buf.insert_txt("zzzz")', "zzzz\n"],
     # At end of file replace should not change anything
     ['buf.replace_with_char("-")', "zzzz\n"],
     'buf.insert_txt("\n")',
     ['buf.insert_txt("yy")', "zzzz\nyy\n"],
     :e_move_backward_char, :e_move_backward_char,
     ['buf.insert_txt("0")', "zzzz\n0yy\n"],
     "buf.jump(START_OF_BUFFER)",
     ['buf.replace_with_char("1")', "1zzz\n0yy\n"]]
  end

  def test_delete
    [['buf.insert_txt("abcdef")', "abcdef\n"],
     'buf.insert_txt("\n")',
     ['buf.insert_txt("yy")', "abcdef\nyy\n"],
     "buf.jump(START_OF_BUFFER)",
     :delete_char_forward,
     [:delete_char_forward, "cdef\nyy\n"],
     "buf.jump(END_OF_LINE)",
     "buf.delete(BACKWARD_CHAR)",
     ["buf.delete(BACKWARD_CHAR)", "cd\nyy\n"]]
  end

  def test_create_close_buf
    ['buf.insert_txt("abcdef")',
     [:buf_new,"\n"],
     'buf.insert_txt("a")',
     'buf.insert_txt("b")',
     'buf.insert_txt("c")',
     'buf.insert_txt("d")',
     ['buf.insert_txt("e")',"abcde\n"],
     [:close_current_buffer, "abcdef\n"]]
  end
end

def test_paste_0(runmacro = true)
  return
  #TODO: update macro
  b = create_new_buffer(file_contents = "\n", prefix = "buf", setcurrent = true)

  b.insert_txt(JABBERWOCKY)
  b.insert_txt(LOREM_IPSUM)
  b.insert_txt(LOREM_IPSUM)

  macro = ["buf.jump(START_OF_BUFFER)", "buf.copy_line", :forward_line, :paste_after, :backward_line, :backward_line, "buf.paste(BEFORE)", :forward_line, :forward_line, :forward_line, :forward_line, "buf.jump_word(FORWARD,WORD_START)", "buf.start_visual_mode", "buf.jump_word(FORWARD,WORD_END)", "buf.copy_active_selection()", "buf.move(FORWARD_CHAR)", "buf.paste(BEFORE)", "buf.jump_word(FORWARD,WORD_END)", :paste_after, :forward_line, "buf.jump(BEGINNING_OF_LINE)", "buf.copy_line", :forward_line, :forward_line, :paste_after, :paste_after, :forward_line, "buf.jump_word(FORWARD,WORD_START)", "buf.start_visual_mode", "buf.jump_word(FORWARD,WORD_END)", "buf.jump_word(FORWARD,WORD_END)", "buf.jump_word(FORWARD,WORD_END)", "buf.jump_word(FORWARD,WORD_END)", "buf.jump(END_OF_LINE)", :e_move_backward_char, "buf.copy_active_selection()", :forward_line, "buf.paste(BEFORE)", "buf.paste(BEFORE)", "buf.paste(BEFORE)", "buf.paste(BEFORE)", "buf.jump(END_OF_BUFFER)", "buf.jump(BEGINNING_OF_LINE)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", "buf.start_visual_mode", "buf.jump_word(FORWARD,WORD_END)", "buf.jump_word(FORWARD,WORD_END)", "buf.jump_word(FORWARD,WORD_END)", "buf.jump_word(FORWARD,WORD_END)", "buf.copy_active_selection()", "buf.jump(BEGINNING_OF_LINE)", "buf.paste(BEFORE)", "buf.paste(BEFORE)"]

  macro_r = true
  if runmacro
    macro_r = vma.macro.run_actions(macro)
  end

  hex = Digest::SHA2.hexdigest b.to_s
  conds = [hex == "705061f7bc6370b501b6d09615547530a103e2a659e20fb6915d17ae65f564fa",
           macro_r == true]
  # debug conds
  debug hex

  if conds.include?(false)
    return false
  else
    return true
  end
end

def macro_test(macro, correct_hex, runmacro = true)
  b = create_new_buffer(file_contents = "\n", prefix = "buf", setcurrent = true)
  b.insert_txt(JABBERWOCKY)
  b.insert_txt(LOREM_IPSUM)
  b.insert_txt(LOREM_IPSUM)

  macro_r = true
  if runmacro
    macro_r = vma.macro.run_actions(macro)
  end

  hex = Digest::SHA2.hexdigest b.to_s
  conds = [hex == correct_hex,
           macro_r == true]
  # debug conds
  debug hex

  if conds.include?(false)
    return false
  else
    return true
  end
end

def test_delete_0
  macro = ["buf.jump(START_OF_BUFFER)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", :e_move_backward_char, "buf.delete(BACKWARD_CHAR)", "buf.delete(BACKWARD_CHAR)", "buf.delete(BACKWARD_CHAR)", "buf.delete(BACKWARD_CHAR)", "buf.delete(BACKWARD_CHAR)", "buf.delete(BACKWARD_CHAR)", :forward_line, :e_move_backward_char, "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", "buf.delete(CURRENT_CHAR_FORWARD)", :forward_line, :forward_line, :forward_line, :forward_line, :forward_line, :delete_line, :forward_line, :delete_line, :forward_line, :forward_line, :delete_line, :delete_line, :forward_line, :forward_line, "vma.kbd.set_mode(:audio)", :forward_line, :forward_line, :forward_line, :forward_line, "buf.delete2(:to_mark,'a')", :backward_line, :forward_line, :forward_line, "vma.kbd.set_mode(:audio)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", "buf.jump_word(FORWARD,WORD_START)", "buf.delete2(:to_mark,'a')", "buf.mark_current_position('b')", :forward_line, :forward_line, :forward_line, :forward_line, :forward_line, :forward_line, :forward_line, :forward_line, :forward_line, :forward_line, "buf.delete2(:to_mark,'a')", "vma.kbd.set_mode(:audio)", :forward_line, :forward_line, :forward_line, "buf.jump_to_mark('a')", "buf.jump_to_mark('a')", :backward_line, :backward_line, :backward_line, :backward_line, "buf.jump_to_mark('a')", "buf.jump_to_mark('a')", "buf.jump_to_mark('a')", "buf.jump_to_mark('a')"]
  return macro_test(macro, "71bc0421b47549267b327b69216ad8e042379625f99de1ba4faaa30d5042c22d")
end

LOREM_IPSUM = "
   Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis sollicitudin mauris. Integer in mauris eu nibh euismod gravida. Duis ac tellus et risus vulputate vehicula. Donec lobortis risus a elit. Etiam tempor. Ut ullamcorper, ligula eu tempor congue, eros est euismod turpis, id tincidunt sapien risus a quam. Maecenas fermentum consequat mi. Donec fermentum. Pellentesque malesuada nulla a mi. Duis sapien sem, aliquet nec, commodo eget, consequat quis, neque. Aliquam faucibus, elit ut dictum aliquet, felis nisl adipiscing sapien, sed malesuada diam lacus eget erat. Cras mollis scelerisque nunc. Nullam arcu. Aliquam consequat. Curabitur augue lorem, dapibus quis, laoreet et, pretium ac, nisi. Aenean magna nisl, mollis quis, molestie eu, feugiat in, orci. In hac habitasse platea dictumst."

JABBERWOCKY = "
  ’Twas brillig, and the slithy toves
      Did gyre and gimble in the wabe:
All mimsy were the borogoves,
      And the mome raths outgrabe.

“Beware the Jabberwock, my son!
      The jaws that bite, the claws that catch!
Beware the Jubjub bird, and shun
      The frumious Bandersnatch!”

He took his vorpal sword in hand;
      Long time the manxome foe he sought—
So rested he by the Tumtum tree
      And stood awhile in thought.

And, as in uffish thought he stood,
      The Jabberwock, with eyes of flame,
Came whiffling through the tulgey wood,
      And burbled as it came!

One, two! One, two! And through and through
      The vorpal blade went snicker-snack!
He left it dead, and with its head
      He went galumphing back.

“And hast thou slain the Jabberwock?
      Come to my arms, my beamish boy!
O frabjous day! Callooh! Callay!”
      He chortled in his joy.

’Twas brillig, and the slithy toves
      Did gyre and gimble in the wabe:
All mimsy were the borogoves,
      And the mome raths outgrabe.
"
