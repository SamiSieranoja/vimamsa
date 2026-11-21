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
    # The report is tracked in git; skip only if it was deleted locally
    skip "#{DOC} missing (run with VMA_UPDATE_DOC=1)" unless File.exist?(DOC)
    assert File.read(DOC) == report,
           "doc/vimlike_vim_conflicts.md is out of date: rerun with VMA_UPDATE_DOC=1 and commit it"
  end

  def test_classifies_known_cases
    assert_eq :shared, row("C", "u")[:status]               # undo in both
    r = row("C", "s")                                       # vim substitute, vimlike easy_jump
    assert_eq [:conflict, :same_keys], [r[:status], r[:why]]
    r = row("C", "c c")                                     # vimlike has no c operator
    assert_eq :added, r[:status]                            # so it comes from VIM_BINDINGS
    assert_eq :added, row("C", "d i <char>")[:status]       # text objects from the shared templates
  end

  def test_shorter_and_prefix_conflicts
    kbd = KeyBindingTree.new(actions: ActionList.new)
    kbd.add_mode("C", :command)
    kbd.bindkey("C z", "mode.browse")
    kbd.bindkey("C , x", :foo)
    kbd.bindkey("C q <char>", :rec)
    st = ->(keys) { vim_binding_status(kbd, "C", keys.split, :vim_action) }
    assert_eq [:conflict, :shorter], st.("z z").values_at(:status, :why)
    assert_eq [:conflict, :prefix], st.(",").values_at(:status, :why)
    assert_eq [:conflict, :wildcard], st.("q a").values_at(:status, :why)
    assert_eq :missing, st.("t <char>")[:status]
  end

  # Everything vimlike could take from the shared table, it took
  def test_nothing_left_missing
    missing = rows.select { |r| r[:status] == :missing }
    assert missing.empty?, missing.map { |r| "#{r[:mode]} #{r[:keys].join(" ")}" }.inspect
  end

  # The live vimlike tree (the one the tests run with) has the added
  # bindings, and they behave as in vim
  def test_added_bindings_work_in_vimlike
    assert vma.kbd.vim_added.include?(["C", ["c", "w"]]), "c w not added"
    buf.set_content("foo bar baz\n")
    buf.set_pos(4)
    keys("D")
    assert_buf "foo \n"
    assert_mode :command

    buf.set_content("foo bar\n")
    buf.set_pos(0)
    keys("c w x esc")
    assert_buf "x bar\n"
    assert_mode :command

    buf.set_content("  foo\nbar\n")
    buf.set_pos(3)
    keys("S y esc")
    assert_buf "y\nbar\n"
  end

  # Conflicting vim bindings are not loaded: vimlike's own action stays
  def test_vimlike_keeps_its_own_bindings
    st = vim_binding_status(vma.kbd, "C", ["s"], "edit.change.char")
    assert_eq [:conflict, :same_keys], st.values_at(:status, :why)
    assert !vma.kbd.vim_added.include?(["C", ["s"]])
    # Adding C ctrl-f ("move.page.next") doesn't change the key the menu shows
    assert_eq "pagedown", vma.kbd.act_bindings["C"]["move.page.next"]
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
      assert vma.actions.include?("help.keys")
    ensure
      cnf.mode.command.cursor.background = color
    end
  end
end
