class Clipboard
  def initialize
    @clipboard = []
  end

  def [](key)
    return @clipboard[key]
  end

  def <<(str)
    return @clipboard << str
  end

  def set(s)
    if !(s.class <= String) or s.size == 0
      debug s.inspect
      debug [s, s.class, s.size]
      log_error("s.class != String or s.size == 0")
      return
    end
    @clipboard << s
    set_system_clipboard(s)
    vma.register[vma.cur_register] = s
    debug "SET CLIPBOARD: [#{s}]"
    debug "REGISTER: #{vma.cur_register}:#{vma.register[vma.cur_register]}"
  end

  def get()
    return @clipboard[-1]
  end
end

def set_system_clipboard(arg)
  debug arg,2
  vma.gui.window.display.clipboard.set(arg)
end
