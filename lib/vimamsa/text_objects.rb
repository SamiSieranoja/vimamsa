module Vimamsa
# Vim text objects. After an operator (d c y gU gu g~) or in Visual mode,
# "i <x>" / "a <x>" acts on a range around the cursor instead of moving it:
#   w W          word / WORD (WORD = any run of non-blank characters)
#   s            sentence
#   p            paragraph (linewise)
#   " ' `        quoted string on the current line
#   ( ) b        ( ) block, may span lines; also [ ], { } B, < >
#   t            XML/HTML tag
# "i" = inner (contents only). "a" = also the delimiters, or the white space
# around, following vim's rules (vim :help text-objects). Checked against
# vim 9.1, including "not inside a ( ) block => use the next one on the line".
class Buffer < String
  TEXT_OBJECT_BRACKETS = {
    "(" => "()", ")" => "()", "b" => "()",
    "[" => "[]", "]" => "[]",
    "{" => "{}", "}" => "{}", "B" => "{}",
    "<" => "<>", ">" => "<>",
  }

  # Range of text object obj ("w", "(", ...) around pos, as
  # [start, end, linewise] with end exclusive (start == end for an empty
  # inner, e.g. i( on "()"), or nil if there is no such object here.
  # count = nesting level for brackets and tags (vim d2i().
  def text_object_range(obj, inner, pos = @pos, count = 1)
    case obj
    when "w" then tobj_word(pos, inner, false)
    when "W" then tobj_word(pos, inner, true)
    when "s" then tobj_sentence(pos, inner)
    when "p" then tobj_paragraph(pos, inner)
    when '"', "'", "`" then tobj_quote(pos, inner, obj)
    when "t" then tobj_tag(pos, inner, count)
    else
      br = TEXT_OBJECT_BRACKETS[obj]
      br && tobj_bracket(pos, inner, br[0], br[1], count)
    end
  end

  # Apply op to a text object, e.g. text_object_op(:delete, "w", :i) = vim diw.
  # op: an operator of VIM_OPERATORS (:delete, :change, :yank, :upcase, ...)
  # or :select (Visual mode: select the object). which: :i (inner) or :a.
  # Returns true if there was an object at the cursor.
  def text_object_op(op, obj, which)
    count = get_repeat_num
    r = text_object_range(obj, which == :i, @pos, count)
    return false if r.nil?
    s, e, linewise = r
    if op == :select
      return false if e <= s
      @selection_start = s
      set_pos(e - 1)
      return true
    end
    # yank / change of an empty inner (yi( on "()") still sets the cursor
    return false if e <= s && ![:yank, :change].include?(op)
    if op == :yank
      vma.clipboard.set(self[s...e], linewise: linewise) if e > s
      set_pos(s)
      return true
    end
    vim_apply_operator(op, s, e, linewise)
  end

  private

  # Like vim Normal mode: the cursor can't stay on a line's newline unless
  # the line is empty.
  def tobj_set_normal_pos(p)
    p = [p, size - 1].min
    p -= 1 if p > 0 and self[p] == "\n" and self[p - 1] != "\n"
    set_pos(p)
  end

  # After a linewise delete: first non-blank of the line holding p (vim)
  def tobj_set_line_pos(p)
    p = [p, size - 1].min
    ls, le = tobj_line_bounds(p)
    p = ls
    p += 1 while p < le && " \t".include?(self[p])
    tobj_set_normal_pos(p)
  end

  # [start of line, position of its "\n"] for the line holding pos
  def tobj_line_bounds(pos)
    ls = pos == 0 ? 0 : (rindex("\n", pos - 1) || -1) + 1
    [ls, index("\n", pos) || size]
  end

  def tobj_word(pos, inner, big)
    ls, le = tobj_line_bounds(pos)
    return nil if pos >= le
    # 0 = blank, 1 = word chars (WORD: any non-blank), 2 = other non-blank
    cls = ->(c) { c == " " || c == "\t" ? 0 : (big || c.match?(/\p{Word}/) ? 1 : 2) }
    run = ->(p) {
      k = cls.(self[p])
      s = p
      s -= 1 while s > ls && cls.(self[s - 1]) == k
      e = p + 1
      e += 1 while e < le && cls.(self[e]) == k
      [s, e]
    }
    s, e = run.(pos)
    return [s, e, false] if inner
    if cls.(self[pos]) == 0 # on blanks: the blanks and the word after them
      return nil if e >= le
      return [s, run.(e)[1], false]
    end
    return [s, run.(e)[1], false] if e < le && cls.(self[e]) == 0 # trailing blanks
    # No trailing blanks: take the leading ones, unless they are the indent
    if s > ls && cls.(self[s - 1]) == 0
      bs = run.(s - 1)[0]
      s = bs if bs > ls
    end
    [s, e, false]
  end

  def tobj_sentence(pos, inner)
    ls, le = tobj_line_bounds(pos)
    return nil if self[ls...le].match?(/\A[ \t]*\z/)
    para = tobj_paragraph(pos, true)
    ps, pe = para[0], para[1] - 1 # pe: the paragraph's last newline
    sents = [] # [start, end of sentence, end of the white space after it]
    i = ps
    i += 1 while i < pe && self[i].match?(/\s/)
    while i < pe
      m = /[.!?][)\]"']*(?=\s|\z)/.match(self[i...pe])
      e = m ? i + m.end(0) : pe
      w = e
      w += 1 while w < pe && self[w].match?(/\s/)
      sents << [i, e, w]
      i = w
    end
    return nil if sents.empty?
    k = sents.rindex { |s, _e, _w| s <= pos } || 0
    s, e, w = sents[k]
    if pos >= e # in the white space after a sentence
      return [e, w, false] if inner
      nxt = sents[k + 1]
      return [e, nxt ? nxt[1] : w, false]
    end
    return [s, e, false] if inner
    return [s, w, false] if w > e
    # Last sentence of the paragraph: take the white space before it
    [k > 0 ? sents[k - 1][1] : s, e, false]
  end

  def tobj_paragraph(pos, inner)
    line_start = ->(p) { p == 0 ? 0 : (rindex("\n", p - 1) || -1) + 1 }
    line_end = ->(l) { (index("\n", l) || size - 1) + 1 } # after its "\n"
    blank = ->(l) { self[l...line_end.(l)].match?(/\A[ \t]*\n?\z/) }
    next_line = ->(l) { n = line_end.(l); n < size ? n : nil }
    prev_line = ->(l) { l == 0 ? nil : line_start.(l - 1) }

    ls = line_start.(pos)
    b = blank.(ls)
    s = ls
    while (pl = prev_line.(s)) && blank.(pl) == b
      s = pl
    end
    e = ls
    while (nl = next_line.(e)) && blank.(nl) == b
      e = nl
    end
    return [s, line_end.(e), true] if inner
    # "a": add the run after it (blank lines after text, text after blanks)
    if (nl = next_line.(e))
      e = nl
      while (n2 = next_line.(e)) && blank.(n2) != b
        e = n2
      end
      return [s, line_end.(e), true]
    end
    # Last paragraph: take the blank lines before it instead
    if !b
      while (pl = prev_line.(s)) && blank.(pl)
        s = pl
      end
    end
    [s, line_end.(e), true]
  end

  def tobj_quote(pos, inner, q)
    ls, le = tobj_line_bounds(pos)
    qs = [] # unescaped quote chars on the line
    i = ls
    while i < le
      if self[i] == "\\"
        i += 2
        next
      end
      qs << i if self[i] == q
      i += 1
    end
    if (k = qs.index(pos))
      # On a quote: which pair it belongs to is counted from the line start
      o, c = k.even? ? [pos, qs[k + 1]] : [qs[k - 1], pos]
    elsif (k = qs.rindex { |x| x < pos })
      o, c = qs[k], qs[k + 1]
    else # no quote before the cursor: the first string after it
      o, c = qs[0], qs[1]
    end
    return nil if o.nil? || c.nil?
    return [o + 1, c, false] if inner
    s, e = o, c + 1
    w = e
    w += 1 while w < le && " \t".include?(self[w])
    if w > e
      e = w
    else
      s -= 1 while s > ls && " \t".include?(self[s - 1])
    end
    [s, e, false]
  end

  def tobj_bracket(pos, inner, op, cl, count)
    o = tobj_find_open(pos, op, cl, count)
    if o.nil? && count == 1
      # Not inside a block: use the next one on the line (as vim 9.1)
      _ls, le = tobj_line_bounds(pos)
      nx = index(op, pos)
      o = nx if nx && nx < le
    end
    return nil if o.nil?
    c = tobj_match_close(o, op, cl)
    return nil if c.nil?
    return [o, c + 1, false] if !inner
    s, e = o + 1, c
    # "(" ending its line / ")" first on its line: those lines aren't part
    # of the inner text, so di{ on a multi-line block keeps "{\n}".
    starts_line = self[s] == "\n"
    s += 1 if starts_line
    nl = rindex("\n", c - 1)
    ends_line = nl && nl >= o + 1 && self[(nl + 1)...c].match?(/\A[ \t]*\z/)
    e = nl + 1 if ends_line
    e = s if e < s
    [s, e, starts_line && ends_line && e > s]
  end

  # Position of the count'th unmatched op enclosing pos (pos itself if on op)
  def tobj_find_open(pos, op, cl, count)
    o = nil
    i = pos - 1
    if self[pos] == op
      o = pos
      count -= 1
    end
    while count > 0
      depth = 0
      found = nil
      while i >= 0
        ch = self[i]
        if ch == cl
          depth += 1
        elsif ch == op
          if depth == 0
            found = i
            break
          end
          depth -= 1
        end
        i -= 1
      end
      return nil if found.nil?
      o = found
      count -= 1
      i = found - 1
    end
    o
  end

  def tobj_match_close(o, op, cl)
    depth = 0
    i = o + 1
    while i < size
      ch = self[i]
      if ch == op
        depth += 1
      elsif ch == cl
        return i if depth == 0
        depth -= 1
      end
      i += 1
    end
    nil
  end

  def tobj_tag(pos, inner, count)
    pairs = [] # [outer start, inner start, inner end, outer end]
    stack = []
    to_s.scan(/<(\/?)([A-Za-z][\w:.-]*)[^<>]*?(\/?)>/) {
      m = $~
      next if m[3] == "/" # <br/>
      if m[1] == ""
        stack << [m[2], m.begin(0), m.end(0)]
      elsif (k = stack.rindex { |t| t[0] == m[2] })
        t = stack[k]
        stack = stack[0...k] # drops unclosed tags inside, e.g. <br>
        pairs << [t[1], t[2], m.begin(0), m.end(0)]
      end
    }
    enc = pairs.select { |os, _is, _ie, oe| os <= pos && pos < oe }.sort_by { |os, _is, _ie, oe| oe - os }
    t = enc[count - 1]
    return nil if t.nil?
    inner ? [t[1], t[2], false] : [t[0], t[3], false]
  end

  public
end

end
