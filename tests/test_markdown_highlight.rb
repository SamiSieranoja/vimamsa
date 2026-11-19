require "tmpdir"

# markdown.lang maps its tokens to def:heading, def:inline-code, def:link-text,
# ... which have no fallback in def.lang. The generated overlay
# (markup_overlay_styles in gui_settings.rb) adds them for schemes that lack
# them, so markdown isn't drawn as plain text with the bundled schemes.
class TestMarkdownHighlight < VmaTest
  def scheme(id)
    ssm = GtkSource::StyleSchemeManager.new
    ssm.set_search_path(ssm.search_path << ppath("styles/"))
    ssm.get_scheme(id)
  end

  def styled?(st)
    !st.nil? && ((st.foreground || "") != "" || st.bold? || st.italic? || (st.underline || "none") != "none")
  end

  def test_overlay_styles_markdown_on_default_scheme
    old = cnf.style_scheme!
    cnf.style_scheme = "molokai_edit"
    sty = load_vimamsa_scheme
    %w[def:heading def:inline-code def:link-text def:strong-emphasis def:list-marker].each { |n|
      assert styled?(sty.get_style(n)), "#{n} has no style on molokai_edit"
    }
    # Colors come from the scheme's own styles
    assert_eq scheme("molokai_edit").get_style("def:string").foreground,
              sty.get_style("def:inline-code").foreground
    assert sty.get_style("def:heading").bold?
  ensure
    cnf.style_scheme = old
    gui_refresh_style_scheme
  end

  def test_scheme_with_markup_styles_is_left_alone
    sty = scheme("Adwaita")
    skip "no Adwaita scheme" if sty.nil?
    out = markup_overlay_styles(sty)
    added = out.scan(/name="([^"]+)"/).flatten
    defined = MARKUP_OVERLAY_STYLES.keys.select { |n| sty.get_style(n) }
    assert defined.include?("def:heading"), "Adwaita should define def:heading"
    assert_eq [], added & defined, "overlay overrides styles the scheme has"
  end

  def test_md_file_gets_markdown_language
    Dir.mktmpdir { |dir|
      path = "#{dir}/x.md"
      File.write(path, "# Title\n\nSome `code` and a [link](http://example.com).\n")
      b = open_new_file(path)
      drain_idle
      begin
        assert_eq "markdown", b.view.buffer.language&.id
      ensure
        vma.buffers.close_buffer(b.id)
      end
    }
  end
end
