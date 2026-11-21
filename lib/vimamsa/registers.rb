module Vimamsa
# Vim registers (doc/vim_compatibility_plan.md, step 4). Each register holds
# text and whether it was copied as whole lines, so a put after yy or dd adds
# lines below or above, wherever the text was copied.
#
#   ""        unnamed: the last copy or delete (also the system clipboard)
#   "0        the last copy (yank)
#   "1 .. "9  the last deletes of whole lines or of text spanning lines,
#             newest in "1 (each delete shifts them down)
#   "-        the last smaller delete
#   "a .. "z  named; "A .. "Z append to them
#   "+ "*     the system clipboard
#   "_        black hole: deleting into it keeps all registers as they are
#
# Select one for the next command with "x (Command and Visual mode): "ayw,
# "ap, "_dd. Insert mode ctrl-r x (vim keymap) inserts a register.
class Registers
  Entry = Struct.new(:text, :linewise)

  NAME_RE = /\A[a-zA-Z0-9"\-+*_]\z/

  # The register selected with "x for the next command, or nil
  attr_reader :pending

  def initialize
    @regs = {}
    @pending = nil
  end

  def valid?(name)
    name.to_s.match?(NAME_RE)
  end

  # "x: use register name for the next copy, delete or put
  def select(name)
    name = name.to_s
    if !valid?(name)
      message("No register #{name.inspect}")
      return false
    end
    @pending = name
    true
  end

  # The pending register, which a command takes: it applies only once
  def take_pending
    r = @pending
    @pending = nil
    r
  end

  def clear_pending
    @pending = nil
  end

  # The entry of a register, or nil. "+ and "* are the system clipboard as
  # far as the editor knows it: the unnamed register (reading the real one
  # is asynchronous, see Buffer#paste).
  def [](name)
    name = name.to_s
    name = '"' if name == "+" || name == "*"
    @regs[name.match?(/\A[A-Z]\z/) ? name.downcase : name]
  end

  # Store copied (kind :yank) or deleted (kind :delete) text, in the register
  # reg, else the pending one, else following vim's rules for the unnamed
  # register. Returns false for the black hole register (nothing stored).
  def store(text, linewise: false, kind: :yank, reg: nil)
    reg ||= take_pending
    return false if reg == "_"
    e = Entry.new(text, linewise)
    case reg
    when nil, '"', "+", "*"
      if kind == :yank
        @regs["0"] = e
      elsif linewise || text.include?("\n")
        8.downto(1) { |i| @regs[(i + 1).to_s] = @regs[i.to_s] if @regs[i.to_s] }
        @regs["1"] = e
      else
        @regs["-"] = e
      end
    when /\A[A-Z]\z/
      old = @regs[reg.downcase]
      e = append(old, e) if old
      @regs[reg.downcase] = e
    else
      @regs[reg] = e
    end
    @regs['"'] = e
    true
  end

  # Names and entries, in the order vim's :registers lists them
  def to_h
    order = ['"', "0", *("1".."9"), "-", *("a".."z")]
    order.filter_map { |n| [n, @regs[n]] if @regs[n] }.to_h
  end

  private

  # "A: linewise if either part is; the old text then ends with a newline
  def append(old, e)
    if old.linewise || e.linewise
      t = old.text.end_with?("\n") ? old.text : old.text + "\n"
      t += e.text
      t += "\n" if !t.end_with?("\n")
      Entry.new(t, true)
    else
      Entry.new(old.text + e.text, false)
    end
  end
end

# A buffer listing the registers (vim :registers)
def show_registers
  lines = vma.registers.to_h.map { |n, e|
    t = e.text.gsub("\n", "^J")
    t = t[0, 70] + "…" if t.size > 70
    "\"#{n}  #{e.linewise ? "l" : "c"}  #{t}"
  }
  s = "Registers (l = whole lines, c = characters)\n\n"
  s += lines.empty? ? "(all empty)\n" : lines.join("\n") + "\n"
  create_new_buffer(s, "registers")
end
end # module Vimamsa
