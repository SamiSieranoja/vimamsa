module Vimamsa
# Form input mode (doc/demo_recording_plan.md, part 1): typing in a form goes
# through the key bindings, so the key log shows it and a demo can record and
# replay it.
#
# A form field is a normal GTK widget (Gtk::Entry) that only shows the text;
# the text and cursor are in a vimamsa Buffer (FormField). The form window's
# keys never reach the widgets: a capture-phase controller turns them into the
# editor's key names (key_names.rb) and gives them to the key bindings, in
# mode F (:form) while the form is up. The form.* actions edit the current
# field's buffer and then show it in the widget.
#
# Changes the widget makes itself (a paste from the right-click menu, a middle
# click, an input method) are copied into the buffer; so are the cursor and a
# selection made with the mouse, read before each key.
#
# Basic keys only (like a GTK entry): typing, backspace, delete, left / right,
# home / end, ctrl-a / ctrl-c / ctrl-x / ctrl-v; tab / shift-tab between the
# fields and buttons, enter submits (or presses the focused button), esc
# cancels.

# One field: a Gtk::Entry showing a Buffer
class FormField
  attr_reader :entry, :buf

  def initialize(entry)
    @entry = entry
    # A Buffer with a view that is never shown, not in the buffer list
    @buf = Buffer.new(entry.text.to_s + "\n", nil, "form-field")
    @buf.set_pos(text.size)
    @sel = nil # [from, to) or nil
    entry.signal_connect("changed") { pull_text if !@syncing }
    sync
  end

  def text
    @buf.to_s.chomp
  end

  def pos
    @buf.pos
  end

  # [from, to) of the selected text, or nil
  attr_reader :sel

  def selected_text
    @sel ? text[@sel[0]...@sel[1]] : nil
  end

  # The widget's cursor and selection (set with the mouse) into the buffer
  def pull_cursor
    return if @syncing
    a, b = entry_selection
    if a && b && a != b
      @sel = [[a, b].min, [a, b].max]
    else
      @sel = nil
    end
    p = @entry.position
    @buf.set_pos(p.clamp(0, text.size)) if p && p != pos
  end

  # Text the widget changed by itself (paste from its menu, input method)
  def pull_text
    t = @entry.text.to_s
    return if t == text
    @buf.delete_range(0, text.size - 1, register: false) if text.size > 0
    @buf.insert_txt_at(t, 0) if t.size > 0
    @buf.set_pos(@entry.position.to_i.clamp(0, text.size))
    @sel = nil
  end

  # The buffer into the widget
  def sync
    @syncing = true
    @entry.text = text if @entry.text.to_s != text
    if @sel
      @entry.select_region(@sel[0], @sel[1])
    else
      @entry.position = pos
    end
  ensure
    @syncing = false
  end

  def insert(s)
    s = s.to_s.gsub(/[\r\n]+/, " ")
    return if s.empty?
    delete_selection
    at = pos
    @buf.insert_txt_at(s, at)
    @buf.set_pos(at + s.size)
  end

  # Deletes the selection; false if there is none
  def delete_selection
    return false if @sel.nil?
    a, b = @sel
    @sel = nil
    @buf.delete_range(a, b - 1, register: false) if b > a
    @buf.set_pos(a)
    true
  end

  def backspace
    return if delete_selection || pos == 0
    at = pos
    @buf.delete_range(at - 1, at - 1, register: false)
    @buf.set_pos(at - 1)
  end

  def delete
    return if delete_selection || pos >= text.size
    @buf.delete_range(pos, pos, register: false)
  end

  def move_to(p)
    @sel = nil
    @buf.set_pos(p.clamp(0, text.size))
  end

  def select_all
    @sel = text.empty? ? nil : [0, text.size]
    @buf.set_pos(text.size)
  end

  # Copy / cut use the system clipboard, not the registers
  def copy
    t = selected_text
    set_system_clipboard(t) if t && !t.empty?
  end

  def cut
    copy
    delete_selection
  end

  # The system clipboard's text at the cursor (over the selection). The
  # clipboard is read asynchronously; the field is shown when it arrives.
  def paste
    vma.gui.window.display.clipboard.read_text_async do |cb, result|
      t = (cb.read_text_finish(result) rescue nil)
      if t && !t.empty?
        insert(t)
        sync
      end
    end
  end

  # Stops the buffer's autosave thread and removes its hidden view
  def dispose
    @buf.instance_variable_get(:@autosave_thread)&.kill
    gui_close_buffer(@buf.id)
  end

  private

  def entry_selection
    r = @entry.selection_bounds
    return [nil, nil] if !r.is_a?(Array)
    r = r[1..] if r.size == 3 # [found, start, end]
    r
  rescue
    [nil, nil]
  end
end

# The form whose window is up: its fields and buttons, in focus order
class FormInput
  class << self
    # The form taking the keys, or nil
    attr_accessor :current
  end

  attr_reader :window, :fields, :items

  # submit: called with no arguments by enter in a field; cancel: by esc
  def initialize(window, submit:, cancel:)
    @window = window
    @submit = submit
    @cancel = cancel
    @fields = []
    @items = [] # fields' entries and buttons, in tab order
    @index = 0
    @last_keyval = nil
    install_key_handler
  end

  def add_field(entry)
    f = FormField.new(entry)
    @fields << f
    @items << entry
    focus_tracking(entry)
    f
  end

  def add_button(button)
    @items << button
    focus_tracking(button)
  end

  # The focused item: a FormField's entry or a button
  def focused
    @items[@index]
  end

  def field
    @fields.find { |f| f.entry.equal?(focused) }
  end

  def focus(i)
    return if @items.empty?
    @index = i % @items.size
    @items[@index].grab_focus
    field&.sync
  end

  def focus_item(widget)
    i = @items.index { |w| w.equal?(widget) }
    focus(i) if i
  end

  def next_item = focus(@index + 1)
  def prev_item = focus(@index - 1)

  # The form takes the keys: mode F
  def activate
    FormInput.current = self
    @prev_stack = vma.kbd.default_mode_stack.dup
    vma.kbd.set_mode(:form)
  end

  # Back to the mode before; the fields' buffers go away (once, also for a
  # form that was never shown)
  def deactivate
    if FormInput.current.equal?(self)
      FormInput.current = nil
      if vma.kbd.get_mode == :form && @prev_stack
        vma.kbd.set_mode_stack(@prev_stack)
        vma.kbd.__set_mode(@prev_stack[-1])
      end
    end
    @fields.each(&:dispose) if !@disposed
    @disposed = true
  end

  # enter: press the focused button, or submit
  def enter
    w = focused
    if w.is_a?(Gtk::Button)
      w.signal_emit("clicked")
    else
      @submit.call
    end
  end

  def cancel
    @cancel.call
  end

  # A key of the form window, as the editor window does it
  # (VSourceView#handle_key_event): released alone, "ctrl!" etc.
  def key(keyval, keystr, sig)
    f = field
    f&.pull_cursor
    k = gui_key_name(keyval, keystr)
    return if k == ""
    if sig == :key_release
      vma.kbd.match_key_conf(k + "!", nil, :key_release) if keyval == @last_keyval
    else
      vma.kbd.match_key_conf(k, nil, :key_press)
    end
    @last_keyval = keyval
  end

  private

  def install_key_handler
    press = Gtk::EventControllerKey.new
    press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
    @window.add_controller(press)
    to_str = lambda { |kv| Gdk::Keyval.to_unicode(kv).chr("UTF-8") }
    press.signal_connect("key-pressed") { |_c, keyval, _code, _st|
      run_dialog_callback("form key") { key(keyval, to_str.(keyval), :key_press) }
      true
    }
    press.signal_connect("key-released") { |_c, keyval, _code, _st|
      run_dialog_callback("form key") { key(keyval, to_str.(keyval), :key_release) }
      true
    }
    press.signal_connect("modifiers") { |_c, modtype| gui_set_modifiers(modtype); true }
  end

  # A click (or GTK moving the focus) makes the item current
  def focus_tracking(widget)
    fc = Gtk::EventControllerFocus.new
    fc.signal_connect("enter") {
      i = @items.index { |w| w.equal?(widget) }
      @index = i if i
    }
    widget.add_controller(fc)
  end
end

# The current form's field, or nil (form.* actions)
def form_field
  FormInput.current&.field
end

# Mode F, the form.* actions and their keys. Called by Editor#start after the
# keymap is loaded (and by vimamsa --help), so every scheme has them.
def form_input_setup
  # editor-wide: not saved in the buffer's mode stack
  vma.kbd.add_mode("F", :form, scope: :editor)
  f = lambda { |&blk| proc { |*a| (x = form_field) && blk.call(x, *a) } }
  reg_act("form.insert.char", f.call { |x, c| x.insert(c) }, "Form: insert <char>")
  reg_act("form.insert.space", f.call { |x| x.insert(" ") }, "Form: insert a space")
  reg_act("form.backspace", f.call { |x| x.backspace }, "Form: delete the char before the cursor")
  reg_act("form.delete", f.call { |x| x.delete }, "Form: delete the char at the cursor")
  reg_act("form.left", f.call { |x| x.move_to(x.pos - 1) }, "Form: cursor left")
  reg_act("form.right", f.call { |x| x.move_to(x.pos + 1) }, "Form: cursor right")
  reg_act("form.home", f.call { |x| x.move_to(0) }, "Form: cursor to the start of the field")
  reg_act("form.end", f.call { |x| x.move_to(x.text.size) }, "Form: cursor to the end of the field")
  reg_act("form.select_all", f.call { |x| x.select_all }, "Form: select the whole field")
  reg_act("form.copy", f.call { |x| x.copy }, "Form: copy the selection")
  reg_act("form.cut", f.call { |x| x.cut }, "Form: cut the selection")
  reg_act("form.paste", f.call { |x| x.paste }, "Form: paste")
  reg_act("form.next", proc { FormInput.current&.next_item }, "Form: next field or button")
  reg_act("form.prev", proc { FormInput.current&.prev_item }, "Form: previous field or button")
  reg_act("form.enter", proc { FormInput.current&.enter }, "Form: submit, or press the focused button")
  reg_act("form.cancel", proc { FormInput.current&.cancel }, "Form: cancel")
  bind_form_field_keys("F")
  # The field shows its buffer after every action, also for keys that don't
  # come from the form window (a demo, tests)
  if !$form_input_watched
    $form_input_watched = true
    vma.kbd.on(:action_handled) { |*_| FormInput.current&.field&.sync }
  end
  add_keys "form cat:edit", {
    "F tab" => "form.next",
    "F shift-tab" => "form.prev",
    "F enter" => "form.enter",
    "F esc" => "form.cancel",
  }
end

# The basic field editing keys, for mode (shared with the command line's
# mode later: doc/demo_recording_plan.md)
def bind_form_field_keys(mode)
  add_keys "form cat:edit", {
    "#{mode} <char>" => "form.insert.char",
    "#{mode} space" => "form.insert.space",
    "#{mode} backspace" => "form.backspace",
    "#{mode} delete" => "form.delete",
    "#{mode} left" => "form.left",
    "#{mode} right" => "form.right",
    "#{mode} home" => "form.home",
    "#{mode} end" => "form.end",
    "#{mode} ctrl-a" => "form.select_all",
    "#{mode} ctrl-c" => "form.copy",
    "#{mode} ctrl-x" => "form.cut",
    "#{mode} ctrl-v" => "form.paste",
  }
end
end # module Vimamsa
