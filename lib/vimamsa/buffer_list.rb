def save_buffer_list()
  message("Save buffer list")
  buffn = get_dot_path("buffers.txt")
  f = File.open(buffn, "w")
  bufstr = vma.buffers.list.collect { |buf| buf.fname }.inspect
  f.write(bufstr)
  f.close()
end

def load_buffer_list()
  message("Load buffer list")
  buffn = get_dot_path("buffers.txt")
  return if !File.exist?(buffn)
  bufstr = IO.read(buffn)
  bufl = eval(bufstr)
  debug bufl
  for b in bufl
    load_buffer(b) if b != nil and File.file?(b)
  end
end

class BufferList
  attr_reader :current_buf, :last_dir, :last_file, :buffer_history
  attr_accessor :list

  def initialize()
    @last_dir = File.expand_path(".")
    @buffer_history = []
    super
    @current_buf = 0
    @list = []
    @h = {}
    reset_navigation
  end

  # lastdir = File.expand_path(".") if lastdir.nil?
  def <<(_buf)
    vma.buf = _buf
    self.add(_buf)

    $hook.call(:change_buffer, vma.buf)
    vma.gui.set_current_buffer(vma.buf.id) #TODO: handle elswhere?
    # vma.buf.view.set_cursor_pos(vma.buf.pos)  #TODO: handle elswhere?
    update_last_dir(_buf)
  end

  def add(_buf)
    @buffer_history << _buf.id
    # @navigation_idx = _buf.id #TODO:??
    @list << _buf
    @h[_buf.id] = _buf
  end

  #NOTE: unused. enable?
  # def switch()
  # debug "SWITCH BUF. bufsize:#{self.size}, curbuf: #{@current_buf}"
  # @current_buf += 1
  # @current_buf = 0 if @current_buf >= self.size
  # m = method("switch")
  # set_last_command({ method: m, params: [] })
  # set_current_buffer(@current_buf)
  # end

  def slist
    # TODO: implement using heap/priorityque
    @list.sort_by! { |x| x.access_time }
  end

  def each(&block)
    for x in slist
      block.call(x)
    end
  end

  def get_last_visited_id
    last_buf = nil
    for i in 0..(slist.size - 1)
      next if slist[i].is_active?
      last_buf = slist[i].id
    end
    return last_buf
  end

  def switch_to_last_buf()
    debug "SWITCH TO LAST BUF:"
    # debug @buffer_history
    # last_buf = @buffer_history[-2]

    last_buf = slist[-2]
    if !last_buf.nil?
      set_current_buffer(last_buf.id)
    end
  end

  def size
    return @list.size
  end

  def get_buffer_by_filename(fname)
    #TODO: check using stat/inode?  http://ruby-doc.org/core-1.9.3/File/Stat.html#method-i-ino
    b = @list.find { |b| b.fname == fname }
    return b.id unless b.nil?
    return nil
  end

  def get_buffer_by_id(id)
    return @h[id]
  end

  def add_buf_to_history(buf_idx)
    if @list.include?(buf_idx)
      @buffer_history << @buf_idx
      @navigation_idx = 0
      # compact_buf_history()
    else
      debug "buffer_list, no such id:#{buf_idx}"
      return
    end
  end

  def add_current_buf_to_history()
    @h[@current_buf].update_access_time
  end

  def set_current_buffer_by_id(idx, update_history = true)
    set_current_buffer(idx, update_history)
  end

  def set_current_buffer(idx, update_history = true)
    # Set update_history = false if we are only browsing

    if !vma.buf.nil? and vma.kbd.get_scope != :editor
      # Save keyboard mode status of old buffer when switching buffer
      vma.buf.mode_stack = vma.kbd.default_mode_stack.clone
    end
    return if !@h[idx]
    vma.buf = bu = @h[idx]
    update_last_dir(vma.buf)
    @current_buf = idx
    debug "SWITCH BUF. bufsize:#{@list.size}, curbuf: #{@current_buf}"

    vma.hook.call(:change_buffer, vma.buf)

    bu.set_active # TODO
    bu.update_access_time if update_history
    vma.gui.set_current_buffer(idx)

    #TODO: delete?
    # if !vma.buf.mode_stack.nil? and vma.kbd.get_scope != :editor #TODO
    # debug "set kbd mode stack #{vma.buf.mode_stack}  #{vma.buf.id}", 2
    # Reload previously saved keyboard mode status
    # vma.kbd.set_mode_stack(vma.buf.mode_stack.clone) #TODO:needed?
    # vma.kbd.set_mode_stack([vma.buf.default_mode])
    # end
    # vma.kbd.set_mode_to_default if vma.kbd.get_scope != :editor

    vma.buf.refresh_title

    if vma.buf.fname
      @last_dir = File.dirname(vma.buf.fname)
    end

    # hpt_scan_images() if cnf.debug? # experimental
    return bu
  end

  def to_s
    return self.class.to_s
  end

  def update_last_dir(buf)
    if buf.fname
      @last_dir = File.dirname(buf.fname)
      @last_file = buf.fname
    end
  end

  def last_dir=(d)
    @last_dir = d
  end

  def get_last_dir
    return @last_dir
  end

  def reset_navigation
    @navigation_idx = 0
  end

  def history_switch(dir = -1)
    # -1: from newest towards oldest
    # +1: from oldest towards newest

    @navigation_idx += dir * -1
    @navigation_idx = 0 if @navigation_idx >= list.size
    @navigation_idx = list.size - 1 if @navigation_idx < 0

    # most recent is at end of slist
    b = slist[-1 - @navigation_idx]
    puts "@navigation_idx=#{@navigation_idx}"
    non_active =  slist.select{|x|!x.is_active?}
    return if non_active.size == 0

    # Take another one from the history if buffer is already open in a window (active)
    navtmp = @navigation_idx
    i = 1
    while b.is_active?
      pp "b.is_active b=#{b.id}"
      navtmp += dir * -1
      b = slist[-1 - navtmp]
      if b.nil? # went past the beginning or end of array slist
        # Start from the end
        if navtmp != 0 and dir == -1 # did not already start from the end
          navtmp = 0
          i = 0
          b = slist[-1 - navtmp]
        elsif navtmp == list.size and dir == 1
          navtmp = list.size
          i = 0
          b = slist[-1 - navtmp]
        else
          return # No buffer exists which is not active already
        end
      end
      i += 1
    end
    @navigation_idx = navtmp

    pp "IND:#{@navigation_idx} RECENT:#{slist.collect { |x| x.fname }.join("\n")}"
    set_current_buffer(b.id, false)
  end

  def history_switch_backwards()
    history_switch(-1)
  end

  def history_switch_forwards()
    history_switch(+1)
  end

  def get_last_non_active_buffer
    for bu in slist.reverse
      return bu.id if !bu.is_active?
    end
    return nil
  end

  def close_buffer(idx, from_recent = false, auto_open: true)
    return if idx.nil?
    bu = @h[idx]
    return if bu.nil?

    bufname = bu.basename
    message("Closed buffer #{bufname}")

    @list.delete(@h[idx])
    @h.delete(idx)

    if auto_open
      @current_buf = get_last_non_active_buffer
      if @list.size == 0 or @current_buf.nil?
        bu = Buffer.new("\n")
        add(bu)
        @current_buf = bu.id
      end
      set_current_buffer(@current_buf, false)
    end
  end

  # Close buffer in the background
  def close_other_buffer(idx)
    close_buffer(idx, auto_open: false)
  end

  #TODO
  # def close_all_buffers()
  # message("Closing all buffers")
  # while @list.size > 0
  # if self.size == 1
  # close_buffer(0)
  # break
  # else
  # close_buffer(0)
  # end
  # end
  # # self << Buffer.new("\n")
  # end

  def close_scrap_buffers()
    l = @list.clone
    for bu in l
      if !bu.pathname
        close_buffer(bu.id)
      end
    end
  end

  def close_current_buffer(from_recent = false)
    close_buffer(@current_buf, from_recent)
  end

  def delete_current_buffer(from_recent = false)
    fn = buf.fname
    close_buffer(@current_buf)
    #TODO: confirm with user, "Do you want to delete file X"
    if is_existing_file(fn)
      message("Deleting file: #{fn}")
      File.delete(fn)
    end
  end
end
