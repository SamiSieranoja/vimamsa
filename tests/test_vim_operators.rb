# The operator + motion layer in the vimlike keymap (vim_operators.rb,
# doc/vim_compatibility_plan.md step 1). Vimlike gets every combination of
# the shared templates whose keys it doesn't use itself.
#
# CASES: [text with "|" at the cursor, vim keys, expected text, expected
# cursor offset]. The expected values come from vim 9.1 (vim -Nu NONE);
# test_cases_match_real_vim checks them again when vim is installed. The
# vim keymap has its own oracle tests in test_vim_bindings.rb.
require "tmpdir"

class TestVimOperators < VmaTest
  CASES = [
    ["foo b|ar baz", "cwX\e", "foo bX baz\n", 5],
    ["foo bar| baz", "cwX\e", "foo barXbaz\n", 7],
    ["one two three four", "d3w", "four\n", 0],
    ["one two three four", "2d2w", "\n", 0],
    ["foo bar", "gUtr", "FOO BAr\n", 0],
    ["a.b c", "dW", "c\n", 0],
    ["a\nb|\nc", ">>", "a\n\tb\nc\n", 3],
    ["a\nb|\nc", ">j", "a\n\tb\n\tc\n", 3],
    ["\ta\n\tb", "<j", "a\nb\n", 0],
    ["a\nb|\nc\nd", "c2jX\e", "a\nX\n", 2],
    ["one two", "wcbX\e", "Xtwo\n", 0],
    ["x (a b) y", "fa>i(", "\tx (a b) y\n", 1],
    ["ab cd", "c$X\e", "X\n", 0],
    ["foo bar", "cOX\e", "X\n", 0], # vimlike's O motion (line end) after an operator
  ]

  def inserts?(keys)
    keys.include?("\e")
  end

  def vma_keys(keys)
    keys.chars.map { |ch| { "\e" => "esc", " " => "space" }.fetch(ch, ch) }.join(" ")
  end

  # [text before the cursor, from the cursor]; no "|" = cursor at the start
  def split_case(text)
    text.include?("|") ? text.split("|", 2) : ["", text]
  end

  def run_case(text, keys)
    pre, rest = split_case(text)
    s = pre + rest
    s += "\n" unless s.end_with?("\n")
    pos = pre.size
    b = vma.buf
    b.set_content(s)
    b.set_pos(pos)
    vma.kbd.set_mode(:command)
    keys(vma_keys(keys))
    [b.to_s, b.pos]
  end

  def test_cases
    # > and < indent with a tab, as vim -u NONE (other tests change these)
    saved = [cnf.tab.width!, cnf.tab.to_spaces_default?]
    cnf.tab.width = 4
    cnf.tab.to_spaces_default = false
    fails = []
    CASES.each { |text, keys, want, want_pos|
      got, got_pos = run_case(text, keys)
      ok = got == want && (inserts?(keys) || got_pos == want_pos)
      fails << "#{text.inspect} #{keys.inspect}: got #{got.inspect} pos #{got_pos}, vim #{want.inspect} pos #{want_pos}" if !ok
      vma.kbd.set_mode(:command)
    }
    assert fails.empty?, "#{fails.size} of #{CASES.size} cases differ from vim:\n  " + fails.join("\n  ")
  ensure
    cnf.tab.width, cnf.tab.to_spaces_default = saved if saved
  end

  # vimlike's own bindings win over the templates
  def test_vimlike_bindings_kept
    assert_eq "edit.delete.word.end", vma.kbd.find_state_by_path("C d e").action
    assert_eq "op.motion", vma.kbd.find_state_by_path("C c w").action
  end

  # A motion added after the keymap loaded works with every operator
  def test_key_set_add
    vma.kbd.key_set_add(:motion, "Q" => :line_end)
    vma.buf.set_content("abc def\n")
    vma.buf.set_pos(0)
    keys("g U Q")
    assert_buf "ABC DEF\n"
  ensure
    vma.kbd.key_sets[:motion].delete("Q")
    vma.kbd.bindings.select { |b| b[:args] && b[:keys].last == "Q" }.each { |b|
      unbindkey("#{b[:mode]} #{b[:keys].join(" ")}")
    }
    assert vma.kbd.bindings.none? { |b| b[:args] && b[:keys].last == "Q" }, "Q bindings left"
  end

  def vim_result(text, keys)
    pre, rest = split_case(text)
    Dir.mktmpdir { |d|
      f = "#{d}/f.txt"
      File.write(f, pre + rest + (rest.end_with?("\n") ? "" : "\n"))
      k = keys.gsub("\\", "\\\\\\\\").gsub('"', '\\"').gsub("\e", "\\<Esc>")
      system("vim", "-Nu", "NONE", "-i", "NONE", "-es", "-c", "go #{pre.bytesize + 1}",
             "-c", "exe \"norm! #{k}\"",
             "-c", "call writefile([line2byte(line('.'))+col('.')-2], '#{d}/p')", "-c", "wq", f)
      [File.read(f), File.read("#{d}/p").to_i]
    }
  end

  def test_cases_match_real_vim
    skip "vim not installed" unless system("command -v vim >/dev/null 2>&1")
    # A fresh vim per case (no registers, marks or repeat carried over), run
    # in parallel
    cases = CASES.reject { |_t, keys, _w, _p| keys.include?("O") } # vimlike-only motion
    results = cases.map { |text, keys, _w, _p| Thread.new { vim_result(text, keys) } }.map(&:value)
    fails = cases.zip(results).reject { |(_t, keys, want, want_pos), (got, got_pos)|
      got == want && (inserts?(keys) || got_pos == want_pos)
    }
    assert fails.empty?, "expected values out of date for this vim: " +
                         fails.map { |(t, k, _w, _p), r| [t, k, r] }.inspect
  end
end
