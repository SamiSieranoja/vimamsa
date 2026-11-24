class TestFuncPanel < VmaTest
  # Regression: toggling the function panel with LSP disabled used to raise
  # NameError (uninitialized constant LangSrv) inside the GTK callback and
  # crash the whole app. It must now degrade to a "(no LSP)" placeholder.
  def test_toggle_func_panel_no_lsp_does_not_raise
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    act "panel.funcs.toggle"   # open
    act "panel.funcs.toggle"   # close
    assert true, "no exception raised"
  ensure
    cnf.lsp.enabled = prev
  end

  def test_refresh_no_lsp_sets_placeholder
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    vma.buf.set_content("def foo\nend\n")
    vma.buf.instance_variable_set(:@fname, "/tmp/func_panel_test.rb") # exercise the LangSrv guard
    fp = Vimamsa::FuncPanel.new
    fp.refresh
    store = fp.instance_variable_get(:@store)
    names = []
    store.each { |_model, _path, iter| names << iter[Vimamsa::FuncPanel::COL_NAME] }
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
    vma.buf.instance_variable_set(:@fname, "/tmp/func_panel_test.txt")
    vma.buf.set_filename(vma.buf.fname)
    fp = Vimamsa::FuncPanel.new
    fp.refresh
    store = fp.instance_variable_get(:@store)
    names = []
    lines = []
    store.each do |_model, _path, iter|
      names << iter[Vimamsa::FuncPanel::COL_NAME]
      lines << iter[Vimamsa::FuncPanel::COL_LINE]
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
    vma.buf.instance_variable_set(:@fname, "/tmp/func_panel_test.txt")
    vma.buf.set_filename(vma.buf.fname)
    fp = Vimamsa::FuncPanel.new
    fp.refresh
    store = fp.instance_variable_get(:@store)
    names = []
    store.each { |_model, _path, iter| names << iter[Vimamsa::FuncPanel::COL_NAME] }
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
    vma.buf.instance_variable_set(:@fname, "/tmp/func_panel_test.txt")
    vma.buf.set_filename(vma.buf.fname)
    act "panel.funcs.toggle"
    drain_idle
    fp = vma.gui.func_panel
    fp.refresh
    drain_idle
    tree = fp.instance_variable_get(:@tree)
    store = fp.instance_variable_get(:@store)
    path = nil
    store.each { |_m, pth, iter| path = pth.dup if iter[Vimamsa::FuncPanel::COL_NAME] == "Beta" }
    assert !path.nil?, "no Beta row"
    assert !tree.focusable?, "panel tree should not take the focus"
    tree.signal_emit("row-activated", path, tree.get_column(0))
    drain_idle
    assert_eq 4, vma.buf.lpos, "did not jump to the heading's line"
    assert vma.gui.window.focus_widget.equal?(vma.buf.view), "editor view lost the focus"
  ensure
    act "panel.funcs.toggle" if vma.gui.instance_variable_get(:@func_panel_shown)
    cnf.lsp.enabled = prev
  end
end
