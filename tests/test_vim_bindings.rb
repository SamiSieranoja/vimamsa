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

  def test_delete_find_char
    assert_matches_vim("foo bar baz\n", "dfa")
    assert_matches_vim("foo bar baz\n", "wdf ")
    assert_matches_vim("foo bar baz\n", "dfz")   # to end of line
    assert_matches_vim("foo\nbar\n", "dfb")     # char only on next line: no-op
    assert_matches_vim("foo bar baz\n", "$dFa")
    assert_matches_vim("foo bar baz\n", "$dF ")
    assert_matches_vim("foo\nbar\n", "j$dFo")   # char only on prev line: no-op
    assert_matches_vim("foo bar\n", "dFf")       # at col 0: no-op
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

  def test_case_operators
    assert_matches_vim("foo bar baz\n", "gUw")
    assert_matches_vim("foo bar baz\n", "llgUw")   # mid-word: to word end
    assert_matches_vim("foo.bar baz\n", "gUw")     # w stops at punctuation
    assert_matches_vim("foo bar baz\n", "wwlgUw")  # last word, no next word
    assert_matches_vim("foo\nbar\n", "llgUw")      # does not reach next line
    assert_matches_vim("foo\n\nbar\n", "jgUw")     # empty line: no-op
    assert_matches_vim("FOO BAR\n", "wguw")
    assert_matches_vim("aB1c\n", "lg~w")
    assert_matches_vim("foo bar\nbaz\n", "wwgUU")
    assert_matches_vim("FOO Bar\nBAZ\n", "jguu")
    assert_matches_vim("a B\n", "g~~")
    assert_matches_vim("foo\n\nbar\n", "jgUU")     # empty line: no-op
    assert_matches_vim("foo bar\n", "wgUwx")      # cursor stays at word start
    assert_matches_vim("foo bar\n", "wgUUx")      # cursor to line start
  end

  # The operator + motion layer (vim_operators.rb): every operator with
  # every motion, counts in both places
  def test_operator_counts
    assert_matches_vim("a b c d e f g\n", "d2w")
    assert_matches_vim("a b c d e f g\n", "2dw")
    assert_matches_vim("a b c d e f g\n", "2d2w")
    assert_matches_vim("a\nb\nc\nd\ne\n", "d2j")
    assert_matches_vim("a\nb\nc\nd\ne\n", "3dd")
    assert_matches_vim("a\nb\nc\n", "5dd")          # more lines than left: no-op
    assert_matches_vim("a\nb\nc\n", "j2dd")
  end

  def test_operator_word_motions
    assert_matches_vim("foo.bar baz\n", "dW")
    assert_matches_vim("foo.bar baz\n", "dE")
    assert_matches_vim("foo bar.baz\n", "$dB")
    assert_matches_vim("foo bar baz\n", "wwdb")
    assert_matches_vim("foo bar\nbaz\n", "wdw")       # last word: not joined
    assert_matches_vim("foo bar\nbaz qux\n", "wd2w")
    assert_matches_vim("foo\n\nbar\n", "dw")
    assert_matches_vim("foo bar\n", "jdb")
    assert_matches_vim("x\n  foo\nbar\n", "jjdb")
    assert_matches_vim("foo bar baz\n", "llcwX\e")    # cw inside a word
    assert_matches_vim("foo bar baz\n", "lllcwX\e")   # cw on a blank
    assert_matches_vim("a bc d\n", "c2wX\e")
    assert_matches_vim("foo bar\n", "yeP")
  end

  def test_operator_line_motions
    assert_matches_vim("x\n  abc def\n", "jwd0")
    assert_matches_vim("x\n  abc def\n", "j$d^")
    assert_matches_vim("abc def\n", "wd$")
    assert_matches_vim("abc\ndef\nghi\n", "d2$")
    assert_matches_vim("abcdef\n", "$dh")
    assert_matches_vim("abcdef\n", "$dl")
    assert_matches_vim("abcdef\n", "d3l")
  end

  def test_operator_find_till
    assert_matches_vim("foo bar baz\n", "dtb")
    assert_matches_vim("foo bar baz\n", "d2fa")
    assert_matches_vim("foo bar baz\n", "$dTo")
    assert_matches_vim("foo bar baz\n", "$dF ")
    assert_matches_vim("foo bar baz\n", "dt ")
    assert_matches_vim("foo bar baz\n", "cfrX\e")
    assert_matches_vim("foo bar baz\n", "gUfr")
  end

  def test_operator_linewise_motions
    assert_matches_vim("a\nb\nc\nd\n", "jdk")
    assert_matches_vim("a\nb\nc\nd\n", "jdG")
    assert_matches_vim("a\nb\nc\nd\n", "jjdgg")
    assert_matches_vim("a\nb\nc\nd\n", "d3G")
    assert_matches_vim("a\nb\nc\n", "yjGp")
    assert_matches_vim("a\nb\nc\n", "jcjX\e")
    assert_matches_vim("a\nb\nc\n", "Gdj")             # can't move: no-op
  end

  def test_indent_operators
    assert_matches_vim("a\nb\nc\n", ">>")
    assert_matches_vim("a\nb\nc\n", "3>>")
    assert_matches_vim("a\n\nc\n", ">j")
    assert_matches_vim("a\n\nc\n", ">2j")              # empty lines stay empty
    assert_matches_vim("\ta\n\tb\n", "<j")
    assert_matches_vim("    a\nb\n", "<<")
    assert_matches_vim("a b\nc\n", ">w")                # > always works on lines
  end

  def test_operator_text_objects_and_case
    assert_matches_vim("foo (bar baz) x\n", "fbd2w")
    assert_matches_vim("foo (bar baz) x\n", "fb>i(")
    assert_matches_vim("foo bar\nbaz\n", "g~j")
    assert_matches_vim("foo bar\n", "gUiw")
    assert_matches_vim("Foo Bar\n", "gu$")
    assert_matches_vim("foo bar\n", "wgUb")
  end

  def test_plain_motions_from_the_layer
    assert_matches_vim("foo.bar baz\n", "Wix\e")
    assert_matches_vim("foo.bar baz\n", "Eix\e")
    assert_matches_vim("foo bar.baz\n", "$Bix\e")
    assert_matches_vim("foo bar baz\n", "tzix\e")
    assert_matches_vim("foo bar baz\n", "$Tfix\e")
    assert_matches_vim("abc\n", "$ix\e")              # $ on the last character
  end

  # "." repeats the last change (dot_repeat.rb)
  def test_dot_repeat
    assert_matches_vim("a b c d e\n", "dw.")
    assert_matches_vim("a b c d e\n", "dw2.")
    assert_matches_vim("one two three\n", "cwfoo\ew.")
    assert_matches_vim("ab\n", "ixy\e0.")         # (vim's esc also moves left; vimamsa's doesn't)
    assert_matches_vim("abcd\n", "x..")
    assert_matches_vim("1\n2\n3\n4\n", "dd.")
    assert_matches_vim("a\nb\n", ">>j.")
    assert_matches_vim("a\nb\n", "A!\ej.")
    assert_matches_vim("a\nb\n", "ox\ej.")
    assert_matches_vim("foo bar\n", "gUiww.")
    assert_matches_vim("a b c\n", "dwlu.")         # undo doesn't replace the change
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
    assert_eq "view.center", vma.kbd.cur_action
  end

  def test_ctrl_o_binding
    assert_eq "ctrl-o", vma.kbd.act_bindings["C"]["jump.edit.prev"]
  end

  def test_backtick_jumps_to_mark
    act 'buf.insert_txt("one\ntwo\nthree\n")'
    act "move.buf.start"
    keys "j m a G ` a"
    assert_eq 1, vma.buf.lpos
  end

  def test_ctrl_a_increments
    act 'buf.insert_txt("a 41 b")'
    act "move.buf.start"
    keys "w ctrl-a"
    assert_buf "a 42 b\n"
  end

  def test_visual_case_ops
    act 'buf.insert_txt("abc def")'
    act "move.buf.start"
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
      # Plain vim has no --headless: use silent ex mode, which starts on the
      # last line, so jump to line 1 first.
      mode = NVIM == "nvim" ? ["--headless"] : ["-E", "-s", "-c", "1"]
      ok = system(NVIM, *mode, "-u", "NONE", "-i", "NONE", "-n",
                  "-c", "set noautoindent nosmartindent sw=4 ts=4",
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
