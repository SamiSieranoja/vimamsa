# Checks that hyperplaintext syntax actually *looks* highlighted.
# test_hpt_link_highlight.rb only checks that a context tag exists, but
# GtkSourceView creates that tag even when the style scheme has no style
# for the lang's map-to id, leaving the text rendered as plain.
class TestHptHighlightVisible < VmaTest

  def view
    vma.buf.view
  end

  def highlight_now
    gb = view.buffer
    gb.ensure_highlight(gb.start_iter, gb.end_iter)
    drain_idle
  end

  def style_tags_at(off)
    itr = view.buffer.get_iter_at(:offset => off)
    itr.tags.reject { |t| t.name.to_s.start_with?("gtksourceview:context-classes") }
  end

  VISUAL_PROPS = %w(foreground-set background-set weight-set style-set
                    underline-set scale-set).freeze

  # True if any tag at +off+ changes how the text is rendered.
  def visibly_styled?(off)
    style_tags_at(off).any? { |t| VISUAL_PROPS.any? { |p| t.get_property(p) } }
  end

  def setup_hpt(txt)
    vma.buf.set_language("hyperplaintext")
    vma.buf.set_content(txt)
    highlight_now
  end

  def bundled_scheme_ids
    Dir[ppath("styles/*.xml")].map { |f| File.read(f)[/<style-scheme[^>]*\bid="([^"]+)"/, 1] }.compact
  end

  def with_scheme(id)
    ssm = GtkSource::StyleSchemeManager.new
    ssm.set_search_path(ssm.search_path << ppath("styles/"))
    sch = ssm.get_scheme(id)
    assert !sch.nil?, "style scheme #{id} should load"
    old = view.buffer.style_scheme
    view.buffer.style_scheme = sch
    highlight_now
    yield
  ensure
    view.buffer.style_scheme = old if old
  end

  def test_link_visible_in_active_scheme
    setup_hpt("plain ⟦notes⟧ plain\n")
    txt = vma.buf.to_s
    assert !visibly_styled?(1), "plain text must not be styled"
    assert visibly_styled?(txt.index("notes")), "⟦notes⟧ must be visibly highlighted"
    assert visibly_styled?(txt.index("⟦")), "⟦ must be visibly highlighted"
    assert visibly_styled?(txt.index("⟧")), "⟧ must be visibly highlighted"
  end

  def test_link_visible_in_every_bundled_scheme
    setup_hpt("plain ⟦notes⟧ plain\n")
    off = vma.buf.to_s.index("notes")
    bad = bundled_scheme_ids.reject { |id| with_scheme(id) { visibly_styled?(off) } }
    assert bad.empty?, "⟦notes⟧ not highlighted in scheme(s): #{bad.join(", ")}"
  end

  def test_other_markup_visible_in_active_scheme
    setup_hpt("⦁bold⦁ ╱italic╱\n")
    txt = vma.buf.to_s
    assert visibly_styled?(txt.index("bold")), "⦁bold⦁ must be visibly highlighted"
    assert visibly_styled?(txt.index("italic")), "╱italic╱ must be visibly highlighted"
  end
end
