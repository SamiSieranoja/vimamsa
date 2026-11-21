module Vimamsa
# Vim operators and motions (doc/vim_compatibility_plan.md, step 1).
#
# The keys are key sets (KeyBindingTree#define_key_set), combined by templates
# in VIM_BINDINGS ("C <op> <motion>", ...), so every operator works with every
# motion and text object. This file has the data (VIM_KEY_SETS), what each
# motion and operator means (VIM_MOTIONS, VIM_OPERATORS), and the Buffer
# methods that compute motion targets and apply operators to a range.
#
# Vim rules followed (vim :help exclusive, :help cw, :help dw):
# - A motion is charwise or linewise, and a charwise motion is inclusive (its
#   target character is included: e, f, t, $) or exclusive (w, b, h, l, 0, ^).
# - An exclusive motion that ends in column 0 of a later line ends at the end
#   of the line before instead. If it started at or before the first non-blank
#   of its line, it becomes linewise.
# - With an operator, w stops at the end of the line of the last word moved
#   over (dw on the last word of a line doesn't join lines).
# - cw on a non-blank works like ce.
# - Counts before the operator and before the motion multiply (2d3w).

# Motion id => properties. desc is used on the key bindings page.
VIM_MOTIONS = {
  char_left: { desc: "character left" },
  char_right: { desc: "character right" },
  line_down: { desc: "line down", linewise: true },
  line_up: { desc: "line up", linewise: true },
  word_next: { desc: "next word start" },
  word_prev: { desc: "previous word start" },
  word_end: { desc: "word end", inclusive: true },
  bigword_next: { desc: "next WORD start" },
  bigword_prev: { desc: "previous WORD start" },
  bigword_end: { desc: "WORD end", inclusive: true },
  line_start: { desc: "line start" },
  line_first_char: { desc: "first non-blank" },
  line_end: { desc: "line end", inclusive: true },
  buf_start: { desc: "first line (<count>: that line)", linewise: true },
  buf_end: { desc: "last line (<count>: that line)", linewise: true },
  find_char: { desc: "to <char>", inclusive: true },
  till_char: { desc: "till <char>", inclusive: true },
  find_char_back: { desc: "back to <char>" },
  till_char_back: { desc: "back till <char>" },
  mark_line: { desc: "line of mark <char>", linewise: true },
  mark: { desc: "mark <char>" },
}

# Operator id => description
VIM_OPERATORS = {
  delete: "delete", change: "change", yank: "copy",
  upcase: "uppercase", downcase: "lowercase", swapcase: "swap case",
  indent: "indent", unindent: "unindent",
}

VIM_TEXTOBJ_DESC = { inner: "inside", around: "around" }

# The key sets of the vim keymap. vimlike uses the same sets, plus its own
# additions (key_set_add before bind_vim_bindings), and gets each
# combination whose keys it doesn't use for something else.
VIM_KEY_SETS = {
  op: {
    "d" => :delete, "c" => :change, "y" => :yank,
    "g U" => :upcase, "g u" => :downcase, "g ~" => :swapcase,
    ">" => :indent, "<" => :unindent,
  },
  motion: {
    "h" => :char_left, "l" => :char_right, "j" => :line_down, "k" => :line_up,
    "w" => :word_next, "b" => :word_prev, "e" => :word_end,
    "W" => :bigword_next, "B" => :bigword_prev, "E" => :bigword_end,
    "0" => :line_start, "^" => :line_first_char, "$" => :line_end,
    "g g" => :buf_start, "G" => :buf_end,
    "f <char>" => :find_char, "t <char>" => :till_char,
    "F <char>" => :find_char_back, "T <char>" => :till_char_back,
    "f space" => { id: :find_char, char: " " }, "t space" => { id: :till_char, char: " " },
    "F space" => { id: :find_char_back, char: " " }, "T space" => { id: :till_char_back, char: " " },
    "' <char>" => :mark_line, "` <char>" => :mark,
  },
  # The object is the typed <char>: w W s p " ' ` ( ) b [ ] { } B < > t
  textobj: { "i <char>" => :inner, "a <char>" => :around },
}

# Text for a key set value on the key bindings page
def key_set_value_desc(set, value)
  case set
  when :op then VIM_OPERATORS[value]
  when :motion then VIM_MOTIONS.dig(value, :desc)
  when :textobj then VIM_TEXTOBJ_DESC[value]
  end || value.to_s
end

class Buffer < String
  # The position motion moves to from pos, or nil if it can't move.
  # count: the typed count, nil if none.
  def vim_motion_target(motion, count, char, pos = @pos)
    n = count || 1
    ls, le = tobj_line_bounds(pos)
    case motion
    when :char_left
      return nil if pos <= ls
      [pos - n, ls].max
    when :char_right
      return nil if pos >= le
      [pos + n, le].min
    when :line_down, :line_up
      l = get_line_pos(pos) + (motion == :line_down ? n : -n)
      return nil if l < 0 || l >= @line_ends.size
      r = line_range(l, 1)
      [r.begin + (pos - ls), r.end].min
    when :word_next, :bigword_next
      big = motion == :bigword_next
      t = pos
      n.times { t = vm_word_next(t, big) }
      t == pos ? nil : t
    when :word_end, :bigword_end
      t = pos
      n.times { t = vm_word_end(t, motion == :bigword_end) || (return nil) }
      t
    when :word_prev, :bigword_prev
      t = pos
      n.times { t = vm_word_prev(t, motion == :bigword_prev) || (return nil) }
      t
    when :line_start then ls
    when :line_first_char then vm_first_non_blank(ls)
    when :line_end
      l = [get_line_pos(pos) + n - 1, @line_ends.size - 1].min
      r = line_range(l, 1)
      r.end > r.begin ? r.end - 1 : r.begin
    when :buf_start, :buf_end
      l = count ? count - 1 : (motion == :buf_start ? 0 : @line_ends.size - 1)
      l = l.clamp(0, @line_ends.size - 1)
      vm_first_non_blank(line_range(l, 1).begin)
    when :find_char, :till_char
      return nil if char.nil?
      t = pos
      n.times { t = index(char, t + 1); return nil if t.nil? || t >= le }
      motion == :till_char ? t - 1 : t
    when :find_char_back, :till_char_back
      return nil if char.nil? || pos == 0
      t = pos
      n.times { t = t > 0 ? rindex(char, t - 1) : nil; return nil if t.nil? || t < ls }
      motion == :till_char_back ? t + 1 : t
    when :mark_line, :mark
      t = @marks[char]
      return nil if t.nil?
      t = [t, size - 1].min
      motion == :mark_line ? vm_first_non_blank(tobj_line_bounds(t)[0]) : t
    end
  end

  # Plain cursor movement and Visual mode extension (the selection follows
  # the cursor)
  def vim_motion_move(motion, count, char)
    t = vim_motion_target(motion, count, char)
    return false if t.nil?
    tobj_set_normal_pos(t)
    true
  end

  # d w, c e, y $, g U f x, > j, ...
  def vim_operator_motion(op, motion, count, char)
    m = VIM_MOTIONS[motion]
    return false if m.nil?
    p = @pos
    linewise = m[:linewise] || false
    inclusive = m[:inclusive] || false
    word = [:word_next, :bigword_next].include?(motion)
    if op == :change && word && !" \t\n".include?(self[p].to_s)
      # cw = ce: change to the end of the word, not including the blanks after
      big = motion == :bigword_next
      t = p
      k = count || 1
      k -= 1 if vm_word_end_at?(p, big)
      k.times { t = vm_word_end(t, big) || t }
      inclusive = true
    else
      t = vim_motion_target(motion, count, char, p)
    end
    return false if t.nil?

    s, e = [p, t].minmax
    if !linewise
      e += 1 if inclusive && self[e] != "\n"
      if word && !inclusive && t > p && get_line_pos(t) > get_line_pos(p) &&
         self[tobj_line_bounds(t)[0]...t].match?(/\A[ \t]*\z/)
        # dw on the last word of a line: stop at the end of that line
        e = [tobj_line_bounds(t)[0] - 1, s].max
      elsif !inclusive && e > s && e < size && (e == 0 || self[e - 1] == "\n") &&
            get_line_pos(e) > get_line_pos(s)
        e -= 1 # end of the line before (its "\n" is not included)
        # (e is now that line's "\n", so the linewise range below ends there)
        linewise = true if s <= vm_first_non_blank(tobj_line_bounds(s)[0])
      end
    end
    # A charwise delete over several lines that starts in the indent and ends
    # at the end of a line deletes whole lines (vim op_delete): d2$ from col 0
    if !linewise && op == :delete && e > s && get_line_pos([e - 1, s].max) > get_line_pos(s)
      le = tobj_line_bounds(e - 1)[1]
      if self[e...le].to_s.match?(/\A[ \t]*\z/) && s <= vm_first_non_blank(tobj_line_bounds(s)[0])
        linewise = true
      end
    end
    # > and < always work on whole lines
    linewise = true if [:indent, :unindent].include?(op)
    if linewise
      s = tobj_line_bounds(s)[0]
      e = tobj_line_bounds(e)[1] + 1
    end
    return false if e <= s
    vim_apply_operator(op, s, e, linewise, from: p)
  end

  # d d, c c, y y, > >, g U U: count lines from the current one. Like vim,
  # nothing happens when there are fewer lines left than the count.
  def vim_operator_lines(op, count)
    l = get_line_pos(@pos)
    l2 = l + (count || 1) - 1
    return false if l2 >= @line_ends.size
    s = line_range(l, 1).begin
    e = line_range(l2, 1).end + 1
    vim_apply_operator(op, s, e, true, from: @pos)
  end

  # Apply op to [s, e) (e exclusive). from: the cursor before the command.
  # Shared with the text objects (text_object_op).
  def vim_apply_operator(op, s, e, linewise, from: @pos)
    e = [e, size].min
    case op
    when :yank
      vma.clipboard.set(self[s...e], linewise: linewise) if e > s
      # The cursor goes to the start of the text, but a linewise yank that
      # starts on the cursor line doesn't move it (y j, y y)
      if !(linewise && tobj_line_bounds(from)[0] == s)
        linewise ? tobj_set_line_pos(s) : set_pos(s)
      end
    when :delete
      return false if e <= s
      txt = self[s...e]
      ds, de = s, e - 1
      # The buffer's final "\n" can't be deleted: for the last lines, take
      # the newline before them instead (vim dap / dd on the last line).
      ds, de = s - 1, e - 2 if linewise && e >= size && s > 0
      Gui.flash_range(self, ds..de) do
        delete_range(ds, de, register: false)
        vma.clipboard.set(txt, linewise: linewise, kind: :delete)
        linewise ? tobj_set_line_pos(ds) : tobj_set_normal_pos(s)
      end
    when :change
      vma.clipboard.set(self[s...e], linewise: linewise, kind: :delete) if e > s
      # Linewise (cc, cip, multi-line ci{): leave an empty line to type on
      if linewise && e >= size && e - 1 > s
        delete_range(s, e - 2, register: false) # the final "\n" stays as that line
      else
        delete_range(s, e - 1, register: false) if e > s
        insert_txt_at("\n", s) if linewise
      end
      set_pos(s)
      vma.kbd.set_mode(:insert)
    when :upcase, :downcase, :swapcase
      return false if e <= s
      old = self[s...e]
      txt = transform_text(old.dup, op)
      replace_range(s..(e - 1), txt) if txt != old
      set_pos(s)
    when :indent, :unindent
      ls = tobj_line_bounds(s)[0]
      le = tobj_line_bounds([e - 1, s].max)[1]
      old = self[ls..le]
      tw = cnf.tab.width!
      new = old.lines.map { |line|
        if op == :indent
          line == "\n" ? line : vm_indent_pad + line
        else
          line.sub(/\A(\t| {1,#{tw}})/, "")
        end
      }.join
      replace_range(ls..le, new) if new != old
      tobj_set_line_pos(ls)
    else
      return false
    end
    true
  end

  private

  def vm_indent_pad
    convert = cnf.tab.to_spaces_default?
    convert = true if cnf.tab.to_spaces_languages?.include?(@lang)
    convert = false if cnf.tab.to_spaces_not_languages?.include?(@lang)
    convert ? " " * cnf.tab.width! : "\t"
  end

  def vm_first_non_blank(ls)
    p = ls
    p += 1 while p < size - 1 && " \t".include?(self[p])
    p
  end

  # Character class for word motions: 0 blank or newline, 1 punctuation,
  # 2 word character. For WORDs (big) every non-blank is 1.
  def vm_cls(p, big)
    ch = self[p]
    return 0 if ch.nil? || ch == " " || ch == "\t" || ch == "\n"
    return 1 if big
    ch.match?(/[\p{L}\p{N}_]/) ? 2 : 1
  end

  # w: start of the next word. An empty line counts as a word; at the end of
  # the buffer, the final "\n".
  def vm_word_next(p, big)
    last = size - 1
    if self[p] != "\n"
      c = vm_cls(p, big)
      p += 1 while p < last && c != 0 && vm_cls(p, big) == c
      p += 1 while p < last && " \t".include?(self[p])
      return p if self[p] != "\n" || p >= last
    end
    loop {
      p += 1
      return last if p >= last
      return p if self[p] == "\n" # empty line
      p += 1 while p < last && " \t".include?(self[p])
      return p if self[p] != "\n"
    }
  end

  # e: end of the word (the next one when already at an end), or nil
  def vm_word_end(p, big)
    last = size - 1
    p += 1
    p += 1 while p < last && vm_cls(p, big) == 0
    return nil if p >= last
    c = vm_cls(p, big)
    p += 1 while p + 1 < last && vm_cls(p + 1, big) == c
    p
  end

  def vm_word_end_at?(p, big)
    c = vm_cls(p, big)
    c != 0 && vm_cls(p + 1, big) != c
  end

  # b: start of the previous word (an empty line counts), or nil at the start
  def vm_word_prev(p, big)
    return nil if p == 0
    p -= 1
    loop {
      ch = self[p]
      break if p == 0
      if ch == " " || ch == "\t"
        p -= 1
      elsif ch == "\n"
        return p if self[p - 1] == "\n" # empty line
        p -= 1
      else
        break
      end
    }
    c = vm_cls(p, big)
    return p if c == 0
    p -= 1 while p > 0 && vm_cls(p - 1, big) == c
    p
  end

  public
end
end # module Vimamsa
