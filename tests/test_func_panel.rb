class TestFuncPanel < VmaTest
  # Regression: toggling the function panel with LSP disabled used to raise
  # NameError (uninitialized constant LangSrv) inside the GTK callback and
  # crash the whole app. It must now degrade to a "(no LSP)" placeholder.
  def test_toggle_func_panel_no_lsp_does_not_raise
    prev = cnf.lsp.enabled?
    cnf.lsp.enabled = false
    act :toggle_func_panel   # open
    act :toggle_func_panel   # close
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
end
