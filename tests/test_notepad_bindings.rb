# Tests for the notepad keybinding scheme.
#
# Run separately: ruby exe/run_tests.rb notepad_bindings
# Excluded from the default suite (see exe/run_tests.rb): loading the
# notepad scheme permanently rebinds keys in the shared test process.
load "vimamsa/key_bindings_notepad.rb" # vimlike already required; applies overrides

class TestNotepadBindings < VmaTest
  def test_typing_inserts_in_default_mode
    keys "h i"
    assert_mode :insert
    assert_buf "hi\n"
  end

  def test_esc_clears_selection_stays_insert
    act 'buf.insert_txt("abc")'
    keys "shift-left shift-left"
    assert vma.buf.selection_active?, "shift-left should select"
    keys "esc"
    assert_mode :insert
    assert !vma.buf.selection_active?, "esc should clear selection"
  end

  def test_ctrl_a_selects_all
    act 'buf.insert_txt("hello world")'
    keys "ctrl-a"
    assert vma.buf.selection_active?, "ctrl-a should activate selection"
    r = vma.buf.get_visual_mode_range
    assert_eq 0, r.begin
    assert_eq vma.buf.size - 1, r.end
  end

  def test_delete_forward
    act 'buf.insert_txt("abc")'
    act :jump_to_start_of_buffer
    keys "delete"
    assert_buf "bc\n"
  end

  def test_home_end_keys
    act 'buf.insert_txt("hello")'
    keys "home"
    assert_pos 0, 0
    keys "end"
    assert_eq 5, vma.buf.pos
  end

  def test_rebound_dispatch
    # Assert rebinds without invoking GUI dialogs / quit
    assert_eq "ctrl-f", vma.kbd.act_bindings["I"][:find_in_buffer]
    assert_eq "ctrl-h", vma.kbd.act_bindings["I"][:gui_search_replace]
    assert_eq "ctrl-q", vma.kbd.act_bindings["I"][:quit]
    keys "ctrl-n" # safe to execute: creates a new buffer
    assert_eq :buf_new, vma.kbd.cur_action
    assert_mode :insert
  end

  private

  # Framework default sets :command mode; the notepad scheme is
  # insert-mode based, so make that explicit for each test.
  def _setup_test
    create_new_buffer("\n", "test", true)
    vma.kbd.set_mode(:insert) rescue nil
    drain_idle
  end
end
