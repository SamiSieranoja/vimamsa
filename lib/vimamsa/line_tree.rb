module Vimamsa

  # The line ends of a buffer, as an implicit treap of lines (see
  # doc/line_tree_plan.md).
  #
  # One node per line, in document order: `len` is the line's length in
  # characters with its "\n", `prio` a random priority (a parent's is higher than
  # its children's), and `cnt` / `sum` the number of lines and characters in the
  # subtree. Line numbers are not stored: a node's line number is the count of
  # lines before it. The last node holds the text after the last "\n" (usually
  # empty), so every position belongs to a node.
  #
  # Answers the Array methods Buffer code uses on @line_ends (size, [i],
  # bsearch_index, bsearch) with the newline positions, so callers don't change.
  # Lookups and edits are O(log n) expected; the old Array needed O(n) per edit.
  class LineTree
    class Node
      attr_accessor :len, :prio, :left, :right, :cnt, :sum

      def initialize(len)
        @len = len
        @prio = rand
        @left = nil
        @right = nil
        @cnt = 1
        @sum = len
      end
    end

    def self.from_string(str)
      lens = []
      str.each_line { |l| lens << l.size }
      lens << 0 if lens.empty? || str.end_with?("\n") # the (empty) text after the last "\n"
      new(lens)
    end

    # lens: the length of each line, "\n" included; the last entry is the text
    # after the last "\n".
    def initialize(lens = [0])
      @root = build(lens)
    end

    # ---------------------------------------------------------------- Array interface

    # Number of "\n" characters (= the size of the old @line_ends Array).
    def size
      @root.cnt - 1
    end

    def length = size
    def empty? = size == 0

    # Position of the i-th "\n" (negative i counts from the end, as in Array).
    def [](i)
      i += size if i < 0
      return nil if i < 0 || i >= size
      line_start(i) + line_len(i) - 1
    end

    def first = self[0]
    def last = self[-1]

    # Array#bsearch_index in find-minimum mode over the "\n" positions: the index
    # of the first position for which the block is true, or nil.
    def bsearch_index
      n = @root
      base = 0      # characters before n's subtree
      idx = 0       # lines before n's subtree
      found = nil
      last_line = size
      while n
        lc = cnt(n.left)
        line_i = idx + lc
        if line_i == last_line
          # The final node has no "\n": it's after every newline, so look left.
          n = n.left
          next
        end
        nl_pos = base + sum(n.left) + n.len - 1
        if yield(nl_pos)
          found = line_i
          n = n.left
        else
          base += sum(n.left) + n.len
          idx = line_i + 1
          n = n.right
        end
      end
      found
    end

    def bsearch(&blk)
      i = bsearch_index(&blk)
      i.nil? ? nil : self[i]
    end

    def to_a
      out = []
      pos = -1
      each_len { |len| pos += len; out << pos }
      out.pop # the final node has no "\n"
      out
    end

    def ==(other)
      other.respond_to?(:to_a) && to_a == other.to_a
    end

    def dup
      LineTree.new(lens)
    end

    def clone(freeze: nil) = dup

    def inspect
      "#<LineTree #{size} newlines, #{total} chars>"
    end

    # ---------------------------------------------------------------- line queries

    def total
      @root.sum
    end

    def line_count
      @root.cnt
    end

    # Character position where line i starts (0 <= i < line_count).
    def line_start(i)
      pos = 0
      n = @root
      while n
        lc = cnt(n.left)
        if i < lc
          n = n.left
        elsif i == lc
          return pos + sum(n.left)
        else
          pos += sum(n.left) + n.len
          i -= lc + 1
          n = n.right
        end
      end
      raise IndexError, "line #{i} out of range"
    end

    # Length of line i, "\n" included.
    def line_len(i)
      node_at(i).len
    end

    # [line, column] of character position p. A position at or past the end
    # belongs to the last line.
    def line_at(p)
      if p >= total
        last = line_count - 1
        return [last, p - line_start(last)]
      end
      p = 0 if p < 0
      line = 0
      n = @root
      while n
        ls = sum(n.left)
        if p < ls
          n = n.left
        elsif p < ls + n.len
          return [line + cnt(n.left), p - ls]
        else
          p -= ls + n.len
          line += cnt(n.left) + 1
          n = n.right
        end
      end
      raise IndexError, "position out of range"
    end

    def lens
      out = []
      each_len { |len| out << len }
      out
    end

    # ---------------------------------------------------------------- edits

    # `text` was inserted at character position pos.
    def insert(pos, text)
      return if text.nil? || text.empty?
      j, c = line_at(pos)
      if !text.include?("\n")
        add_len(j, text.size)
        return
      end
      pieces = text.split("\n", -1) # k newlines -> k + 1 pieces
      old = line_len(j)
      set_len(j, c + pieces[0].size + 1)
      new_lens = pieces[1...-1].map { |s| s.size + 1 }
      new_lens << pieces[-1].size + (old - c) # the rest of line j
      insert_lines(j + 1, new_lens)
    end

    # `text` (the removed text) was deleted at character position pos.
    def delete(pos, text)
      return if text.nil? || text.empty?
      n = text.size
      m = text.count("\n")
      j, c = line_at(pos)
      if m == 0
        add_len(j, -n)
        return
      end
      je = j + m
      ce = pos + n - line_start(je) # where the deletion ends, as a column of line je
      set_len(j, c + (line_len(je) - ce))
      delete_lines(j + 1, m)
    end

    # Raises if heap order or a subtree count is wrong (tests, debugging).
    def check!
      walk = lambda do |n|
        return [0, 0] if n.nil?
        [n.left, n.right].each do |ch|
          raise "heap order broken" if ch && ch.prio > n.prio
        end
        lc, ls = walk.call(n.left)
        rc, rs = walk.call(n.right)
        raise "cnt wrong" if n.cnt != 1 + lc + rc
        raise "sum wrong" if n.sum != n.len + ls + rs
        [n.cnt, n.sum]
      end
      walk.call(@root)
      true
    end

    private

    def cnt(n) = n ? n.cnt : 0
    def sum(n) = n ? n.sum : 0

    def update(n)
      n.cnt = 1 + cnt(n.left) + cnt(n.right)
      n.sum = n.len + sum(n.left) + sum(n.right)
    end

    # In-order lengths, without recursion.
    def each_len
      stack = []
      n = @root
      while n || !stack.empty?
        while n
          stack << n
          n = n.left
        end
        n = stack.pop
        yield n.len
        n = n.right
      end
    end

    def node_at(i)
      n = @root
      while n
        lc = cnt(n.left)
        if i < lc
          n = n.left
        elsif i == lc
          return n
        else
          i -= lc + 1
          n = n.right
        end
      end
      raise IndexError, "line out of range"
    end

    # Path from the root to line i, root first.
    def path_to(i)
      path = []
      n = @root
      while n
        path << n
        lc = cnt(n.left)
        if i < lc
          n = n.left
        elsif i == lc
          return path
        else
          i -= lc + 1
          n = n.right
        end
      end
      raise IndexError, "line out of range"
    end

    def add_len(i, d)
      path = path_to(i)
      path.last.len += d
      path.each { |n| n.sum += d } # only sums change; counts stay
    end

    def set_len(i, len)
      add_len(i, len - line_len(i))
    end

    def insert_lines(i, lens)
      l, r = split(@root, i)
      @root = merge(merge(l, build(lens)), r)
    end

    def delete_lines(i, k)
      l, rest = split(@root, i)
      _mid, r = split(rest, k)
      @root = merge(l, r)
    end

    # [lines 0...i, lines i..]
    def split(n, i)
      return [nil, nil] if n.nil?
      if i <= cnt(n.left)
        l, r = split(n.left, i)
        n.left = r
        update(n)
        [l, n]
      else
        l, r = split(n.right, i - cnt(n.left) - 1)
        n.right = l
        update(n)
        [n, r]
      end
    end

    # Every line of a comes before every line of b.
    def merge(a, b)
      return b if a.nil?
      return a if b.nil?

      if a.prio > b.prio
        a.right = merge(a.right, b)
        update(a)
        a
      else
        b.left = merge(a, b.left)
        update(b)
        b
      end
    end

    # O(k) build from lengths in document order (a Cartesian tree on the
    # priorities, using a stack of the right spine).
    def build(lens)
      stack = []
      lens.each do |len|
        n = Node.new(len)
        last = nil
        while !stack.empty? && stack[-1].prio < n.prio
          last = stack.pop
          update(last)
        end
        n.left = last
        stack[-1].right = n if !stack.empty?
        stack << n
      end
      stack.reverse_each { |s| update(s) }
      stack[0]
    end
  end
end # module Vimamsa
