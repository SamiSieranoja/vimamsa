
module Vimamsa
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

  # Copied (kind :yank) or deleted (kind :delete) text: into the registers
  # (Registers#store: the pending "x register, else vim's rules) and the
  # system clipboard. linewise: copied as whole lines (yy, dd), so a put adds
  # lines. Nothing happens for the black hole register "_.
  def set(s, linewise: false, kind: :yank)
    if !(s.class <= String) or s.size == 0
      debug s.inspect
      debug [s, s.class, s.size]
      log_error("s.class != String or s.size == 0")
      return
    end
    return if !vma.registers.store(s, linewise: linewise, kind: kind)
    @clipboard << s
    set_system_clipboard(s)
    debug "SET CLIPBOARD: [#{s}]"
  end

  def get()
    return @clipboard[-1]
  end
end

def set_system_clipboard(arg)
  debug arg,2
  vma.gui.window.display.clipboard.set(arg)
end
end # module Vimamsa
