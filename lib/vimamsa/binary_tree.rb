#!/usr/bin/ruby

require "ripl/multi_line"
# class
$debug = true
$debug = false

# Binary tree representation of the buffer
# This class stores the root node and provides interface to access the tree
class BufferTree
  attr_accessor :tree

  def initialize(buf = nil)
    set_content(buf) if buf
  end

  def set_content(buf)
    t1 = Time.now
    lines = buf.split("\n")
    puts Time.now - t1
    @tree = BNode.new
    lines.each { |l| @tree.insert(BData.new(l)) }
    if $debug
      puts "TREE CREATED in time: #{Time.now - t1}"
    end
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
end

class BNode
  attr_accessor :count, :left, :right, :parent, :_size, :numchar, :data, :pos

  # include Enumerable

  def initialize(s = nil, _parent = nil)
    @count = 0
    @left = NullNode.new()
    @right = NullNode.new()
    @parent = _parent
    @data = nil
    @leaf = false
    if !s.nil?
      @data = s
      @leaf = true
    end
    @depth = 0
    @_size = nil
    @numchar = nil
    @pos = nil
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
      # lnchar = @left.nchar unless @left.nil?
      # rnchar = @right.nchar unless @right.nil?
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
    ls = 0; rs = 0
    ls = @left.nchar unless @left.nil?
    rs = @right.nchar unless @right.nil?
    c += @data.numchar + 1 if @leaf == true
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
      @pos = ind - nchar()
      return self
    end

    if @right.size > i
      return @right.get_line(i, ind - @left.nchar)
    else
      return @left.get_line(i - @right.size, ind)
    end
  end

  def line_start(i)
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
