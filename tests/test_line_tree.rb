require "benchmark"

# LineTree: the treap that holds a buffer's line ends (lib/vimamsa/line_tree.rb,
# doc/line_tree_plan.md).
class TestLineTree < VmaTest
  def newline_positions(s)
    out = []
    s.each_char.with_index { |c, i| out << i if c == "\n" }
    out
  end

  def test_from_string
    assert_eq [], LineTree.from_string("").to_a
    assert_eq [2], LineTree.from_string("ab\n").to_a
    assert_eq [2, 3], LineTree.from_string("ab\n\ncd").to_a
    t = LineTree.from_string("ab\n\ncd")
    assert_eq 2, t.size
    assert_eq 6, t.total
    assert_eq [2, 1], t.line_at(5)
    assert_eq [2, 2], t.line_at(6) # the end belongs to the last line
  end

  # Random inserts and deletes, including non-ASCII text and newlines, compared
  # with the newline positions of a String after every step.
  def test_random_edits_match_string
    rng = Random.new(7)
    alpha = ["a", "b", "ä", "€", "\n", "\n", "xy", "\n\n", "q\nr", "ö\nä\n"]
    40.times do
      s = Array.new(rng.rand(0..20)) { alpha.sample(random: rng) }.join
      t = LineTree.from_string(s)
      40.times do
        if rng.rand < 0.55 || s.empty?
          pos = rng.rand(0..s.size)
          txt = Array.new(rng.rand(1..4)) { alpha.sample(random: rng) }.join
          s.insert(pos, txt)
          t.insert(pos, txt)
        else
          pos = rng.rand(0...s.size)
          removed = s.slice!(pos, rng.rand(1..[6, s.size - pos].min))
          t.delete(pos, removed)
        end
        ref = newline_positions(s)
        assert_eq ref, t.to_a, "after edits, text #{s.inspect}"
        assert t.check!
        assert_eq s.size, t.total
      end
    end
  end

  def test_array_interface_matches_array
    s = "ab\n\nc€d\nx\n\nlast"
    ref = newline_positions(s)
    t = LineTree.from_string(s)
    assert_eq ref.size, t.size
    (-ref.size - 1..ref.size).each { |i| assert_eq ref[i], t[i], "[#{i}]" }
    (0..s.size + 1).each do |p|
      assert_eq ref.bsearch_index { |x| x >= p }, t.bsearch_index { |x| x >= p }, "bsearch_index #{p}"
      assert_eq ref.bsearch { |x| x > p }, t.bsearch { |x| x > p }, "bsearch #{p}"
    end
  end

  def test_buffer_edits_keep_line_ends
    act 'buf.insert_txt("one\ntwo\nthree\n")'
    keys "g g d d"
    keys "p"
    act 'buf.insert_txt("x\ny")'
    b = vma.buf
    assert_eq newline_positions(b.to_s), b.line_ends.to_a
    act "undo.last"
    act "undo.last"
    b = vma.buf
    assert_eq newline_positions(b.to_s), b.line_ends.to_a
  end

  # The old Array took about 6 ms per edit at 100k lines (it shifted every later
  # entry); the tree needs microseconds. The bound is loose for slow machines.
  def test_edit_cost_does_not_grow_with_lines
    t = LineTree.from_string("the quick brown fox jumps over the lazy dog 0123456789\n" * 100_000)
    mid = t.total / 2
    sec = Benchmark.realtime { 1000.times { |k| t.insert(mid + k, "x") } }
    assert sec < 0.5, "1000 inserts took #{sec.round(3)} s"
    sec = Benchmark.realtime { 200.times { t.insert(mid, "ab\ncd\n") } }
    assert sec < 0.5, "200 newline inserts took #{sec.round(3)} s"
    assert_eq 100_400, t.size
  end
end
