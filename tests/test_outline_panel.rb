class TestOutlinePanel < VmaTest
  # Regression: toggling the outline panel with LSP disabled used to raise
  # NameError (uninitialized constant LangSrv) inside the GTK callback and
  # crash the whole app. It must now degrade to a "(no LSP)" placeholder.
  def test_toggle_outline_panel_no_lsp_does_not_raise
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    act "panel.outline.toggle"   # open
    act "panel.outline.toggle"   # close
    assert true, "no exception raised"
  ensure
    cnf.lsp.enabled = prev
  end

  def test_refresh_no_lsp_sets_placeholder
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    vma.buf.set_content("def foo\nend\n")
    vma.buf.instance_variable_set(:@fname, "/tmp/outline_panel_test.rb") # exercise the LangSrv guard
    fp = Vimamsa::OutlinePanel.new
    fp.refresh
    store = fp.instance_variable_get(:@store)
    names = []
    store.each { |_model, _path, iter| names << iter[Vimamsa::OutlinePanel::COL_NAME] }
    assert_eq ["(no LSP)"], names, "placeholder row set"
  rescue NameError => e
    raise VmaTestFailure, "refresh raised NameError: #{e.message}"
  ensure
    cnf.lsp.enabled = prev
  end

  def test_refresh_hyperplaintext_uses_titles_and_headings_without_lsp
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    vma.buf.set_content("❙ Project Notes ❙\nBody\n◼ Alpha\nText\n◼◼ Beta\n")
    vma.buf.instance_variable_set(:@fname, "/tmp/outline_panel_test.txt")
    vma.buf.set_filename(vma.buf.fname)
    fp = Vimamsa::OutlinePanel.new
    fp.refresh
    store = fp.instance_variable_get(:@store)
    names = []
    lines = []
    store.each do |_model, _path, iter|
      names << iter[Vimamsa::OutlinePanel::COL_NAME]
      lines << iter[Vimamsa::OutlinePanel::COL_LINE]
    end
    assert_eq ["Project Notes", "Alpha", "Beta"], names, "hyperplaintext outline rows"
    assert_eq [1, 3, 5], lines, "hyperplaintext outline line numbers"
  ensure
    cnf.lsp.enabled = prev
  end

  def test_refresh_hyperplaintext_without_outline_sets_placeholder
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    vma.buf.set_content("plain text\nmore text\n")
    vma.buf.instance_variable_set(:@fname, "/tmp/outline_panel_test.txt")
    vma.buf.set_filename(vma.buf.fname)
    fp = Vimamsa::OutlinePanel.new
    fp.refresh
    store = fp.instance_variable_get(:@store)
    names = []
    store.each { |_model, _path, iter| names << iter[Vimamsa::OutlinePanel::COL_NAME] }
    assert_eq ["(no headings)"], names, "placeholder row set"
  ensure
    cnf.lsp.enabled = prev
  end

  # Clicking a heading jumps there and leaves the focus in the editor, so its
  # cursor is drawn (it wasn't until a mode change, e.g. ctrl twice)
  def test_click_heading_keeps_editor_focus
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    vma.buf.set_content("❙ Project Notes ❙\nBody\n◼ Alpha\nText\n◼◼ Beta\n")
    vma.buf.instance_variable_set(:@fname, "/tmp/outline_panel_test.txt")
    vma.buf.set_filename(vma.buf.fname)
    act "panel.outline.toggle"
    drain_idle
    fp = vma.gui.outline_panel
    fp.refresh
    drain_idle
    tree = fp.instance_variable_get(:@tree)
    store = fp.instance_variable_get(:@store)
    path = nil
    store.each { |_m, pth, iter| path = pth.dup if iter[Vimamsa::OutlinePanel::COL_NAME] == "Beta" }
    assert !path.nil?, "no Beta row"
    assert !tree.focusable?, "panel tree should not take the focus"
    tree.signal_emit("row-activated", path, tree.get_column(0))
    drain_idle
    assert_eq 4, vma.buf.lpos, "did not jump to the heading's line"
    assert vma.gui.window.focus_widget.equal?(vma.buf.view), "editor view lost the focus"
  ensure
    act "panel.outline.toggle" if vma.gui.instance_variable_get(:@outline_panel_shown)
    cnf.lsp.enabled = prev
  end

  def outline_names(panel)
    names = []
    panel.instance_variable_get(:@store).each { |_m, _p, iter| names << iter[Vimamsa::OutlinePanel::COL_NAME] }
    names
  end

  # The key bindings page is a generated buffer (no file name) in
  # hyperplaintext: its title and ◼ sections are the outline, without a manual
  # refresh (it used to show "(no file)")
  def test_key_bindings_page_has_outline
    act "panel.outline.toggle"
    drain_idle
    act "help.keys"
    drain_idle
    names = outline_names(vma.gui.outline_panel)
    assert !names.include?("(no file)"), "shows (no file): #{names.first(3).inspect}"
    assert names.any? { |n| n.start_with?("Key bindings") }, "no title row: #{names.first(3).inspect}"
    assert names.include?("Basics"), "no Basics section: #{names.first(5).inspect}"
    assert_eq "hyperplaintext", vma.buf.lang
  ensure
    act "panel.outline.toggle" if vma.gui.instance_variable_get(:@outline_panel_shown)
  end

  # Markdown headings, nested by level; "#" lines in code blocks are not headings
  def test_markdown_headings
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    vma.buf.set_content("# Top\ntext\n```sh\n# not a heading\n```\n### Deep ###\n## Mid\n#nospace\n")
    vma.buf.instance_variable_set(:@fname, "/tmp/outline_panel_test.md")
    fp = Vimamsa::OutlinePanel.new
    fp.refresh
    store = fp.instance_variable_get(:@store)
    rows = []
    store.each { |_m, path, iter| rows << [iter[Vimamsa::OutlinePanel::COL_NAME], iter[Vimamsa::OutlinePanel::COL_LINE], path.depth] }
    assert_eq [["Top", 1, 1], ["Deep", 6, 2], ["Mid", 7, 2]], rows, "markdown outline"
  ensure
    cnf.lsp.enabled = prev
  end

  # Old action ids and saved layouts from before the rename still work
  def test_old_names_still_work
    assert_eq "panel.outline.toggle", vma.actions.resolve("panel.funcs.toggle").to_s
    assert_eq "panel.outline.toggle", vma.actions.resolve(:toggle_func_panel).to_s
  end
end
