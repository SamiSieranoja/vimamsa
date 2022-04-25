
def save_buffer_list()
  message("Save buffer list")
  buffn = get_dot_path("buffers.txt")
  f = File.open(buffn, "w")
  bufstr = $buffers.collect { |buf| buf.fname }.inspect
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

class BufferList < Array
  attr_reader :current_buf


  def <<(_buf)
    super
    $buffer = _buf
    @current_buf = self.size - 1
    $buffer_history << @current_buf
    @recent_ind = 0
    $hook.call(:change_buffer, $buffer)
    gui_set_current_buffer($buffer.id)
    gui_set_cursor_pos($buffer.id, $buffer.pos)
  end

  def switch()
    debug "SWITCH BUF. bufsize:#{self.size}, curbuf: #{@current_buf}"
    @current_buf += 1
    @current_buf = 0 if @current_buf >= self.size
    m = method("switch")
    set_last_command({ method: m, params: [] })
    set_current_buffer(@current_buf)
  end

  def switch_to_last_buf()
    debug "SWITCH TO LAST BUF:"
    debug $buffer_history
    last_buf = $buffer_history[-2]
    if last_buf
      set_current_buffer(last_buf)
    end
  end

  def get_buffer_by_filename(fname)
    #TODO: check using stat/inode?  http://ruby-doc.org/core-1.9.3/File/Stat.html#method-i-ino
    buf_idx = self.index { |b| b.fname == fname }
    return buf_idx
  end
  
   def get_buffer_by_id(id)
    buf_idx = self.index { |b| b.id == id }
    return buf_idx
  end
 

  def add_current_buf_to_history()
    @recent_ind = 0
    $buffer_history << @current_buf
    compact_buf_history()
  end

  def set_current_buffer(buffer_i, update_history = true)
    buffer_i = self.size -1 if buffer_i > self.size
    buffer_i = 0 if buffer_i < 0
    $buffer = self[buffer_i]
    return if !$buffer
    @current_buf = buffer_i
    debug "SWITCH BUF2. bufsize:#{self.size}, curbuf: #{@current_buf}"
    fpath = $buffer.fname
    if fpath and fpath.size > 50
      fpath = fpath[-50..-1]
    end

    if update_history
      add_current_buf_to_history
    end

    $hook.call(:change_buffer, $buffer)
    $buffer.set_active

    gui_set_current_buffer($buffer.id)
    gui_set_window_title($buffer.title,$buffer.subtitle)   

    # hpt_scan_images() if $debug # experimental
  end

  def get_last_dir
    lastdir = nil
    if $buffer.fname
      lastdir = File.dirname($buffer.fname)
    else
      for bufid in $buffer_history.reverse[1..-1]
        bf = $buffers[bufid]
        debug "FNAME:#{bf.fname}"
        if bf.fname
          lastdir = File.dirname(bf.fname)
          break
        end
      end
    end
    lastdir = File.expand_path(".") if lastdir.nil?
    return lastdir
  end

  def get_recent_buffers()
    bufs = []; b = {}
    $buffer_history.reverse.each { |x| bufs << x if !b[x] && x < self.size; b[x] = true }
    return bufs
  end

  def history_switch_backwards()
    recent = get_recent_buffers()
    @recent_ind += 1
    @recent_ind = 0 if @recent_ind >= recent.size
    bufid = recent[@recent_ind]
    debug "IND:#{@recent_ind} RECENT:#{recent.join(" ")}"
    set_current_buffer(bufid, false)
  end

  def history_switch_forwards()
    recent = get_recent_buffers()
    @recent_ind -= 1
    @recent_ind = self.size - 1 if @recent_ind < 0
    bufid = recent[@recent_ind]
    debug "IND:#{@recent_ind} RECENT:#{recent.join(" ")}"
    set_current_buffer(bufid, false)
  end

  def compact_buf_history()
    h = {}
    # Keep only first occurence in history
    bh = $buffer_history.reverse.select { |x| r = h[x] == nil; h[x] = true; r }
    $buffer_history = bh.reverse
  end


  # Close buffer in the background
  # TODO: if open in another widget
  def close_other_buffer(buffer_i)
    return if self.size <= buffer_i
    return if @current_buf == buffer_i
    
    bufname = self[buffer_i].basename
    message("Closed buffer #{bufname}")

    self.slice!(buffer_i)
    $buffer_history = $buffer_history.collect { |x| r = x; r = x - 1 if x > buffer_i; r = nil if x == buffer_i; r }.compact

  end


  def close_buffer(buffer_i, from_recent = false)
    return if self.size <= buffer_i
    
    bufname = self[buffer_i].basename
    message("Closed buffer #{bufname}")
    recent = get_recent_buffers
    jump_to_buf = recent[@recent_ind + 1]
    jump_to_buf = 0 if jump_to_buf == nil

    self.slice!(buffer_i)
    $buffer_history = $buffer_history.collect { |x| r = x; r = x - 1 if x > buffer_i; r = nil if x == buffer_i; r }.compact

    if @current_buf == buffer_i
      if from_recent
        @current_buf = jump_to_buf
      else
        @current_buf = $buffer_history.last
      end
    end
    # Ripl.start :binding => binding
    if self.size == 0
      self << Buffer.new("\n")
      @current_buf = 0
    else
      @current_buf = 0 if @current_buf >= self.size
    end
    set_current_buffer(@current_buf, false)
  end

  def close_all_buffers()
    message("Closing all buffers")
    while true
      if self.size == 1
        close_buffer(0)
        break
      else
        close_buffer(0)
      end
    end
    # self << Buffer.new("\n")
  end

  def close_scrap_buffers()
    i = 0
    while i < self.size
      if !self[i].pathname
        close_buffer(i)
      else
        i += 1
      end
    end
  end

  def close_current_buffer(from_recent = false)
    close_buffer(@current_buf, from_recent)
  end

  def delete_current_buffer(from_recent = false)
    fn = buf.fname
    close_buffer(@current_buf, from_recent)
    #TODO: confirm with user, "Do you want to delete file X"
    if is_existing_file(fn)
      message("Deleting file: #{fn}")
      File.delete(fn)
    end
  end
end
