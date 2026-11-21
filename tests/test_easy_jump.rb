# Easy jump (s): labels at line and word starts; typing one jumps there
# (easy_jump.rb)
class TestEasyJump < VmaTest
  TEXT = "first line here\nsecond line\nthird one\nfourth\n"

  def setup_buf
    act "buf.insert_txt(#{TEXT.inspect})"
    keys "g g"
    vma.buf.view.handle_deltas
    20.times { drain_idle; sleep 0.02 } # laid out: labels only what's visible
  end

  def ej
    EasyJump.class_variable_get(:@@cur)
  end

  # The label of the start of line l (0-based)
  def label_index(l)
    ls = l == 0 ? 0 : vma.buf.line_ends[l - 1] + 1
    ej.instance_variable_get(:@easy_jump_wsmarks).index(ls)
  end

  def seq(i)
    ej.instance_variable_get(:@jump_sequence)[i]
  end

  # A failed test must not leave easy jump waiting for keys
  def teardown_ej
    vma.kbd.remove_keyhandling_override
    vma.gui.clear_overlay
  end

  def drain_for(secs)
    t = Time.now
    while Time.now - t < secs
      drain_idle
      sleep 0.01
    end
  end

  # After the first key, the matching labels show it bright and bold, the
  # others are dimmed
  def test_typed_key_highlighted
    setup_buf
    keys "s"
    i = label_index(2)
    s = seq(i)
    keys s[0].downcase
    # (a label set with markup returns the markup as its text)
    assert_eq ej.label_markup(s, 1), ej.labels[i].label
    assert ej.labels[i].label.include?("foreground='#{EasyJump::TYPED_FG}' weight='heavy'>#{s[0]}<"), ej.labels[i].label
    other = ej.labels.each_index.find { |k| !seq(k).to_s.start_with?(s[0]) }
    assert other, "no label that doesn't match #{s[0]}"
    assert_eq ej.label_markup(seq(other), 0, dim: true), ej.labels[other].label
    assert ej.labels[other].label.include?("alpha="), ej.labels[other].label
    keys s[1].downcase
    assert_eq vma.buf.line_ends[1] + 1, vma.buf.pos
  ensure
    teardown_ej
  end

  # The chosen label stays a moment after the others are gone
  def test_chosen_label_stays_briefly
    setup_buf
    keys "s"
    i = label_index(1)
    s = seq(i)
    labels = ej.labels
    keys s.downcase.chars.join(" ")
    chosen = labels[i]
    assert chosen.parent, "chosen label removed at once"
    assert labels.each_with_index.all? { |l, k| k == i || l.parent.nil? }, "other labels still shown"
    da = chosen.parent
    drain_for(EasyJump::CHOSEN_SECS + 0.25)
    assert da.parent.nil?, "chosen label still shown after #{EasyJump::CHOSEN_SECS} s"
  ensure
    teardown_ej
  end

  # cnf.easy_jump.glow (off by default: slower without a GPU)
  def test_labels_with_glow
    old = cnf.easy_jump.glow?
    cnf.easy_jump.glow = true
    setup_buf
    keys "s"
    assert ej.labels.size > 0
    assert ej.labels.all? { |l| l.has_css_class?("overlay-label") }
    keys "esc"
  ensure
    teardown_ej
    cnf.easy_jump.glow = old
  end
end
