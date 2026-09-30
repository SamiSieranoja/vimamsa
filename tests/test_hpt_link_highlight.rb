class TestHptLinkHighlight < VmaTest

  def view
    vma.buf.view
  end

  # Force GtkSourceView to run its (normally async) syntax highlighter
  # over the whole buffer.
  def highlight_now
    gb = view.buffer
    gb.ensure_highlight(gb.start_iter, gb.end_iter)
    drain_idle
  end

  # Syntax-style tags at +off+. Context-class tags (e.g. the
  # "no-spell-check" class on the main context) cover all text and are
  # not highlighting, so leave them out.
  def style_tags_at(off)
    itr = view.buffer.get_iter_at(:offset => off)
    itr.tags.reject { |t| t.name.to_s.start_with?("gtksourceview:context-classes") }
  end

  def setup_hpt(txt)
    vma.buf.set_language("hyperplaintext")
    vma.buf.set_content(txt)
    highlight_now
  end

  def test_hyperplaintext_language_loaded
    vma.buf.set_language("hyperplaintext")
    lang = view.buffer.language
    assert !lang.nil?, "hyperplaintext.lang should be found under lang/"
    assert_eq "hyperplaintext", lang.id
  end

  def test_link_gets_highlight_tag
    setup_hpt("plain ⟦link⟧ plain\n")
    txt = vma.buf.to_s
    link_off = txt.index("link")
    plain_off = 1

    assert style_tags_at(plain_off).empty?, "plain text must not be highlighted"
    tags = style_tags_at(link_off)
    assert !tags.empty?, "expected a syntax tag over ⟦link⟧"
  end

  def test_link_highlight_covers_brackets
    setup_hpt("x ⟦link⟧ y\n")
    txt = vma.buf.to_s
    open_off = txt.index("⟦")
    close_off = txt.index("⟧")
    link_tags = style_tags_at(open_off + 1)
    assert !link_tags.empty?, "expected a syntax tag over ⟦link⟧"

    assert_eq link_tags, style_tags_at(open_off), "⟦ should share the link style"
    assert_eq link_tags, style_tags_at(close_off), "⟧ should share the link style"
    assert style_tags_at(open_off - 1).empty?, "text before ⟦ must not be highlighted"
    assert style_tags_at(close_off + 1).empty?, "text after ⟧ must not be highlighted"
  end

  def test_link_style_differs_from_bold
    setup_hpt("⦁bold⦁ ⟦link⟧\n")
    txt = vma.buf.to_s
    bold_tags = style_tags_at(txt.index("bold"))
    link_tags = style_tags_at(txt.index("link"))
    assert !link_tags.empty?, "expected a syntax tag over ⟦link⟧"
    assert link_tags != bold_tags, "link must use its own style, not bold's"
  end

  def test_unclosed_link_not_highlighted
    setup_hpt("plain ⟦link without end\n")
    off = vma.buf.to_s.index("link")
    assert style_tags_at(off).empty?, "unterminated ⟦ must not be highlighted"
  end

  def test_other_language_does_not_highlight_link
    vma.buf.set_content("plain ⟦link⟧ plain\n")
    highlight_now
    off = vma.buf.to_s.index("link")
    assert style_tags_at(off).empty?, "no lang => no link highlight"
  end
end
