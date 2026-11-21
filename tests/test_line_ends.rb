require "benchmark"

# scan_indexes / line ends on non-ASCII text (scan_indexes used to be O(n^2)
# there), and get_line_end (used to scan all line ends).
class TestLineEnds < VmaTest
  # The old implementation, kept as the reference.
  def ref_scan_indexes(txt, regex)
    txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) }
  end

  def test_scan_indexes_matches_reference_on_utf8
    txt = "äö foo\nbär baz\n\n€ x\ty\nlast"
    [/\n/, /\S/, /(?<=[^\p{Word}])\p{Word}|\Z/, /(?<=\p{Word})[^\p{Word}]/, /\n[ \t]*\n/, /z/].each do |re|
      assert_eq ref_scan_indexes(txt, re), scan_indexes(txt, re), "regex #{re.inspect}"
    end
  end

  def test_scan_indexes_ascii_unchanged
    txt = "foo bar\nbaz\n"
    assert_eq ref_scan_indexes(txt, /\n/), scan_indexes(txt, /\n/)
  end

  def test_line_ends_of_utf8_buffer
    act 'buf.insert_txt("äb\nc€d\n\nlast")'
    b = vma.buf
    assert_eq ref_scan_indexes(b.to_s, /\n/), b.line_ends.to_a
    assert_eq 2, b.get_line_end(0)
    assert_eq 6, b.get_line_end(3)
    assert_eq 7, b.get_line_end(6)
  end

  def test_get_line_end_matches_select
    act 'buf.insert_txt("a\nbb\n\nccc\nd")'
    b = vma.buf
    (0...b.size).each do |pos|
      assert_eq b.line_ends.to_a.select { |x| x > pos }.min, b.get_line_end(pos), "pos #{pos}"
    end
  end

  # 3 MB with one non-ASCII character: the old code took seconds (13 s at
  # 5.5 MB), the new one well under 0.1 s. The bound is loose for slow
  # machines (the test VM once took 1.0 s).
  def test_scan_indexes_utf8_is_not_quadratic
    txt = "ä" + ("the quick brown fox jumps over the lazy dog 0123456789\n" * 55_000)
    res = nil
    t = Benchmark.realtime { res = scan_indexes(txt, /\n/) }
    assert_eq 55_000, res.size
    assert_eq txt.size - 1, res.last
    assert t < 2.0, "scan_indexes took #{t.round(2)} s for 3 MB of UTF-8"
  end
end
