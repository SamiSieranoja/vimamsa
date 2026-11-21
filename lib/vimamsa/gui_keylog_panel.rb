
module Vimamsa
# Right-side panel that live-logs pressed key chords and the actions they
# trigger. Meant for demos and for new users learning the key bindings.
# Fed by direct calls from KeyBindingTree (log_action / log_pending /
# log_nomatch); all of them are no-ops unless the panel is shown (@active).
class KeyLogPanel
  MAX_ENTRIES = 200

  # Test-visible model: array of hashes, one per row (newest last;
  # displayed newest first). kind: :action | :pending | :insert | :nomatch | :mode
  attr_reader :entries

  # The highlighted Gtk::ListBoxRow of the newest entry
  attr_reader :newest_row

  # Demo controls (Help ▸ Play demo), shown while a demo plays
  attr_reader :demo_bar, :demo_pause_btn, :demo_speed_lbl, :close_btn, :demo_list

  # The bubble next to the cursor with the newest entry (gui_key_hint.rb)
  attr_reader :hint

  # Insert-mode typing arrives as eval-string actions like buf.insert_txt('h');
  # matched here so consecutive chars can be coalesced into one "typed:" row.
  INSERT_TXT_RE = /\Abuf\.insert_txt\((.+)\)\z/

  # A named action bound to a <char> key, as the key tree runs it:
  # a.edit.insert.char!('h') (KeyBindingTree#match_key_conf)
  CHAR_ACTION_RE = /\Aa\.([a-z][a-z0-9_.]*)!\((.+)\)\z/

  def initialize
    @entries = []
    @rows = []       # Gtk::ListBoxRow per entry, parallel to @entries
                     # (newest last, like @entries; displayed newest first)
    @active = false
    @last_mode = nil # last seen mode badge, e.g. "[COMMAND]"
    @newest_row = nil
    @hint = KeyHint.new

    @list = Gtk::ListBox.new
    @list.selection_mode = :none

    # Highlight for the newest row (color from gui_theme.rb, cnf-backed)
    @row_css = Gtk::CssProvider.new
    @row_css.load(data: keylog_row_css)

    @sw = Gtk::ScrolledWindow.new
    @sw.set_policy(:never, :automatic)
    @sw.set_child(@list)
    @sw.vexpand = true

    title = Gtk::Label.new("<span weight='ultrabold' size='large'>Key log</span>")
    title.use_markup = true
    title.xalign = 0.0
    title.hexpand = true

    clear_btn = Gtk::Button.new(label: "Clear")
    clear_btn.signal_connect("clicked") { clear }

    # Closes the panel (and stops a demo, whose controls are here)
    @close_btn = Gtk::Button.new(label: "✕")
    @close_btn.tooltip_text = "Close the key log"
    @close_btn.focus_on_click = false
    @close_btn.signal_connect("clicked") { close }

    header = Gtk::Box.new(:horizontal, 6)
    header.margin_start = 8
    header.margin_end = 6
    header.margin_top = 6
    header.margin_bottom = 4
    header.append(title)
    header.append(clear_btn)
    header.append(@close_btn)

    # @box is the outermost widget: header on top, scrollable log below.
    @box = Gtk::Box.new(:vertical, 0)
    @box.set_size_request(320, -1)
    @box.add_css_class("side-panel")
    @box.append(header)
    @box.append(demo_bar_init)
    @box.append(@sw)
  end

  # The ✕ button: hides the panel, stopping a demo that plays
  def close
    DemoPlayer.current.stop("Demo stopped") if DemoPlayer.current&.running?
    vma.gui.hide_keylog_panel
  end

  # Pause / continue, slower and faster for DemoPlayer. The buttons
  # don't take the focus, so the editor keeps getting the keys.
  def demo_bar_init
    btn = lambda { |label, tip, &blk|
      b = Gtk::Button.new(label: label)
      b.focus_on_click = false
      b.tooltip_text = tip
      b.signal_connect("clicked") { blk.call }
      b
    }
    @demo_pause_btn = btn.call("Pause", "Pause or continue the demo") { call_action("help.demo.pause") }
    slower = btn.call("−", "Slower") { call_action("help.demo.slower") }
    faster = btn.call("+", "Faster") { call_action("help.demo.faster") }
    @demo_speed_lbl = Gtk::Label.new("1×")
    @demo_speed_lbl.width_chars = 5

    # The demos (DemoPlayer.demos, recorded ones too); choosing one switches
    # to it
    @demo_names = DemoPlayer::DEMOS.keys
    @demo_list = Gtk::DropDown.new(Gtk::StringList.new(DemoPlayer::DEMOS.values.map { |d| d[:title] }), nil)
    @demo_list.tooltip_text = "Switch to another demo"
    @demo_list.focusable = false
    @demo_list.hexpand = true
    @demo_list.signal_connect("notify::selected") {
      name = @demo_names[@demo_list.selected]
      cur = DemoPlayer.current
      if !@demo_list_updating && name && cur&.running? && cur.name != name
        GLib::Idle.add { DemoPlayer.toggle(name); false }
      end
    }

    title = Gtk::Label.new("Demo")
    title.xalign = 0.0

    # Two rows (the demo list, then the buttons), so the panel keeps its width
    list_row = Gtk::Box.new(:horizontal, 6)
    [title, @demo_list].each { |w| list_row.append(w) }
    spacer = Gtk::Label.new("")
    spacer.hexpand = true
    btn_row = Gtk::Box.new(:horizontal, 4)
    [spacer, @demo_pause_btn, slower, @demo_speed_lbl, faster].each { |w| btn_row.append(w) }

    @demo_bar = Gtk::Box.new(:vertical, 4)
    @demo_bar.margin_start = 8
    @demo_bar.margin_end = 6
    @demo_bar.margin_bottom = 4
    [list_row, btn_row].each { |w| @demo_bar.append(w) }
    @demo_bar.visible = false
    @demo_bar
  end

  def show_demo_controls(paused:, rate:, demo: nil)
    @demo_pause_btn.label = paused ? "Continue" : "Pause"
    @demo_speed_lbl.label = rate
    refresh_demo_list
    i = @demo_names.index(demo)
    if i && @demo_list.selected != i
      @demo_list_updating = true
      @demo_list.selected = i
      @demo_list_updating = false
    end
    @demo_bar.visible = true
  end

  # The demo list again if demos were recorded since
  def refresh_demo_list
    demos = DemoPlayer.demos
    return if demos.keys == @demo_names
    @demo_list_updating = true
    @demo_names = demos.keys
    @demo_list.model = Gtk::StringList.new(demos.values.map { |d| d[:title] })
    @demo_list_updating = false
  end

  def hide_demo_controls
    @demo_bar.visible = false
  end

  # Returns the outermost widget to embed in the paned layout.
  def widget
    @box
  end

  def active?
    @active
  end

  # First row currently displayed (should be the newest); used by tests.
  def top_row
    @list.first_child
  end

  def set_active(v)
    @active = v
    @hint.hide if !v
  end

  # Re-read the newest-row highlight color from cnf and reload it live.
  def refresh_css
    @row_css.load(data: keylog_row_css)
  end

  def clear
    @entries.clear
    @rows.each { |r| @list.remove(r) }
    @rows.clear
    @last_mode = nil
    @newest_row = nil
  end

  # ── logging API, called from key_binding_tree.rb ──────────────────────────

  # A key chord completed and an action is about to execute.
  # trail_str is e.g. "[COMMAND] g g"; action is a Symbol, Proc or eval string.
  def log_action(trail_str, action)
    return unless @active
    if action.class == String && (m = INSERT_TXT_RE.match(action))
      log_insert_char(unquote(m[1]))
      return
    end
    if action.class == String && (m = CHAR_ACTION_RE.match(action))
      if m[1] == "edit.insert.char" || m[1] == "form.insert.char" # form_input.rb
        log_insert_char(unquote(m[2]))
        return
      end
      id, char = m[1], unquote(m[2])
    end
    mode_divider(trail_str)
    drop_pending
    desc = vma.actions[id || action]&.method_name.to_s
    desc = desc.gsub("<char>", char) if char
    name = action.class == Proc ? "(proc)" : action.to_s
    desc = "" if desc == name
    push(kind: :action, chord: fmt_chord(trail_str), action: action, desc: desc)
  end

  # A multi-key sequence is in progress (matched a state that has children).
  def log_pending(trail_str)
    return unless @active
    mode_divider(trail_str)
    e = { kind: :pending, chord: fmt_chord(trail_str) }
    if @entries.last && @entries.last[:kind] == :pending
      @entries[-1] = e
      update_last_row(e)
    else
      push(e)
    end
  end

  # A key of an easy jump label (easy_jump.rb, which reads them itself).
  # label: the keys so far; state: :typing, :jumped (to 1-based line) or
  # :nomatch. One row per label, updated as it is typed.
  def log_jump_label(label, state, line = nil)
    return unless @active
    drop_pending
    e = { kind: :jump, text: label.downcase, state: state, line: line }
    last = @entries.last
    if last && last[:kind] == :jump && last[:state] == :typing
      @entries[-1] = e
      update_last_row(e)
    else
      push(e)
    end
  end

  # A key press that matched nothing in the binding tree.
  def log_nomatch(c, trail_str)
    return unless @active
    drop_pending
    chord = [trail_str, c].reject { |s| s.to_s.empty? }.join(" ")
    push(kind: :nomatch, chord: fmt_chord(chord))
  end

  private

  def log_insert_char(ch)
    if @entries.last && @entries.last[:kind] == :insert
      @entries.last[:text] << ch
      update_last_row(@entries.last)
    else
      push(kind: :insert, text: ch.dup)
    end
  end

  # A pending row is superseded by the entry that completes or aborts it.
  def drop_pending
    return unless @entries.last && @entries.last[:kind] == :pending
    @entries.pop
    @list.remove(@rows.pop)
  end

  # Insert a dim divider row whenever the mode badge changes between entries.
  def mode_divider(trail_str)
    mode = trail_str.to_s[/\A\[[^\]]+\]/]
    return if mode.nil?
    push(kind: :mode, text: mode) if @last_mode && mode != @last_mode
    @last_mode = mode
  end

  def push(e)
    @entries << e
    lbl = Gtk::Label.new
    lbl.use_markup = true
    lbl.xalign = 0.0
    lbl.wrap = true
    # Break inside long words too: an action like
    # buf.jump(END_OF_LINE);buf.insert_txt("\n");... has no spaces, and its
    # width would otherwise become the panel's minimum width
    lbl.wrap_mode = :word_char
    lbl.margin_start = 8
    lbl.margin_end = 8
    lbl.margin_top = 3
    lbl.margin_bottom = 3
    lbl.markup = markup_for(e)
    row = Gtk::ListBoxRow.new
    row.set_child(lbl)
    row.style_context.add_provider(@row_css)
    @list.prepend(row)   # newest entry shown at top
    @rows << row
    highlight(row)
    show_hint(e)
    if @entries.size > MAX_ENTRIES
      @entries.shift
      @list.remove(@rows.shift)   # oldest row sits at the bottom
    end
    scroll_to_top
  end

  def update_last_row(e)
    @rows.last.child.markup = markup_for(e)
    show_hint(e)
    scroll_to_top
  end

  # The entry in the bubble next to the cursor, shorter: no mode badge (the
  # mode divider rows aren't shown there)
  def show_hint(e)
    return if e[:kind] == :mode
    chord = esc(e[:chord].to_s.sub(/\A\[[^\]]*\]\s*/, ""))
    m = case e[:kind]
      when :action
        name = e[:action].class == Proc ? "(proc)" : e[:action].to_s
        what = e[:desc].to_s.empty? ? name : e[:desc]
        what = what[0, 45] + "…" if what.size > 46
        "<b>#{chord}</b>  <span alpha='80%'>#{esc(what)}</span>"
      when :pending then "<b>#{chord}</b> …"
      when :insert
        t = e[:text]
        t = "…" + t[-30..] if t.size > 31
        "<span alpha='80%'>typed</span> <b>#{esc(t)}</b>"
      when :nomatch then "<b>#{chord}</b>  <span alpha='80%'>(no binding)</span>"
      when :jump then "<span alpha='80%'>label</span> <b>#{esc(e[:text])}</b><span alpha='80%'>#{jump_result(e)}</span>"
      end
    @hint.show(m)
  end

  # Mark row as the newest entry, unmarking the previous one.
  def highlight(row)
    @newest_row&.remove_css_class("keylog-newest")
    row.add_css_class("keylog-newest")
    @newest_row = row
  end

  def markup_for(e)
    case e[:kind]
    when :action
      name = e[:action].class == Proc ? "(proc)" : e[:action].to_s
      s = "<span size='large' weight='bold'>#{esc(e[:chord])}</span>\n"
      s << "<span foreground='#8fbef0' size='large'>#{esc(e[:desc])}</span>" unless e[:desc].empty?
      s << "\n<span>#{esc(name)}</span>"
      s
    when :pending
      "<span size='large' weight='bold' alpha='55%'>#{esc(e[:chord])} …</span>"
    when :insert
      "<span size='large'>typed: <b>#{esc(e[:text])}</b></span>"
     when :mode
      "<span size='small' alpha='50%'>— #{esc(e[:text])} —</span>"     
    when :nomatch
      "<span size='large' alpha='45%'>#{esc(e[:chord])}  (no binding)</span>"
    when :jump
      "<span size='large'>label: <b>#{esc(e[:text])}</b>#{jump_result(e)}</span>"

    end
  end

  def jump_result(e)
    case e[:state]
    when :typing then " …"
    when :jumped then "  → line #{e[:line]}"
    else "  (no such label)"
    end
  end

  # Render key-release notation "ctrl!" as "ctrl↑"
  def fmt_chord(s)
    s.to_s.gsub(/(\S+?)!/) { "#{$1}↑" }
  end

  def esc(s)
    CGI.escapeHTML(s.to_s)
  end

  # Extract the character from the quoted arg of buf.insert_txt('x'),
  # undoing the escaping done in match_key_conf.
  def unquote(s)
    s = s.to_s
    s = s[1..-2] if s.size >= 2 && (s[0] == "'" || s[0] == '"') && s[-1] == s[0]
    s.gsub("\\\\'", "'").gsub("\\\\\\\\", "\\\\")
  end

  def scroll_to_top
    GLib::Idle.add do
      adj = @sw.vadjustment
      adj.value = adj.lower
      false
    end
  end
end
end # module Vimamsa
