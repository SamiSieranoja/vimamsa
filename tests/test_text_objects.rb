require "tmpdir"

# Vim text objects (text_objects.rb). Each case: [text with "|" at the
# cursor, vim keys, expected text, expected cursor offset]. The expected
# values come from vim 9.1 (vim -Nu NONE); test_cases_match_real_vim checks
# them again when vim is installed.
class TestTextObjects < VmaTest
  CASES = [
    ["foo b|ar baz", "diw", "foo  baz\n", 4],
    ["foo b|ar baz", "daw", "foo baz\n", 4],
    ["foo b|ar", "daw", "foo\n", 2],
    ["  |foo", "daw", "  \n", 1],
    ["foo   |  bar", "daw", "foo\n", 2],
    ["foo  |  bar", "diw", "foobar\n", 3],
    ["foo.b|ar", "diw", "foo.\n", 3],
    ["foo x.b|ar(1) z", "diW", "foo  z\n", 4],
    ["foo x.b|ar(1) z", "daW", "foo z\n", 4],
    ["foo bar  |\n", "daw", "foo bar  \n", 8],
    ["say \"h|i\" now", "di\"", "say \"\" now\n", 5],
    ["say \"h|i\" now", "da\"", "say now\n", 4],
    ["say \"hi|\"", "da\"", "say\n", 2],
    ["\"a\" |x \"b\"", "di\"", "\"a\"\"b\"\n", 3],
    ["x |y \"a\" \"b\"", "di\"", "x y \"\" \"b\"\n", 5],
    ["a \"q\" |b", "da\"", "a \"q\" b\n", 6],
    ["it's |a 'q'", "di'", "it''q'\n", 3],
    ["a `c|d` b", "di`", "a `` b\n", 3],
    ["say \"|\"", "ci\"Z", "say \"Z\"\n", 5],
    ["a(b,|c)d", "di(", "a()d\n", 2],
    ["a(b,|c)d", "da(", "ad\n", 1],
    ["a(b,|c)d", "dib", "a()d\n", 2],
    ["a(b,|c)d", "di)", "a()d\n", 2],
    ["a|(b)d", "di(", "a()d\n", 2],
    ["x (a) |y (b)", "di(", "x (a) y ()\n", 9],
    ["x (a (|b) c)", "2di(", "x ()\n", 3],
    ["a [x|y] b", "di[", "a [] b\n", 3],
    ["a [x|y] b", "da]", "a  b\n", 2],
    ["f {\n  a|b\n  c\n}\nz", "di{", "f {\n}\nz\n", 4],
    ["f {\n  a|b\n  c\n}\nz", "da{", "f \nz\n", 1],
    ["f { a|b }\nz", "diB", "f {}\nz\n", 3],
    ["x <a|b> y", "di<", "x <> y\n", 3],
    ["x\nf(a,\n  |b)\nz", "di(", "x\nf()\nz\n", 4],
    ["a(|)b", "ci(Z", "a(Z)b\n", 2],
    ["f {\n  a|b\n}\nz", "ci{Z", "f {\nZ\n}\nz\n", 4],
    ["x()|y", "di(", "x()y\n", 3],
    ["<a><b>x|y</b></a>", "dit", "<a><b></b></a>\n", 6],
    ["<a><b>x|y</b></a>", "dat", "<a></a>\n", 3],
    ["<a><b>xy</b>|z</a>", "dit", "<a></a>\n", 3],
    ["<a x=\"1\">|<br>q</a>", "dit", "<a x=\"1\"></a>\n", 9],
    ["<a><b>x|y</b></a>", "2dit", "<a></a>\n", 3],
    ["Hi there. This |is it. And more.", "dis", "Hi there.  And more.\n", 10],
    ["Hi there. This |is it. And more.", "das", "Hi there. And more.\n", 10],
    ["Hi there. This is it. And |more.", "das", "Hi there. This is it.\n", 20],
    ["p1\np|1b\n\n\np2", "dip", "\n\np2\n", 0],
    ["p1\np|1b\n\n\np2", "dap", "p2\n", 0],
    ["p1\n\np2\np|2b", "dap", "p1\n", 0],
    ["p1\n|\n\np2", "dip", "p1\np2\n", 3],
    ["p1\n|\n\np2", "dap", "p1\n", 0],
    ["p1\np|1b\n\np2", "cipZ", "Z\n\np2\n", 0],
    ["ab|c d", "gUiw", "ABC d\n", 0],
    ["x (a|B) y", "g~i(", "x (Ab) y\n", 3],
    ["X 'A|B'", "gua'", "X 'ab'\n", 1],
    ["a [x|y] b", "vi[d", "a [] b\n", 3],
    ["foo b|ar baz", "vawd", "foo baz\n", 4],
    ["p1\np|1b\n\np2", "vipd", "\np2\n", 0],
    ["say \"h|i\" now", "va\"d", "say now\n", 4],
  ]

  # Cases that end in Insert mode: the cursor after esc differs from vim's
  # (vim -es stays in Insert mode), so only the text is compared.
  def inserts?(keys)
    keys =~ /^(\d*)c/
  end

  def run_case(text, keys)
    pre, rest = text.split("|", 2)
    s = pre + rest
    s += "\n" unless s.end_with?("\n")
    pos = pre.size
    # vim's Normal mode cursor can't be on the newline of a non-empty line
    pos -= 1 if s[pos] == "\n" && pos > 0 && s[pos - 1] != "\n"
    b = vma.buf
    b.set_content(s)
    b.set_pos(pos)
    vma.kbd.set_mode(:command)
    k = keys.chars
    k << "esc" if inserts?(keys)
    keys(k.join(" "))
    [b.to_s, b.pos]
  end

  def test_cases
    fails = []
    CASES.each { |text, keys, want, want_pos|
      got, got_pos = run_case(text, keys)
      ok = got == want && (inserts?(keys) || got_pos == want_pos)
      fails << "#{text.inspect} #{keys}: got #{got.inspect} pos #{got_pos}, vim #{want.inspect} pos #{want_pos}" if !ok
      vma.kbd.set_mode(:command)
    }
    assert fails.empty?, "#{fails.size} of #{CASES.size} cases differ from vim:\n  " + fails.join("\n  ")
  end

  def test_yank_word
    run_case("x foo|bar y", "yiw")
    assert_eq "foobar", vma.clipboard.get
    assert_eq 2, vma.buf.pos
    assert_buf "x foobar y\n"
  end

  def test_yank_paragraph_is_linewise
    run_case("p1\np|1b\n\np2", "yip")
    assert_eq "p1\np1b\n", vma.clipboard.get
    assert vma.registers['"'].linewise, "yip should yank whole lines"
  end

  def test_delete_puts_text_in_clipboard
    run_case('say "h|i" now', 'di"')
    assert_eq "hi", vma.clipboard.get
  end

  def test_change_enters_insert_mode
    vma.buf.set_content("a(b,c)d\n")
    vma.buf.set_pos(4)
    keys("c i (")
    assert_mode :insert
    assert_buf "a()d\n"
    assert_eq 2, vma.buf.pos
  end

  def test_no_object_changes_nothing
    run_case("plain| text", "di(")
    assert_buf "plain text\n"
    assert_mode :command
  end

  def test_visual_append_bindings_still_work
    # vimlike's Visual "a y" (copy, append to clipboard) shares the "a" prefix
    vma.clipboard.set("old")
    run_case("ab|cd", "v")
    keys("l a y")
    assert_eq "cd\nold", vma.clipboard.get
  end

  def vim_result(text, keys)
    pre, rest = text.split("|", 2)
    Dir.mktmpdir { |d|
      f = "#{d}/f.txt"
      File.write(f, pre + rest + (rest.end_with?("\n") ? "" : "\n"))
      k = keys.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
      system("vim", "-Nu", "NONE", "-i", "NONE", "-es", "-c", "go #{pre.bytesize + 1}",
             "-c", "exe \"norm! #{k}\"",
             "-c", "call writefile([line2byte(line('.'))+col('.')-2], '#{d}/p')", "-c", "wq", f)
      [File.read(f), File.read("#{d}/p").to_i]
    }
  end

  def test_cases_match_real_vim
    skip "vim not installed" unless system("command -v vim >/dev/null 2>&1")
    fails = CASES.reject { |text, keys, want, want_pos|
      vim_result(text, keys) == [want, want_pos]
    }
    assert fails.empty?, "expected values out of date for this vim: #{fails.map { |c| c[0, 2] }.inspect}"
  end
end
