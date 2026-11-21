module Vimamsa
# A see-through bubble next to the cursor with the key just pressed and the
# action it ran, so a demo (or a new user) can follow the keys without
# looking at the key log panel. Shown while the key log panel is shown, fed
# by it (KeyLogPanel#push), and fades out after a moment. It goes right of
# the end of the cursor's line, where it covers no text (below the line if
# that is too long), with a dashed border to set it apart from the text. It
# starts with the current mode as a copy of the mode badge (same CSS
# classes, so it follows the theme, cyberpunk included). It is drawn over
# the editor, above easy jump's labels, and takes no mouse input.
class KeyHint
  SHOW_SECS = 2.0 # fully shown
  FADE_SECS = 0.8 # then fading out
  OPACITY = 0.8
  GAP = 44 # px between the end of the line and the bubble
  MIN_GAP = 12 # the gap used when GAP doesn't leave room for the bubble

  # Test-visible: the mode and markup shown; the bubble (a Gtk::Box), its
  # mode badge label and its key/action label
  attr_reader :markup, :widget, :mode_label, :label

  def initialize
    @mode_label = Gtk::Label.new
    @mode_label.add_css_class("mode-badge")
    @mode_label.valign = :center
    @mode_cls = nil
    @label = Gtk::Label.new
    @label.use_markup = true
    @label.wrap = false
    @widget = Gtk::Box.new(:horizontal, 6)
    @widget.append(@mode_label)
    @widget.append(@label)
    @widget.halign = :start
    @widget.valign = :start
    @widget.can_target = false
    @widget.add_css_class("key-hint")
    css = Gtk::CssProvider.new
    css.load(data: <<~CSS)
      .key-hint {
        background-color: rgba(20, 26, 34, 0.75);
        color: #ffffff;
        border: 1px dashed rgba(255, 255, 255, 0.45);
        border-radius: 8px;
        padding: 0px 8px;
        font-size: 1.3em;
      }
    CSS
    @widget.style_context.add_provider(css)
    @widget.visible = false
    @parent = nil
    @timer = nil
  end

  def visible?
    @widget.visible?
  end

  # body: Pango markup of the key and action; the mode tag goes before it
  def show(body)
    attach
    return if @parent.nil?
    @body = body
    render
    @widget.opacity = OPACITY
    @widget.visible = true
    remove_timer
    # Placed once the action has run, so it follows the cursor's new place
    GLib::Idle.add { place; false }
    @shown_at = Time.now
    @timer = GLib::Timeout.add(40) { fade }
  end

  def hide
    remove_timer
    @widget.visible = false
  end

  private

  # The mode is read when shown and again when placed, after the action
  # has run (v shows VISUAL)
  def render
    text, cls = vma.gui.mode_badge_info
    @mode_label.text = text.to_s
    @mode_label.visible = !text.to_s.empty?
    if cls != @mode_cls
      @mode_label.remove_css_class(@mode_cls) if @mode_cls
      @mode_label.add_css_class(cls) if cls
      @mode_cls = cls
    end
    @label.markup = @body.to_s
    @markup = "#{text} #{@body}"
  end

  # Into the active window's overlay, as its topmost child (easy jump adds
  # its labels to the same overlay later)
  def attach
    ov = vma.gui.active_window && vma.gui.active_window[:overlay]
    return if ov.nil?
    return if ov.equal?(@parent) && ov.last_child.equal?(@widget)
    @parent&.remove_overlay(@widget)
    ov.add_overlay(@widget)
    @parent = ov
  end

  # Right of the end of the cursor's line; if the line is too long, below it
  # (above it near the bottom of the view)
  def place
    v = vma.gui.view
    return if v.nil? || @parent.nil? || !@widget.visible?
    render
    b = vma.buf
    x, y = v.pos_to_coord(b.pos)
    line_h = v.get_iter_location(v.buffer.get_iter_at(offset: b.pos)).height rescue 20
    # The size it will have with the new text (the allocated one is the
    # previous text's); measure counts the margins, which place it
    w = [@widget.measure(:horizontal, -1)[1] - @widget.margin_start - @widget.margin_end, 80].max
    h = [@widget.measure(:vertical, -1)[1] - @widget.margin_top - @widget.margin_bottom, 24].max
    eol = b.index("\n", b.pos) || b.size
    xe, _ye = v.pos_to_coord(eol)
    gap = [GAP, MIN_GAP].find { |g| xe + g + w <= @parent.width }
    if gap
      left = xe + gap
      top = y + (line_h - h) / 2
    else
      left = x.clamp(0, [@parent.width - w, 0].max)
      top = y + line_h + 4
      top = y - h - 4 if top + h > @parent.height && y - h - 4 >= 0
    end
    @widget.margin_start = [left, 0].max
    @widget.margin_top = [top, 0].max
  rescue => e
    debug "KeyHint#place: #{e.message}"
  end

  def fade
    t = Time.now - @shown_at
    return true if t < SHOW_SECS
    if t >= SHOW_SECS + FADE_SECS
      @widget.visible = false
      @timer = nil
      return false
    end
    @widget.opacity = OPACITY * (1 - (t - SHOW_SECS) / FADE_SECS)
    true
  end

  def remove_timer
    GLib::Source.remove(@timer) rescue nil if @timer
    @timer = nil
  end
end
end # module Vimamsa
