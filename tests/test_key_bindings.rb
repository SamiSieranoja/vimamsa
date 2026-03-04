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

end
