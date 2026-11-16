# With the cursor on a bracket, GtkSourceView highlights its matching bracket
# (buffer.highlight_matching_brackets, set in gui_create_buffer, styled by the
# scheme's "bracket-match" style).
class TestBracketMatch < VmaTest
  TEXT = "foo(bar[1], {a: 2}) x\n"

  # GtkSourceView updates the bracket highlight from a low-priority main loop
  # source, so give the loop real time rather than a fixed iteration count.
  def wait_main_loop(sec = 0.3)
    t = Time.now
    GLib::MainContext.default.iteration(false) while Time.now - t < sec
  end

  # Put text in the current buffer, move the cursor to pos and return
  # [matched_offset, state] from the last "bracket-matched" signal, state as
  # :found, :not_found, :out_of_range or :none. nil if no signal came.
  def match_at(pos, text = TEXT)
    b = vma.buf
    b.set_content(text)
    drain_idle
    gbuf = b.view.buffer
    # Start from a non-bracket position so moving to pos is a real change
    b.set_pos(text.index(" ") || 0)
    wait_main_loop
    got = nil
    hid = gbuf.signal_connect("bracket-matched") do |_buf, iter, state|
      got = [state.nick.tr("-", "_").to_sym == :found ? iter.offset : nil, state.nick.tr("-", "_").to_sym]
    end
    begin
      b.set_pos(pos)
      wait_main_loop
    ensure
      gbuf.signal_handler_disconnect(hid)
    end
    got
  end

  # Tags at offset that paint a background (the bracket-match highlight)
  def highlight_tags_at(offset)
    gbuf = vma.buf.view.buffer
    gbuf.get_iter_at(:offset => offset).tags.select { |t| t.background_set? }
  end

  def test_enabled_on_gtk_buffer
    assert vma.buf.view.buffer.highlight_matching_brackets?, "highlight_matching_brackets is off"
  end

  def test_scheme_defines_bracket_match_style
    sty = vma.buf.view.buffer.style_scheme
    assert !sty.nil?, "no style scheme"
    assert !sty.get_style("bracket-match").nil?, "scheme #{sty.id} has no bracket-match style"
  end

  def test_open_paren_matches_close
    assert_eq [TEXT.index(")"), :found], match_at(TEXT.index("("))
    assert !highlight_tags_at(TEXT.index(")")).empty?, "closing ) not highlighted"
  end

  def test_close_paren_matches_open
    assert_eq [TEXT.index("("), :found], match_at(TEXT.index(")"))
    assert !highlight_tags_at(TEXT.index("(")).empty?, "opening ( not highlighted"
  end

  def test_square_and_curly
    assert_eq [TEXT.index("]"), :found], match_at(TEXT.index("["))
    assert_eq [TEXT.index("}"), :found], match_at(TEXT.index("{"))
  end

  def test_nested_matches_outer
    t = "((a)(b)) z\n"
    assert_eq [7, :found], match_at(0, t)
    assert_eq [3, :found], match_at(1, t)
  end

  def test_unbalanced_is_not_found
    assert_eq [nil, :not_found], match_at(0, "(abc def\n")
  end

  def test_highlight_cleared_when_cursor_leaves
    assert_eq [TEXT.index(")"), :found], match_at(TEXT.index("("))
    vma.buf.set_pos(TEXT.index("x"))
    wait_main_loop
    assert highlight_tags_at(TEXT.index(")")).empty?, ") still highlighted with cursor away"
  end
end
