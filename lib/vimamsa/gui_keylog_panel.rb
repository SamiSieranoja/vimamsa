
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

  # Insert-mode typing arrives as eval-string actions like buf.insert_txt('h');
  # matched here so consecutive chars can be coalesced into one "typed:" row.
  INSERT_TXT_RE = /\Abuf\.insert_txt\((.+)\)\z/

  def initialize
    @entries = []
    @rows = []       # Gtk::ListBoxRow per entry, parallel to @entries
                     # (newest last, like @entries; displayed newest first)
    @active = false
    @last_mode = nil # last seen mode badge, e.g. "[COMMAND]"
    @newest_row = nil

    @list = Gtk::ListBox.new
    @list.selection_mode = :none

    # Highlight for the newest row
    @row_css = Gtk::CssProvider.new
    @row_css.load(data: "row.keylog-newest { color:#fff; background-color: alpha(#000000, 0.12); border: 3px solid #94ffbb; }")

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

    header = Gtk::Box.new(:horizontal, 6)
    header.margin_start = 8
    header.margin_end = 6
    header.margin_top = 6
    header.margin_bottom = 4
    header.append(title)
    header.append(clear_btn)

    # @box is the outermost widget: header on top, scrollable log below.
    @box = Gtk::Box.new(:vertical, 0)
    @box.set_size_request(320, -1)
    @box.append(header)
    @box.append(@sw)
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
    mode_divider(trail_str)
    drop_pending
    desc = vma.actions[action]&.method_name.to_s
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
    if @entries.size > MAX_ENTRIES
      @entries.shift
      @list.remove(@rows.shift)   # oldest row sits at the bottom
    end
    scroll_to_top
  end

  def update_last_row(e)
    @rows.last.child.markup = markup_for(e)
    scroll_to_top
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
      s << "<span foreground='#4a90d9' size='large' alpha='60%'>#{esc(e[:desc])}</span>" unless e[:desc].empty?
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
