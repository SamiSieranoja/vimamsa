class TestColorHighlight < VmaTest

  def view
    vma.buf.view
  end

  # Does the GTK buffer carry one of our color tags spanning the given offset?
  def color_tag_at(off)
    itr = view.buffer.get_iter_at(:offset => off)
    itr.tags.find { |t| t.name.to_s.start_with?("vma_color_") }
  end

  # ── Pure color math ──────────────────────────────────────────────────────

  def test_display_colors_six_digit
    bg, fg = Vimamsa::ColorHighlight.display_colors("#3DCBB5")
    assert_eq "#3dcbb5", bg
    assert_eq "#000000", fg, "teal is bright => black text"
  end

  def test_display_colors_dark_gets_white_text
    _bg, fg = Vimamsa::ColorHighlight.display_colors("#101010")
    assert_eq "#ffffff", fg
  end

  def test_display_colors_shorthand_expands
    bg, _fg = Vimamsa::ColorHighlight.display_colors("#f00")
    assert_eq "#ff0000", bg
  end

  def test_display_colors_drops_alpha
    bg, _fg = Vimamsa::ColorHighlight.display_colors("#3dcbb5ff")
    assert_eq "#3dcbb5", bg
  end

  # ── Live tagging in the GTK buffer ─────────────────────────────────────────

  def test_hex_code_gets_a_color_tag
    cnf.modules.color_highlight.enabled = true
    vma.buf.set_content("bg = #3DCBB5\n")
    view.highlight_colors
    idx = vma.buf.to_s.index("#3DCBB5")
    tag = color_tag_at(idx)
    assert !tag.nil?, "expected a vma_color_ tag over the hex code"
    assert_eq "#3dcbb5", tag.name.sub("vma_color_", "")
  end

  def test_non_color_text_untagged
    cnf.modules.color_highlight.enabled = true
    vma.buf.set_content("just words here\n")
    view.highlight_colors
    assert color_tag_at(2).nil?, "plain text must not get a color tag"
  end

  def test_disabled_clears_tags
    cnf.modules.color_highlight.enabled = true
    vma.buf.set_content("c = #ff0000\n")
    view.highlight_colors
    idx = vma.buf.to_s.index("#ff0000")
    assert !color_tag_at(idx).nil?, "tag should be present while enabled"
    cnf.modules.color_highlight.enabled = false
    view.highlight_colors
    assert color_tag_at(idx).nil?, "disabling must remove color tags"
  ensure
    cnf.modules.color_highlight.enabled = true
  end

  def test_toggle_action
    prev = cnf.modules.color_highlight.enabled?
    cnf.modules.color_highlight.enabled = true
    act :toggle_highlight_colors
    assert_eq false, cnf.modules.color_highlight.enabled?
    act :toggle_highlight_colors
    assert_eq true, cnf.modules.color_highlight.enabled?
  ensure
    cnf.modules.color_highlight.enabled = prev
  end

  # The module decouples from core via view hooks rather than direct calls.
  def test_view_hooks_registered
    assert vma.hook[:view_content_set]&.any?, "content-set hook should be registered"
    assert vma.hook[:view_text_changed]&.any?, "text-changed hook should be registered"
  end

  # Exposed in the Preferences dialog as an auto-discovered module toggle.
  def test_setting_exposed
    all = all_settings_defs.flat_map { |sec| sec[:settings] }
    s = all.find { |x| x[:key] == [:modules, :color_highlight, :enabled] }
    assert !s.nil?, "color_highlight module toggle must appear in settings defs"
    assert_eq :bool, s[:type]
  end
end
