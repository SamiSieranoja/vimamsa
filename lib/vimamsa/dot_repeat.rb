module Vimamsa
# Vim "." (doc/vim_compatibility_plan.md, step 4): repeat the last change.
#
# A change is a command run from Command mode that modified the buffer (d w,
# x, p, > >, g U U, ...) or that started Insert or Replace mode (i, a, o, c w,
# R, ...). For the latter, everything done until Insert mode was left belongs
# to the change too: the typed text, backspaces, the key that left. The
# command is kept as the key tree ran it (a string such as
# a.op.motion!({op: :change, motion: :word_next}), or an action id), with its
# count and register, so "." runs exactly the same thing again:
#   c w foo esc   then .   changes the next word to foo
#   3 .           repeats with count 3 instead (for an operator: d w, 3 .
#                 deletes 3 words; for i/a/o: inserts the text 3 times)
# The repeat is one undo step.
#
# Not recorded: commands run from Visual mode (vim repeats those on the same
# amount of text, not done here), undo/redo, macros, and commands that act on
# files, buffers or the view rather than the text.
class DotRepeat
  # The last change: { action:, count:, reg:, typed: [...], changed: }
  attr_reader :last

  NOT_CHANGES = /\A(a\.)?(undo|macro|buf|file|app|debug|help|panel|view|lsp|grep|ack|search|mode\.cmdline)\b/
  TYPING_MODES = [:insert, :replace]

  def initialize
    @last = nil
    @cmd = nil
    @insert = nil
    @replaying = false
  end

  def replaying?
    @replaying
  end

  # KeyBindingTree :key_action: a command is about to run
  def before(action)
    return if @replaying
    if @insert
      @insert[:typed] << action
      return
    end
    @cmd = { action: action, count: vma.kbd.next_command_count, reg: vma.registers.pending,
             buf: vma.buf, version: vma.buf&.edit_version, mode: vma.kbd.get_mode }
  end

  # KeyBindingTree :action_handled: the command finished
  def after(action)
    return if @replaying
    mode = vma.kbd.get_mode
    if @insert
      if !TYPING_MODES.include?(mode)
        @last = @insert
        @insert = nil
      end
      return
    end
    c = @cmd
    @cmd = nil
    return if c.nil? || !c[:action].equal?(action) || c[:mode] != :command
    return if action.class != String || action.match?(NOT_CHANGES)
    changed = vma.buf.equal?(c[:buf]) && vma.buf.edit_version != c[:version]
    if TYPING_MODES.include?(mode)
      @insert = c.merge(typed: [], changed: changed)
    elsif changed
      @last = c.merge(typed: [], changed: true)
    end
  end

  # ".": run the last change again. count: the count typed before ".", which
  # replaces the change's own.
  def repeat(count = nil)
    l = @last
    return false if l.nil?
    b = vma.buf
    kbd = vma.kbd
    @replaying = true
    b.new_undo_group
    b.instance_variable_set(:@macro_group_active, true)
    begin
      vma.registers.select(l[:reg]) if l[:reg]
      typed = l[:typed]
      leave = typed.empty? ? [] : [typed.last]
      body = typed[0...-1] || []
      # An insert command (i, a, o: the text didn't change before typing):
      # the count repeats the typed text. Otherwise it goes to the command.
      insert_cmd = !l[:changed] && typed.any?
      kbd.next_command_count = insert_cmd ? l[:count] : (count || l[:count])
      kbd.handle_key_bindigs_action(l[:action], nil)
      times = insert_cmd ? (count || 1) : 1
      times.times { body.each { |a| exec_action(a) } }
      leave.each { |a| exec_action(a) }
    ensure
      b.instance_variable_set(:@macro_group_active, false)
      b.new_undo_group
      @replaying = false
      # The nested run reset this; "." handles its count itself
      kbd.method_handles_repeat = true
    end
    true
  end
end
end # module Vimamsa
