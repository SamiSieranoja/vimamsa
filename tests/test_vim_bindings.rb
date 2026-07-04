# Tests for the vim keybinding scheme.
#
# Run separately: ruby exe/run_tests.rb vim_bindings
# Excluded from the default suite (see exe/run_tests.rb): loading the vim
# scheme permanently rebinds keys in the shared test process.
#
# Oracle tests replay each key sequence in real vim (nvim --headless -u NONE)
# on the same initial text and require an identical resulting buffer.
load "vimamsa/key_bindings_vim.rb" # replaces the vimlike bindings loaded under --test

require "tempfile"

# Match the oracle's noautoindent: vimamsa auto-indents "\n" inserts otherwise
cnf.indent_based_on_last_line = false

class TestVimBindings < VmaTest
  NVIM = %w[nvim vim].find { |c| system("which #{c} > /dev/null 2>&1") }

  # ── oracle tests: same keys into vimamsa and real vim, buffers must match ──

  def test_x_family
    assert_matches_vim("abc\n", "x")
    assert_matches_vim("a\n\nb\n", "jx")  # x on empty line: no-op
    assert_matches_vim("abcd\n", "llX")
    assert_matches_vim("ab\ncd\n", "jX")  # X at col 0: no-op
  end

  def test_dd_and_count
    assert_matches_vim("aa\nbb\ncc\n", "dd")
    assert_matches_vim("a\nb\nc\nd\n", "2dd")
  end

  def test_delete_motions
    assert_matches_vim("foo bar baz\n", "dw")
    assert_matches_vim("foo bar baz\n", "wdw")
    assert_matches_vim("foo bar baz\n", "de")
    assert_matches_vim("abcdef\n", "lld$")
  end

  def test_delete_and_change_to_eol
    assert_matches_vim("abcdef\n", "llD")
    assert_matches_vim("abcdef\n", "llCxy\e")
  end

  def test_change_line
    assert_matches_vim("  old line\nrest\n", "ccnew\e")
    assert_matches_vim("old\nrest\n", "Snew\e")
    assert_matches_vim("a\n\nb\n", "jccx\e") # cc on empty line: guard path
  end

  def test_change_word_and_substitute
    assert_matches_vim("foo bar\n", "cwnew\e")
    assert_matches_vim("abc\n", "sX\e")
  end

  def test_replace_and_case
    assert_matches_vim("abc\n", "rZ")
    assert_matches_vim("aBc\n", "~~")
  end

  def test_join
    assert_matches_vim("aa\nbb\n", "J")
  end

  def test_yank_paste
    assert_matches_vim("aa\nbb\n", "yyp")
    assert_matches_vim("aa\nbb\n", "Yp")
  end

  def test_open_lines
    assert_matches_vim("aa\nbb\n", "ofoo\e")
    assert_matches_vim("aa\nbb\n", "Obar\e")
  end

  def test_insert_variants
    assert_matches_vim("world\n", "ihi \e")
    assert_matches_vim("  hi\n", "A!\e")
    assert_matches_vim("  hi\n", "I>\e")
  end

  def test_first_non_blank
    assert_matches_vim("   abc\n", "$^ix\e")
  end

  def test_motions_with_insert_probe
    assert_matches_vim("a\nb\nc\nd\ne\n", "3jix\e")
    assert_matches_vim("abcdef\n", "fdix\e")
    assert_matches_vim("a\nb\nc\n", "Gdd")
    assert_matches_vim("a\nb\nc\n", "Gggdd")
  end

  def test_undo_after_dd
    assert_matches_vim("aa\nbb\n", "ddu")
  end

  # ── structural tests (approximations / GUI-dependent; no oracle) ──────────

  def test_leader_namespace_gone
    before = vma.buf.to_s
    keys ", b" # vimlike: start_buf_manager; must be inert now
    assert_mode :command
    assert_buf before
  end

  def test_non_vim_chords_gone
    n = bufs.list.size
    keys "ctrl-w"        # vimlike: close_current_buffer
    assert_eq n, bufs.list.size
    keys "i ctrl-w"      # vimlike: close_current_buffer from insert
    assert_eq n, bufs.list.size
    assert_mode :insert
    keys "esc"
  end

  def test_insert_ctrl_c_acts_as_esc
    keys "i"
    assert_mode :insert
    keys "ctrl-c"
    assert_mode :command
  end

  def test_insert_ctrl_h_is_backspace
    keys "i a b ctrl-h"
    assert_buf "a\n"
    keys "esc"
  end

  def test_zz_dispatch
    keys "z z"
    assert_eq :center_on_current_line, vma.kbd.cur_action
  end

  def test_ctrl_o_binding
    assert_eq "ctrl-o", vma.kbd.act_bindings["C"][:jump_to_last_edit]
  end

  def test_backtick_jumps_to_mark
    act 'buf.insert_txt("one\ntwo\nthree\n")'
    act :jump_to_start_of_buffer
    keys "j m a G ` a"
    assert_eq 1, vma.buf.lpos
  end

  def test_ctrl_a_increments
    act 'buf.insert_txt("a 41 b")'
    act :jump_to_start_of_buffer
    keys "w ctrl-a"
    assert_buf "a 42 b\n"
  end

  def test_visual_case_ops
    act 'buf.insert_txt("abc def")'
    act :jump_to_start_of_buffer
    keys "v e U"
    assert_buf "ABC def\n"
  end

  private

  def _setup_test
    create_new_buffer("\n", "test", true)
    vma.kbd.set_mode(:command) rescue nil
    drain_idle
  end

  # vim-style key string -> vimamsa keys() tokens
  def vim_tokens(s)
    s.chars.map { |ch|
      case ch
      when "\e" then "esc"
      when " " then "space"
      when "\r", "\n" then "enter"
      else ch
      end
    }.join(" ")
  end

  # Run `normal! nkeys` in real vim on initial; returns resulting text,
  # nil if no vim available. Array-args system(): raw "\e" bytes are fine.
  def vim_oracle(initial, nkeys)
    return nil unless NVIM
    f = Tempfile.new(["vma_vim_oracle", ".txt"])
    begin
      f.write(initial)
      f.flush
      ok = system(NVIM, "--headless", "-u", "NONE", "-i", "NONE", "-n",
                  "-c", "set noautoindent nosmartindent",
                  "-c", "normal! #{nkeys}",
                  "-c", "wq!", f.path,
                  out: File::NULL, err: File::NULL)
      raise VmaTestFailure, "oracle #{NVIM} failed for #{nkeys.inspect}" unless ok
      IO.read(f.path)
    ensure
      f.close
      f.unlink
    end
  end

  def assert_matches_vim(initial, seq)
    raise VmaTestFailure, "initial must end with \\n" unless initial.end_with?("\n")
    create_new_buffer(initial, "vimoracle", true)
    vma.kbd.set_mode(:command) rescue nil
    vma.buf.set_pos(0) # cursor at line 1 col 1, like vim
    drain_idle
    # Force the synchronous internal-clipboard paste path (as in test_copy_paste)
    vma.macro.instance_variable_set(:@running_macro, true)
    begin
      keys vim_tokens(seq)
    ensure
      vma.macro.instance_variable_set(:@running_macro, false)
    end
    expected = vim_oracle(initial, seq)
    if expected.nil?
      puts "  SKIP oracle (no nvim/vim in PATH)"
      return
    end
    assert_eq expected, vma.buf.to_s,
              "vim mismatch for #{seq.inspect} on #{initial.inspect}\n" \
              "  vim:     #{expected.inspect}\n  vimamsa: #{vma.buf.to_s.inspect}"
  end
end
