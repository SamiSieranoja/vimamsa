# Vim registers (registers.rb, doc/vim_compatibility_plan.md step 4)
class TestRegisters < VmaTest
  # Put synchronously from the editor's copy (as in test_copy_paste): the
  # system clipboard is read asynchronously and may belong to another program
  def sync_paste
    vma.macro.instance_variable_set(:@running_macro, true)
    yield
  ensure
    vma.macro.instance_variable_set(:@running_macro, false)
  end

  def setup_text(s, pos = 0)
    buf.set_content(s)
    buf.set_pos(pos)
    vma.kbd.set_mode(:command)
  end

  def test_linewise_put_in_another_buffer
    setup_text("one\ntwo\n")
    keys("y y")
    create_new_buffer("a\nb\n", "regtest", true)
    buf.set_pos(0)
    sync_paste { keys("p") }
    assert_buf "a\none\nb\n"
    vma.buffers.close_buffer(buf.id)
  end

  def test_named_register
    setup_text("one\ntwo\n")
    keys('" a y y j')
    assert_eq ["one\n", true], vma.registers["a"].to_a
    keys('" a p')
    assert_buf "one\ntwo\none\n"
  end

  def test_append_to_named_register
    setup_text("one two\nthree\n")
    keys('" a y y')
    keys('j " A y y')
    assert_eq ["one two\nthree\n", true], vma.registers["a"].to_a
    vma.registers.store("x", reg: "b")
    vma.registers.store("y", reg: "B")
    assert_eq ["xy", false], vma.registers["b"].to_a
  end

  def test_numbered_and_small_delete
    setup_text("1\n2\n3\nfoo bar\n")
    keys("d d d d")
    assert_eq "2\n", vma.registers["1"].text
    assert_eq "1\n", vma.registers["2"].text
    keys("j d w")      # a delete within one line goes to "-, not "1
    assert_eq "foo ", vma.registers["-"].text
    assert_eq "2\n", vma.registers["1"].text
  end

  def test_yank_register_survives_deletes
    setup_text("keep\ngone\n")
    keys("y y j d d")
    assert_eq "keep\n", vma.registers["0"].text
    assert_eq "gone\n", vma.registers['"'].text
    keys('" 0 P')
    assert_buf "keep\nkeep\n"
  end

  def test_black_hole
    setup_text("keep\ngone\n")
    keys("y y j")
    keys('" _ d d')
    assert_buf "keep\n"
    assert_eq "keep\n", vma.registers['"'].text
    assert_eq "keep\n", vma.clipboard.get
  end

  # "x applies to the next command only; a count may come between
  def test_pending_register_is_used_once
    setup_text("a\nb\nc\n")
    keys('" q j y y')
    assert vma.registers["q"].nil?, "register used by a later command"
    keys('" w 2 y y')
    assert_eq "b\nc\n", vma.registers["w"].text
  end

  # A case change replaces the text but isn't a delete
  def test_case_change_keeps_clipboard
    setup_text("abc def\n")
    keys("y y g U w")
    assert_buf "ABC def\n"
    assert_eq "abc def\n", vma.registers['"'].text
  end

  def test_put_empty_register
    setup_text("abc\n")
    keys('" z p')
    assert_buf "abc\n"
  end

  def test_insert_register
    setup_text("abc\n")
    vma.registers.store("XY", reg: "k")
    keys("i")
    act("a.edit.insert.register!('k')")
    keys("esc")
    assert_buf "XYabc\n"
  end

  def test_operator_and_text_object_registers
    setup_text("foo bar\n")
    keys('" e c w')      # vimlike has no c: the shared operator layer
    keys("esc")
    assert_eq ["foo", false], vma.registers["e"].to_a
    setup_text("(x y)\n", 1)
    keys('" f d i (')
    assert_eq "x y", vma.registers["f"].text
  end

  def test_show_registers
    vma.registers.store("hello\n", linewise: true, reg: "h")
    show_registers
    assert buf.to_s.include?("\"h  l  hello^J"), buf.to_s
    vma.buffers.close_buffer(buf.id)
  end
end
