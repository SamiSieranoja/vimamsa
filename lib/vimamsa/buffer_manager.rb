class BufferManager
  attr_reader :buf
  @@cur = nil # Current object of class

  def self.cur()
    return @@cur
  end

  def self.init()
    vma.kbd.add_minor_mode("bmgr", :buf_mgr, :command)
    reg_act(:bmgr_select, proc { buf.module.select_line }, "")
    reg_act(:bmgr_close, proc { buf.module.close_selected }, "")

    reg_act(:start_buf_manager, proc { BufferManager.new.run; vma.kbd.set_mode(:buf_mgr) }, "Buffer manager")

    bindkey "bmgr enter", :bmgr_select
    bindkey "bmgr c", :bmgr_close
  end

  def initialize()
    @buf = nil
    @line_to_id = {}
  end

  def buf_of_current_line()
    l = @buf.lpos - @header.size
    return nil if l < 0
    bufid = @line_to_id[l]
    buf_i = vma.buffers.get_buffer_by_id(bufid)
    return buf_i
  end

  def close_selected
    buf_i = buf_of_current_line()
    if buf_i.nil?
      message("buf already closed")
      return
    end
    vma.buffers.close_other_buffer(buf_i)
  end

  def select_line
    buf_i = buf_of_current_line()
    return if buf_i.nil?

    vma.buffers.close_current_buffer()
    vma.buffers.set_current_buffer(buf_i)
    @@cur = nil
  end

  def run
    if !@@cur.nil? #One instance open already
      #Close it
      buf_i = vma.buffers.get_buffer_by_id(@@cur.buf.id)
      vma.buffers.close_buffer(buf_i)
    end
    # Ripl.start :binding => binding
    @@cur = self
    @header = []
    @header << "Current buffers:"
    @header << "keys: <enter> to select, <c> to close buffer"
    @header << "=" * 40

    s = ""
    s << @header.join("\n")
    s << "\n"
    i = 0
    jump_to_line = 0
    for b in vma.buffers.sort_by { |x| x.list_str }
      if b.id == vma.buf.id # current file
      # s << "   "
      jump_to_line = i
      end
      x = b.list_str
      s << "#{x}\n"
      @line_to_id[i] = b.id
      i += 1
    end

    if @buf.nil?
      @buf = create_new_file(nil, s)
      @buf.module = self
      @buf.active_kbd_mode = :buf_mgr
    else
      @buf.set_content(s)
    end
    # Position on the line of the active buffer
    # @buf.set_content(s)
    newlpos=@header.size+jump_to_line
    # vma.buffers.set_current_buffer(vma.buffers.get_buffer_by_id(@buf.id))
    # @buf.set_pos(newlpos)
    # center_on_current_line
    @buf.set_line_and_column_pos(newlpos, 0)
    # Thread.new{sleep 0.1; gui_set_cursor_pos(@buf.id, @buf.pos)}
    # gui_set_cursor_pos(@buf.id, @buf.pos)
    # Thread.new{sleep 0.1; center_on_current_line()} # TODO
  end
end
