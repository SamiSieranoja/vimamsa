# vim_binding_conflicts (key_bindings_report.rb) and the generated
# doc/vimlike_vim_conflicts.md. Regenerate the doc with:
#   VMA_UPDATE_DOC=1 ruby exe/run_tests.rb --headless vim_conflicts
class TestVimConflicts < VmaTest
  DOC = File.expand_path("../doc/vimlike_vim_conflicts.md", __dir__)

  def rows
    @rows ||= vim_binding_conflicts
  end

  def row(mode, keys)
    rows.find { |r| r[:mode] == mode && r[:keys].join(" ") == keys }
  end

  def test_doc_is_up_to_date
    report = vim_binding_conflicts_report(rows)
    if ENV["VMA_UPDATE_DOC"] == "1"
      File.write(DOC, report)
      return
    end
    # doc/ is in .gitignore, so a fresh checkout has no report to compare with
    skip "#{DOC} missing (run with VMA_UPDATE_DOC=1)" unless File.exist?(DOC)
    assert File.read(DOC) == report,
           "doc/vimlike_vim_conflicts.md is out of date: rerun with VMA_UPDATE_DOC=1 and commit it"
  end

  def test_classifies_known_cases
    assert_eq :shared, row("C", "u")[:status]               # undo in both
    r = row("C", "s")                                       # vim substitute, vimlike easy_jump
    assert_eq [:conflict, :same_keys], [r[:status], r[:why]]
    r = row("C", "c c")                                     # vimlike has no c operator
    assert_eq :missing, r[:status]
    assert_eq :shared, row("C", "d i <char>")[:status]      # text objects in both
  end

  def test_shorter_and_prefix_conflicts
    kbd = KeyBindingTree.new(actions: ActionList.new)
    kbd.add_mode("C", :command)
    kbd.bindkey("C z", :start_browse_mode)
    kbd.bindkey("C , x", :foo)
    kbd.bindkey("C q <char>", :rec)
    st = ->(keys) { vim_binding_status(kbd, "C", keys.split, :vim_action) }
    assert_eq [:conflict, :shorter], st.("z z").values_at(:status, :why)
    assert_eq [:conflict, :prefix], st.(",").values_at(:status, :why)
    assert_eq [:conflict, :wildcard], st.("q a").values_at(:status, :why)
    assert_eq :missing, st.("t <char>")[:status]
  end

  def test_loading_schemes_leaves_editor_alone
    kbd, acts = vma.kbd, vma.actions
    color = cnf.mode.command.cursor.background!
    cnf.mode.command.cursor.background = "#123456"
    begin
      load_scheme_kbd("vim")
      assert vma.kbd.equal?(kbd), "vma.kbd replaced"
      assert vma.actions.equal?(acts), "vma.actions replaced"
      assert_eq "#123456", cnf.mode.command.cursor.background!
      assert vma.actions.include?(:show_key_bindings)
    ensure
      cnf.mode.command.cursor.background = color
    end
  end
end
