class TestKeyBindings < VmaTest

  # ── bindkey / basic dispatch ─────────────────────────────────────────────

  def test_bindkey_symbol_action_fires
    triggered = false
    reg_act(:_test_bindkey_symbol, proc { triggered = true }, "test")
    bindkey "C t e s t 1", :_test_bindkey_symbol
    keys "t e s t 1"
    assert triggered, "action should have fired"
  end

  def test_bindkey_string_action_fires
    $test_str_fired = false
    bindkey "C t e s t 2", '$test_str_fired = true'
    keys "t e s t 2"
    assert $test_str_fired, "string action should have fired"
  end

  def test_bindkey_proc_via_array
    $test_arr_fired = false
    bindkey "C t e s t 3", [:_test_arr_action, proc { $test_arr_fired = true }, "test"]
    keys "t e s t 3"
    assert $test_arr_fired, "array-style action should have fired"
  end

  # ── multi-key chord ──────────────────────────────────────────────────────

  def test_chord_requires_full_sequence
    count = 0
    reg_act(:_test_chord, proc { count += 1 }, "test chord")
    bindkey "C , x q", :_test_chord

    keys ","       # partial — should not fire yet
    assert_eq 0, count, "should not fire after partial chord"

    keys "x q"     # complete chord
    assert_eq 1, count, "should fire after complete chord"
  end

  def test_chord_wrong_key_resets
    count = 0
    reg_act(:_test_chord_reset, proc { count += 1 }, "test")
    bindkey "C , x r", :_test_chord_reset

    keys ", x z"   # wrong last key — resets, does not fire
    assert_eq 0, count, "wrong key should not fire the action"

    keys ", x r"   # correct sequence
    assert_eq 1, count, "correct chord should fire"
  end

  # ── mode specificity ─────────────────────────────────────────────────────

  def test_command_binding_does_not_fire_in_insert_mode
    count = 0
    reg_act(:_test_cmd_only, proc { count += 1 }, "test")
    bindkey "C , x c", :_test_cmd_only

    # Switch to insert mode and send the keys
    vma.kbd.set_mode(:insert)
    keys ", x c"
    vma.kbd.set_mode(:command)
    assert_eq 0, count, "command binding should not fire in insert mode"
  end

  def test_insert_binding_fires_in_insert_mode
    count = 0
    reg_act(:_test_ins_only, proc { count += 1 }, "test")
    bindkey "I ctrl-F9", :_test_ins_only   # unlikely to conflict

    vma.kbd.set_mode(:insert)
    keys "ctrl-F9"
    vma.kbd.set_mode(:command)
    assert_eq 1, count, "insert binding should fire in insert mode"
  end

  # ── unbindkey ────────────────────────────────────────────────────────────

  def test_unbindkey_removes_binding
    count = 0
    reg_act(:_test_unbind, proc { count += 1 }, "test")
    bindkey "C , x u", :_test_unbind

    keys ", x u"
    assert_eq 1, count, "should fire before unbind"

    unbindkey "C , x u"

    keys ", x u"
    assert_eq 1, count, "should not fire after unbind"
  end

  def test_unbindkey_pipe_syntax
    count = 0
    reg_act(:_test_unbind_pipe, proc { count += 1 }, "test")
    bindkey "C , x p || C , x q", :_test_unbind_pipe

    keys ", x p"
    keys ", x q"
    assert_eq 2, count, "both bindings should fire"

    unbindkey "C , x p || C , x q"

    keys ", x p"
    keys ", x q"
    assert_eq 2, count, "neither binding should fire after unbind"
  end

  # include_child_nodes: clear every binding under a node in one call.

  def test_unbindkey_include_child_nodes_clears_mode
    count = 0
    reg_act(:_test_uc1, proc { count += 1 }, "test")
    reg_act(:_test_uc2, proc { count += 1 }, "test")
    vma.kbd.add_minor_mode("tdictmode", :tdictmode, :command)
    bindkey "tdictmode ctrl-F10", :_test_uc1
    bindkey "tdictmode ctrl-F11 ctrl-F12", :_test_uc2

    vma.kbd.set_mode(:tdictmode)
    keys "ctrl-F10"
    keys "ctrl-F11 ctrl-F12"
    assert_eq 2, count, "both mode bindings should fire before unbind"

    unbindkey "tdictmode", include_child_nodes: true
    keys "ctrl-F10"
    keys "ctrl-F11 ctrl-F12"
    assert_eq 2, count, "no mode binding should fire after clearing children"
  ensure
    vma.kbd.set_mode(:command)
  end

  # A bare mode id (no chord) implies include_child_nodes.
  def test_unbindkey_bare_mode_clears_children
    count = 0
    reg_act(:_test_ub_bare, proc { count += 1 }, "test")
    vma.kbd.add_minor_mode("tbaremode", :tbaremode, :command)
    bindkey "tbaremode ctrl-F9", :_test_ub_bare

    vma.kbd.set_mode(:tbaremode)
    keys "ctrl-F9"
    assert_eq 1, count, "mode binding should fire before unbind"

    unbindkey "tbaremode"
    keys "ctrl-F9"
    assert_eq 1, count, "bare-mode unbind should clear children"
  ensure
    vma.kbd.set_mode(:command)
  end

  # Clearing a minor mode's children must leave the inherited (command) mode.
  def test_unbindkey_include_child_nodes_keeps_parent_mode
    parent_count = 0
    child_count = 0
    reg_act(:_test_parent, proc { parent_count += 1 }, "test")
    reg_act(:_test_child, proc { child_count += 1 }, "test")
    bindkey "C ctrl-F7", :_test_parent
    vma.kbd.add_minor_mode("tdmodeb", :tdmodeb, :command)
    bindkey "tdmodeb ctrl-F8", :_test_child

    vma.kbd.set_mode(:tdmodeb)
    unbindkey "tdmodeb", include_child_nodes: true

    keys "ctrl-F8"
    assert_eq 0, child_count, "child binding should be cleared"
    keys "ctrl-F7"
    assert_eq 1, parent_count, "inherited command binding should still fire"
  ensure
    vma.kbd.set_mode(:command)
    unbindkey "C ctrl-F7"
  end

  # ── || (pipe) multi-binding syntax ───────────────────────────────────────

  def test_pipe_syntax_both_keys_trigger_same_action
    count = 0
    reg_act(:_test_pipe, proc { count += 1 }, "test")
    bindkey "C , x a || C , x b", :_test_pipe

    keys ", x a"
    assert_eq 1, count
    keys ", x b"
    assert_eq 2, count
  end

  # ── repeat count ─────────────────────────────────────────────────────────

  # Seed the buffer with `n` numbered lines ("line1".."lineN") and park the
  # cursor at the top. The fresh test buffer is already "\n", so chomp.
  def seed_numbered_lines(n)
    text = (1..n).map { |i| "line#{i}" }.join("\n")
    act "buf.insert_txt(#{text.inspect})"
    act "buf.set_pos(0)"
  end

  # Text of the line the cursor is on.
  def cur_line_text
    vma.buf.to_s.lines[vma.buf.lpos].to_s.chomp
  end

  # "20G" jumps to line 20. Exercises a multi-digit count: each digit folds into
  # next_command_count, then G's counted variant routes to buf.jump_to_line.
  # The "0" matters — it is bound separately from [1-9] (a leading "0" is
  # jump-to-column-0, not a count), so a two-digit count is the case that breaks.
  def test_count_20_G_jumps_to_line_20
    seed_numbered_lines(30)
    keys "2 0 G"
    assert_eq "line20", cur_line_text, "20G should land on line 20"
    assert_pos 19, 0, "20G should put the cursor at the start of line 20"
  end

  # Single-digit count, for contrast: proves the count path itself works, so a
  # failure above is specific to accumulating a second digit.
  def test_count_5_G_jumps_to_line_5
    seed_numbered_lines(30)
    keys "5 G"
    assert_eq "line5", cur_line_text, "5G should land on line 5"
    assert_pos 4, 0, "5G should put the cursor at the start of line 5"
  end

  # esc aborts a count that is being typed, so the digits don't silently attach
  # to the next command ("2 0 0 esc d d" must delete one line, not 200).
  def test_esc_cancels_pending_count
    keys "2 0 0"
    assert_eq 200, vma.kbd.next_command_count, "digits should accumulate into a count"
    keys "esc"
    assert_eq nil, vma.kbd.next_command_count, "esc should cancel the pending count"
  end

  def test_repeat_count_executes_action_n_times
    count = 0
    reg_act(:_test_repeat, proc { count += 1 }, "test")
    bindkey "C , x 9", :_test_repeat

    # Set repeat count to 3 then fire action
    vma.kbd.set_next_command_count(3)
    keys ", x 9"
    assert_eq 3, count, "action should run 3 times with count=3"
  end

  # ── mode switching ───────────────────────────────────────────────────────

  def test_escape_returns_to_command_from_insert
    keys "i"
    assert_mode :insert
    keys "esc"
    assert_mode :command
  end

  def test_i_enters_insert_mode
    assert_mode :command
    keys "i"
    assert_mode :insert
    keys "esc"
  end

  # ── binding to a mode that does not exist ────────────────────────────────

  # A binding for an unknown mode used to be installed silently into the
  # current default mode instead: 'bindkey "fexp , x"' in custom.rb (loaded
  # before FileManager.init creates the fexp mode) became "C , x" and fired in
  # every buffer.
  def test_bindkey_unknown_mode_is_reported_and_binds_nothing
    errors = capture_kbd_errors {
      bindkey "nosuchmode z z", :_test_unknown_mode_action
    }
    assert_eq 1, errors.size, "unknown mode should be reported once: #{errors.inspect}"
    assert errors[0].include?("nosuchmode"), "error should name the mode: #{errors[0]}"
    assert_eq [], find_binding_paths(:_test_unknown_mode_action),
      "nothing should have been bound"
  end

  # Mode part neither all uppercase (major modes) nor all lowercase (minor
  # modes): used to raise NoMethodError on nil while loading custom.rb.
  def test_bindkey_mixed_case_mode_is_reported_and_binds_nothing
    errors = capture_kbd_errors {
      bindkey "Fexp z z", :_test_mixed_case_mode_action
    }
    assert_eq 1, errors.size, "invalid mode should be reported once: #{errors.inspect}"
    assert_eq [], find_binding_paths(:_test_mixed_case_mode_action),
      "nothing should have been bound"
  end

  def test_bindkey_known_minor_mode_binds_to_that_mode
    bindkey "fexp z z", :_test_fexp_action
    assert_eq ["fexp z z"], find_binding_paths(:_test_fexp_action)
    unbindkey "fexp z z"
  end

  private

  # Collect the errors the key binding tree reports while running blk.
  def capture_kbd_errors
    errors = []
    prev = vma.kbd.error_handler
    vma.kbd.error_handler = proc { |msg| errors << msg }
    begin
      yield
    ensure
      vma.kbd.error_handler = prev
    end
    errors
  end

  # Every key sequence in the whole tree bound to action, e.g. ["C , x"]
  def find_binding_paths(action)
    found = []
    walk = lambda { |state, path|
      state.children.each { |c|
        p2 = path + [c.key_name]
        found << p2.join(" ") if c.action == action
        walk.call(c, p2)
      }
    }
    vma.kbd.root.children.each { |mode| walk.call(mode, [mode.key_name]) }
    found
  end

end
