# Scientific calculator widget embeddable inline in a text buffer.
#
# Enable this module in Preferences → Modules → "Scientific Calculator".
#
# Usage (once enabled):
#   :insert_calculator action  — inserts the widget at the cursor position
#
# The widget occupies a single U+FFFC (object replacement) character in the
# Ruby buffer, keeping GTK/Ruby buffer offsets aligned.
# Press ↩ inside the calculator to insert the current result after the widget.

class VmaCalculator < Gtk::Box
  BUTTON_LAYOUT = [
    #  label   row  col  w    h
    ["sin",    0,   0,   1,   1],
    ["cos",    0,   1,   1,   1],
    ["tan",    0,   2,   1,   1],
    ["log",    0,   3,   1,   1],
    ["ln",     0,   4,   1,   1],
    ["√x",     1,   0,   1,   1],
    ["x²",     1,   1,   1,   1],
    ["xʸ",     1,   2,   1,   1],
    ["π",      1,   3,   1,   1],
    ["e",      1,   4,   1,   1],
    ["C",      2,   0,   1,   1],
    ["±",      2,   1,   1,   1],
    ["%",      2,   2,   1,   1],
    ["⌫",      2,   3,   1,   1],
    ["↩",      2,   4,   1,   1],
    ["7",      3,   0,   1,   1],
    ["8",      3,   1,   1,   1],
    ["9",      3,   2,   1,   1],
    ["÷",      3,   3,   1,   1],
    ["(",      3,   4,   1,   1],
    ["4",      4,   0,   1,   1],
    ["5",      4,   1,   1,   1],
    ["6",      4,   2,   1,   1],
    ["×",      4,   3,   1,   1],
    [")",      4,   4,   1,   1],
    ["1",      5,   0,   1,   1],
    ["2",      5,   1,   1,   1],
    ["3",      5,   2,   1,   1],
    ["-",      5,   3,   1,   1],
    ["=",      5,   4,   2,   1],
    ["0",      6,   0,   2,   1],
    [".",      6,   2,   1,   1],
    ["+",      6,   3,   1,   1],
  ].freeze

  def initialize(anchor_pos, bufo)
    super(:vertical, 2)
    @anchor_pos = anchor_pos
    @bufo = bufo
    @expression = ""
    @last_result = nil

    self.margin_top    = 4
    self.margin_bottom = 4
    self.margin_start  = 4
    self.margin_end    = 4

    setup_ui
  end

  private

  def setup_ui
    @expr_label = Gtk::Label.new("")
    @expr_label.xalign = 1.0
    @expr_label.add_css_class("dim-label")
    append(@expr_label)

    @display = Gtk::Entry.new
    @display.editable = false
    @display.xalign = 1.0
    @display.text = "0"
    @display.add_css_class("monospace")
    @display.width_chars = 20
    append(@display)

    grid = Gtk::Grid.new
    grid.row_spacing    = 2
    grid.column_spacing = 2
    grid.margin_top     = 4
    append(grid)

    BUTTON_LAYOUT.each do |label, row, col, w, h|
      btn = Gtk::Button.new(label: label)
      btn.width_request  = 42
      btn.height_request = 36
      btn.signal_connect("clicked") { on_button(label) }
      btn.add_css_class("suggested-action")   if %w[= ↩].include?(label)
      btn.add_css_class("destructive-action") if %w[C ⌫].include?(label)
      grid.attach(btn, col, row, w, h)
    end
  end

  def on_button(label)
    case label
    when "C"
      @expression = ""
      show_display("0")
    when "⌫"
      @expression = @expression[0..-2] || ""
      show_display(@expression.empty? ? "0" : @expression)
    when "="       then evaluate
    when "↩"       then insert_result
    when "sin"     then apply_unary("Math.sin(deg2rad(%s))")
    when "cos"     then apply_unary("Math.cos(deg2rad(%s))")
    when "tan"     then apply_unary("Math.tan(deg2rad(%s))")
    when "log"     then apply_unary("Math.log10(%s)")
    when "ln"      then apply_unary("Math.log(%s)")
    when "√x"      then apply_unary("Math.sqrt(%s)")
    when "x²"
      @expression = "(#{@expression})**2"
      evaluate
    when "xʸ"
      @expression += "**"
      show_display(@expression)
    when "π"
      @expression += Math::PI.to_s
      show_display(@expression)
    when "e"
      @expression += Math::E.to_s
      show_display(@expression)
    when "±"
      @expression = @expression.start_with?("-") ? @expression[1..] : "-#{@expression}"
      show_display(@expression.empty? ? "0" : @expression)
    when "%"
      @expression = "(#{@expression})/100.0"
      evaluate
    when "÷"
      @expression += "/"
      show_display(@expression)
    when "×"
      @expression += "*"
      show_display(@expression)
    else
      @expression += label
      show_display(@expression)
    end
  end

  def apply_unary(template)
    @expression = template % "(#{@expression}).to_f"
    evaluate
  end

  def evaluate
    result = eval(@expression).to_f
    @last_result = result
    formatted = (result == result.floor && result.abs < 1e15) ?
      result.to_i.to_s : result.round(10).to_s
    @expr_label.text = @expression
    @expression = formatted
    show_display(formatted)
  rescue => e
    @expr_label.text = @expression
    show_display("Error")
    @expression = ""
  end

  def show_display(text)
    @display.text = text
  end

  # Insert the current result into the buffer immediately after the widget.
  def insert_result
    return if @last_result.nil?
    result_str = (@last_result == @last_result.floor && @last_result.abs < 1e15) ?
      @last_result.to_i.to_s : @last_result.to_s
    @bufo.insert_txt_at(result_str, @anchor_pos + 1)
  end

  def deg2rad(deg)
    deg * Math::PI / 180.0
  end
end

# Insert a VmaCalculator widget at the current cursor position.
# U+FFFC is inserted in the Ruby buffer as a placeholder so that
# Ruby and GTK buffer offsets stay aligned (both have exactly one
# character at the anchor position).
def insert_calculator_in_buffer
  view = vma.gui.view
  bufo = vma.buf
  return if view.nil? || bufo.nil?

  pos = bufo.pos

  # Step 1: insert the placeholder in the Ruby buffer and flush it to GTK.
  bufo.insert_txt_at("\uFFFC", pos)
  view.handle_deltas

  # Step 2: the GTK buffer now has a plain U+FFFC at pos.
  # Replace it with a real child anchor, then attach the widget.
  iter = view.buffer.get_iter_at(:offset => pos)
  if iter && iter.char == "\uFFFC"
    iter2 = view.buffer.get_iter_at(:offset => pos + 1)
    view.buffer.delete(iter, iter2)
    iter = view.buffer.get_iter_at(:offset => pos)
    anchor = view.buffer.create_child_anchor(iter)
    calc = VmaCalculator.new(pos, bufo)
    view.add_child_at_anchor(calc, anchor)
    calc.show
  end
end

def calculator_init
  reg_act(:insert_calculator, proc { insert_calculator_in_buffer }, "Insert scientific calculator widget at cursor")
end
