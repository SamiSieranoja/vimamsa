#!/usr/bin/ruby

require "ripl/multi_line"
# class
$debug = true
$debug = false

# Binary tree representation of the buffer
# This class stores the root node and provides interface to access the tree

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
  attr_accessor :tree

  def initialize(_buf = nil)
    @buf = nil
    set_content(_buf) if _buf
  end

  def set_content(_buf)
    @buf = _buf
    t1 = Time.now
    lines = @buf.split("\n")
    puts Time.now - t1
    @tree = BNode.new
    lines.each { |l| @tree.insert(BData.new(l + "\n")) }
    if $debug
      puts "TREE CREATED in time: #{Time.now - t1}"
    end
  end

  def handle_delta(delta)
    if delta.insert?
    elsif delta.delete?
      (snode, pos_on_line) = @tree.find_node_of_char(delta.pos)
      lastnode = snode.delete(delta.nchars, pos_on_line)
      # Merge nodes
      if lastnode != snode and lastnode.nchar > 0 and snode.nchar > 0
        snode.data.numchar += lastnode.data.numchar
        lastnode.delete_node
      end

      #Merge first and last nodes
      # @tree.delete(delta.pos, delta.nchars)
    end
    # add_delta([self.size, INSERT, 1, "\n"], true)
    # add_delta([@pos, DELETE, 1], true)
  end

  def numlines()
    return @tree.size
  end

  def numchars()
    return @tree.nchar
  end
end

class NullNode
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
end

# Organized from right to left. First char of buffer belongs to rightmost node.
class BNode
  attr_accessor :count, :left, :right, :parent, :_size, :numchar, :data, :pos, :leaf

  # include Enumerable

  def initialize(s = nil, _parent = nil)
    @left = NullNode.new()
    @right = NullNode.new()
    @parent = _parent
    @data = nil
    @leaf = false
    if !s.nil?
      @data = s
      @leaf = true
    end
    @_size = nil
    @numchar = nil
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
      lnchar = -1
      rnchar = -1
      lnchar = @left.nchar
      rnchar = @right.nchar
      puts "ls=#{ls} rs=#{rs} c=#{c} numchar=#{nchar} left.nchar=#{lnchar} right.nchar=#{rnchar}"
    end
    @_size = c
    return @_size
  end

  # Number of characters within this subtree
  def nchar()
    # puts "cached" if !@numchar.nil?
    return @numchar if !@numchar.nil?
    c = 0
    ls = @left.nchar
    rs = @right.nchar
    c += @data.numchar if @leaf == true
    # + 1 from \n which is not part of data
    c += ls + rs
    if $debug == true
      # puts "ls=#{ls} rs=#{rs} c=#{c}"
    end
    @numchar = c
    return @numchar
  end

  def rotate()
    return if @parent.nil? # Don't rotate root node

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
        b.left = c
      end

      if ls - rs > 1 # More on left side
        newroot = a
        c.left = a.right
        a.right = c
      end

      if newroot
        newroot.parent = @parent
        @parent = newroot

        # newroot._size = nil
        # @_size = nil
        # @numchar = nil
        # newroot.numchar = nil
        reset_size

        if !d.nil?
          d.left = newroot if d.left == self
          d.right = newroot if d.right == self
        end
      end

      if !d.nil?
        d.rotate
      end
    end
  end

  def reset_size()
    @_size = nil
    @numchar = nil
    if !@parent.nil?
      @parent.reset_size
    end
  end

  def insert(s)
    nchar()
    @numchar = nil
    if @leaf == true
      @right = BNode.new(@data, self)
      @left = BNode.new(s, self)
      @leaf = false
      # @right.parent = self
      # @left.parent = self
      balance()
    elsif right.nil?
      @right = BNode.new(s, self)
      # @right.parent = self
      balance()
    elsif left.nil?
      @left = BNode.new(s, self)
      # @left.parent = self
      balance()
    else
      @left.insert(s)
    end
    # rotate
  end

  def balance()
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
    # eval(e)
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
    if @right.nchar >= pos
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
    cur = @parent
    # cur = @parent.parent if self.leftchild?

    # Go up until find first branch to left
    while true
      #Left branch but not where we started
      if !cur.left.nil? and !self.equal?(cur.left)
        cur = cur.left
        break
      else
        cur = cur.parent
      end
    end

    # Then go downwards, taking always right child
    while true
      if cur.leaf? or cur.nil?
        return cur
      else
        cur = cur.right
      end
    end
    #TODO
  end

  def copyToSelf(fromNode)
    @left = fromNode.left
    @right = fromNode.right
    # @parent = _parent
    @data = fromNode.data
    @leaf = fromNode.leaf
    @_size = fromNode._size
    @numchar = fromNode.numchar
    # @pos = fromNode.pos
  end

  def replace_self()
    # Replace self with that child which is not empty
    # TODO: Change ref from parent instead of copy
    if @left.nil? and !@right.nil?
      copyToSelf(@right)
    elsif !@left.nil? and @right.nil?
      copyToSelf(@left)
    end
  end

  def delete_node()
    reset_size()
    @parent.left = nil if leftchild?
    @parent.right = nil if rightchild?
    @parent.replace_self
  end

  # Delete characters, starting from this node
  def delete(delchars, frompos = 0)
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
      debug("DELETE STARTING FROM NEXT LINE: delchars=#{delchars - delete_from_this_node}")
      lastnode = nextleaf.delete(delchars - delete_from_this_node)
    end

    # Delete all chars from this node => Delete whole node
    if delete_from_this_node == nchar
      debug("DELETE THIS NODE (chars=#{delete_from_this_node})")
      delete_node()
      # reset_size()
      # @parent.left = nil if leftchild?
      # @parent.right = nil if rightchild?
      # @parent.replace_self
    else
      debug("Shorten THIS NODE by #{delete_from_this_node}")
      # Shorten this node
    end
    @data.numchar -= delete_from_this_node

    return lastnode

    # if delchars > nchar
    # end

    # if frompos == 0 and delchars > nchar
    # delete_this_node = true

    # debug("DELETE LINE+ delchars=#{delchars} nchar=#{nchar}")
    # # Delete this node and continue to next
    # nextleaf.delete(delchars - nchar)
    # @parent.left = nil if leftchild?
    # @parent.right = nil if rightchild?
    # @parent.replace_self
    # elsif delchars == nchar
    # debug("DELETE LINE delchars=#{delchars} nchar=#{nchar}")
    # # Delete this node but don't continue to next
    # @parent.left = nil if leftchild?
    # @parent.right = nil if rightchild?
    # @parent.replace_self
    # elsif delchars < nchar
    # # Shorten this node
    # debug("SHORTEN LINE BY #{delchars} (#{nchar})")
    # @data.numchar -= delchars
    # end
    # @tree.delete(delta.pos, delta.nchars)
  end

  def handle_delta(d)
    #TODO
  end
end

#TODO: Split leaf node that contains several "\n"
#TODO: find all leaf nodes in range a..b
#TODO: delete leaf node

class BData
  attr_accessor :str, :numchar, :highlights

  def initialize(_str)
    @str = _str
    @numchar = _str.size
    @highlights = nil
  end

  def to_s()
    @str
  end
end
