# Covers the visual-selection transform envelope (transform_selection,
# convert_selected_text, style_transform) and the line-style helper
# (set_line_style) after they were refactored onto the shared
# transform_visual_selection / apply_style_markers helpers.

class TestTextTransforms < VmaTest
  # Select the whole first word ("hello") in visual mode.
  def select_first_word
    keys("i h e l l o esc")
    act("buf.set_pos(0)")
    keys("v")
    act("buf.set_pos(4)") # extend selection over "hello"
  end

  def test_upcase
    select_first_word
    act("buf.transform_selection(:upcase)")
    assert_buf("HELLO\n")
    assert_mode(:command)
  end

  def test_swapcase
    keys("i H e L l O esc")
    act("buf.set_pos(0)")
    keys("v")
    act("buf.set_pos(4)")
    act("buf.transform_selection(:swapcase)")
    assert_buf("hElLo\n")
  end

  def test_reverse
    select_first_word
    act("buf.transform_selection(:reverse)")
    assert_buf("olleh\n")
  end

  def test_no_op_when_not_visual
    keys("i h e l l o esc")
    # Not in visual mode: transform_selection must be a no-op.
    act("buf.transform_selection(:upcase)")
    assert_buf("hello\n")
  end

  def test_style_bold
    select_first_word
    act("buf.style_transform(:bold)")
    assert_buf("⦁hello⦁\n")
  end

  def test_style_clear
    keys("i ❙ h i ❙ esc")
    act("buf.set_pos(0)")
    keys("v")
    act("buf.set_pos(3)")
    act("buf.style_transform(:clear)")
    assert_buf("hi\n")
  end

  def test_line_style_title
    keys("i h e l l o esc")
    act("buf.set_line_style(:title)")
    assert_buf("❙hello❙\n")
  end

  def test_line_style_h2_then_clear
    keys("i h e l l o esc")
    act("buf.set_line_style(:h2)")
    assert_buf("◼◼ hello\n")
    act("buf.set_line_style(:clear)")
    assert_buf("hello\n")
  end
end
