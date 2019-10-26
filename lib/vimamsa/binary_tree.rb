#!/usr/bin/ruby

require "ripl/multi_line"
# class
$debug = true
$debug = false

# Binary tree representation of the buffer
# This class stores the root node and provides interface to access the tree
# Reason for using binary trees: reduce time complexity of all edit operations from O(N) to O(logN)

class Delta
  attr_accessor :pos, :type, :nchars, :txt

  def initialize(_pos, _type, _nchars, _txt = nil)
    @pos = _pos
    @type = _type
    @nchars = _nchars
    @txt = _txt
  end

  def insert?()
    return @type == INSERT
  end

  def delete?()
    return @type == DELETE
  end
end

class BufferTree
  include Enumerable
  attr_accessor :tree, :buf

  def initialize(_buf = nil)
    @buf = nil
    set_content(_buf) if _buf
  end

  def set_content(_buf)
    @buf = _buf
    t1 = Time.now
    # "sdfsdf\n\nsdf\n\n\n".scan(/([^\n]*\n)/).flatten
    # Same as split("\n"), but returns also empty lines at end
    lines = @buf.scan(/([^\n]*\n)/).flatten
    # lines = @buf.split("\n")
    puts Time.now - t1
    @tree = BNode.new(nil, self, true)
    lines.each { |l| @tree.insert(BData.new(l)) }
    if $debug
      puts "TREE CREATED in time: #{Time.now - t1}"
    end
  end

  def each
    i = 0
    cur = @tree.get_line(0)
    while !cur.nil?
      yield cur
      cur = cur.nextleaf()
    end
    #  buf.bt.each{|x| puts x.startpos..x.endpos}
    #  buf.bt.each{|x| puts buf[x.startpos..x.endpos]}
  end
  
   def each_line
    self.each{|x| yield buf[x.startpos..x.endpos]}
    # buf.bt.each_line{|x| puts x}
   # self.each{|leaf| }
  end
  
  # Change binatry tree structure based on changes (insert, delete) to  buffer contents
  def handle_delta(delta)
    if delta.insert?
      if !delta.txt.include?("\n")
        (snode, pos_on_line) = @tree.find_node_of_char(delta.pos)
        snode.nchar = snode.nchar + delta.nchars
      else
        (snode, pos_on_line) = @tree.find_node_of_char(delta.pos)
        nind = scan_indexes(delta.txt, /\n/)
        # Split current line to two parts: a and b
        a = pos_on_line
        b = snode.nchar - pos_on_line
        snode.nchar = a + nind[0] + 1 # Set length of current line
        to_add = []
        (1..(nind.size - 1)).each { |i| to_add << nind[i] - nind[i - 1] }
        to_add << b + (delta.txt.size - nind[-1] - 1)
        lastnode = snode
        # Insert each new line as new node
        to_add.each { |x| lastnode = lastnode.insert(BData.new(x)) }
      end
    elsif delta.delete?
      nchars_before = @tree.nchar()
      (snode, pos_on_line) = @tree.find_node_of_char(delta.pos)
      lastnode = snode.delete(delta.nchars, pos_on_line)
      snode.reset_size()
      # @tree.recurse("reset_size()")

      nchars_after = @tree.nchar()
      debug("NCHARS before: #{nchars_before} after: #{nchars_after}")

      # Merge nodes
      if lastnode != snode and lastnode.nchar > 0 and snode.nchar > 0
        debug("MERGE TWO NODES OF SIZE: #{snode.data.numchar}, #{lastnode.data.numchar}")
        snode.data.numchar += lastnode.data.numchar
        lastnode.delete_node
      end

      snode.reset_size()

      #Merge first and last nodes
      # @tree.delete(delta.pos, delta.nchars)
    end
    # add_delta([self.size, INSERT, 1, "\n"], true)
    # add_delta([@pos, DELETE, 1], true)
  end

  def left()
    return @tree
  end

  def left=(node)
    @tree = node
  end

  def numlines()
    return @tree.size
  end

  def numchars()
    return @tree.nchar
  end
end

class NullNode
  attr_accessor :parent, :left, :right

  def size()
    return 0
  end

  def nil?()
    return true
  end

  def nchar()
    return 0
  end

  def to_a()
    return []
  end

  def data
    return ""
  end
end

# Organized from right to left. First char of buffer belongs to rightmost node.
class BNode
  # attr_accessor :count, :left, :right, :parent, :_size, :numchar, :data, :pos, :leaf
  attr_accessor :count, :left, :right, :parent, :_size, :data, :pos, :leaf, :cache_chars

  # include Enumerable

  def initialize(s = nil, _parent = nil, _is_root = false)
    @left = NullNode.new()
    @right = NullNode.new()
    @parent = _parent
    @data = nil
    @leaf = false
    @is_root = _is_root
    if !s.nil?
      @data = s
      @leaf = true
    end
    @_size = nil
    @cache_chars = nil
    @pos = nil
  end

  def leaf?()
    return @leaf == true
  end

  # Number of leaf nodes (lines) within this subtree
  def size()
    # puts "cached" if !@_size.nil?
    return @_size if !@_size.nil?
    c = 0
    ls = 0; rs = 0
    ls = @left.size unless @left.nil?
    rs = @right.size unless @right.nil?
    c += 1 if @leaf == true
    c += ls + rs
    if $debug == true
      # lnchar = -1
      # rnchar = -1
      # lnchar = @left.nchar
      # rnchar = @right.nchar
      # puts "ls=#{ls} rs=#{rs} c=#{c} numchar=#{nchar} left.nchar=#{lnchar} right.nchar=#{rnchar}"
    end
    @_size = c
    return @_size
  end

  def nchar=(newnchar)
    if @leaf == true
      @data.numchar = newnchar
      reset_size
    end
  end

  # Number of characters within this subtree
  def nchar()
    # puts "cached" if !@cache_chars.nil?
    if !(@cache_chars.nil?)
      # puts "(cached) numchar=#{@cache_chars} depth=#{depth()} leaf=#{@leaf}"
      return @cache_chars
    end
    c = 0
    if @leaf == true
      c = @data.numchar
    else
      ls = @left.nchar
      rs = @right.nchar
      c = ls + rs
    end

    # + 1 from \n which is not part of data
    if $debug == true
      # puts "ls=#{ls} rs=#{rs} c=#{c} [#{@data.to_s}] depth=#{depth()} leaf=#{@leaf}"
    end
    @cache_chars = c
    # puts "numchar=#{@cache_chars} depth=#{depth()}"
    return @cache_chars
  end

  def rotate()
    return if root? # Don't rotate root node

    if !@left.nil? and !@right.nil?
      ls = @left.size
      rs = @right.size

      a = @left
      b = @right
      c = self
      d = @parent
      newroot = nil

      if rs - ls > 1 # More on right side
        newroot = b

        c.right = b.left
        c.right.parent = c if !c.right.nil?

        b.left = c
      end

      if ls - rs > 1 # More on left side
        newroot = a

        c.left = a.right
        c.left.parent = c if !c.left.nil?

        a.right = c
      end

      if !newroot.nil?
        newroot.parent = c.parent
        c.parent = newroot

        # These should be enough:
        c.reset_size
        # a.reset_size
        # b.reset_size

        if !d.nil?
          d.left = newroot if d.left.equal?(self)
          d.right = newroot if d.right.equal?(self)
        end
      end

      if !d.nil?
        d.rotate
      end
    end
  end

  def reset_size()
    @_size = nil
    @cache_chars = nil
    if !root?
      @parent.reset_size()
    end
    # puts "RESET SIZE (depth=#{depth()}) [#{data.to_s}]"
  end

  def root?()
    return true if @parent.class != BNode
    # return true if @parent.nil?
    return false
  end

  def depth()
    return 0 if root?
    return 1 + @parent.depth()
  end

  def insert(s)
    # nchar()
    @cache_chars = nil
    if @leaf == true
      @right = BNode.new(@data, self)
      @left = BNode.new(s, self)
      @leaf = false
      @data = nil
      newnode = @left
      # @right.parent = self
      # @left.parent = self
      balance()
    elsif right.nil?
      # TODO: Should not come to here? Should be leaf node if right.nil?
      newnode = @right = BNode.new(s, self)
      # @right.parent = self
      balance()
    elsif left.nil?
      newnode = @left = BNode.new(s, self)
      # @left.parent = self
      balance()
    else
      newnode = @left.insert(s)
    end
    return newnode
    # rotate
  end

  def balance()
    reset_size()
    rotate
    reset_size()
    # @parent.balance if !@parent.nil?
  end

  def to_a()
    a = []
    a << @right.to_a unless @right.nil?
    a << @left.to_a unless @left.nil?
    a << @data if @leaf == true
    return a
  end

  def recurse(e)
    @left.recurse(e) unless @left.nil?
    @right.recurse(e) unless @right.nil?
    if !@left.nil? and !@right.nil?
      if @left.size > 4 * @right.size or @right.size > 4 * @left.size
        puts "self.size=#{size} @left.size = #{@left.size} @right.size = #{@right.size}"
      end
    end
    eval(e)
  end

  # Start of range in buffer
  def startpos()
    #TODO: cache?
    return 0 if root?
    return @parent.startpos if rightchild?
    return @parent.startpos + @parent.right.nchar if leftchild?
  end

  def endpos()
    return startpos + (nchar - 1)
  end

  def get_line(i, ind = nil)
    if ind == nil
      ind = nchar()
    end
    if i == 0 and @leaf == true
      @pos = ind - nchar() # Line start pos in buffer
      return self
    end

    if @right.size > i
      return @right.get_line(i, ind - @left.nchar)
    else
      return @left.get_line(i - @right.size, ind)
    end
  end

  # Find that leaf node(line) that includes char at given pos
  def find_node_of_char(pos)
    if leaf?
      if pos > nchar() or pos < 0
        crash("btree: INVALID RANGE")
      end
      return [self, pos]
    end
    if depth >= 5
      puts "FOO"
    end

    if @right.nchar > pos
      return @right.find_node_of_char(pos)
    else
      return @left.find_node_of_char(pos - @right.nchar)
    end
  end

  def line_start(i)
  end

  def leftchild?()
    return true if self.equal?(@parent.left)
  end

  def rightchild?()
    return true if self.equal?(@parent.right)
  end

  def nextleaf()
    # cur = @parent
    prev = cur = self
    # cur = @parent.parent if self.leftchild?

    #TODO: When there is no next leaf
    # Go up until find first branch to left
    while true
      #Left branch but not where we started
      if !cur.left.nil? and !cur.left.equal?(prev)
        prev = cur
        cur = cur.left
        # debug("TAKE LEFT")
        break
      elsif cur.root?
        # debug("No next leaf, self is the last")
        return NullNode.new() # No next leaf, self is the last
      else
        # debug("MOVE UP")
        prev = cur
        cur = cur.parent
      end
    end

    # Then go downwards, taking always right child
    while true
      if cur.leaf? or cur.nil?
        # debug("RET")
        return cur
      else
        cur = cur.right
        # debug("TAKE RIGHT")
      end
    end
    #TODO
  end

  def copyToSelf(fromNode)
    @left = fromNode.left
    @right = fromNode.right
    @left.parent = self
    @right.parent = self
    # @parent = _parent
    @data = fromNode.data
    @leaf = fromNode.leaf
    @_size = fromNode._size
    # @cache_chars = fromNode.numchar
    @cache_chars = nil
    # @pos = fromNode.pos
  end

  def replace_self()
    # Replace self with that child which is not empty
    # (done after leaf node delete)
    if @left.nil? and !@right.nil?
      # replace self with left child
      liftup = @right
    elsif !@left.nil? and @right.nil?
      liftup = @left
    else
      return #TODO: error?
    end

    if leftchild?
      @parent.left = liftup
    elsif rightchild?
      @parent.right = liftup
    end
    liftup.parent = @parent
  end

  def delete_node()
    reset_size()
    @parent.left = nil if leftchild?
    @parent.right = nil if rightchild?
    @parent.replace_self
  end

  # Delete characters, starting from this node
  # Returns the last node (line) that was not completely deleted
  # (either shortened, or not edited at all)
  def delete(delchars, frompos = 0)
    reset_size()
    debug("DELETE delchars=#{delchars} frompos=#{frompos}")
    delete_this_node = false
    lastnode = self

    if delchars > (nchar - frompos)
      delete_from_this_node = (nchar - frompos)
    else
      delete_from_this_node = delchars
    end
    # delete_from_this_node = [delchars, (nchar - frompos)].min

    if delchars > delete_from_this_node
      debug("DELETE STARTING FROM NEXT LINE: delchars=#{delchars - delete_from_this_node} ")
      lastnode = nextleaf.delete(delchars - delete_from_this_node)
      debug("A lastnode = #{lastnode.data}")
    elsif frompos + delchars == nchar
      # End of line is last deleted char => merge with next line
      lastnode = nextleaf
      debug("B lastnode = #{lastnode.data}")
    end

    # Delete all chars from this node => Delete whole node
    if delete_from_this_node == nchar
      debug("DELETE THIS NODE (chars=#{delete_from_this_node}) [#{@data}]")
      delete_node()
    else
      debug("Shorten THIS NODE (depth=#{depth()}) by #{delete_from_this_node} [#{@data}]")
      # Shorten this node
    end
    @data.numchar -= delete_from_this_node
    reset_size()

    return lastnode
  end
end

#TODO: Split leaf node that contains several "\n"
#TODO: find all leaf nodes in range a..b
#TODO: delete leaf node

class BData
  attr_accessor :str, :numchar, :highlights

  # Takes as input a String or a size of String (integer)
  # TODO: convert to using just integer?
  def initialize(a)
    @str = nil
    if a.class == Integer
      @numchar = a
    elsif a.class == String or a.class==Buffer
      @str = a
      @numchar = @str.size
    end
    @highlights = nil
  end

  def to_s()
    @str
  end
end
