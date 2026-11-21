module Vimamsa
# A see-through bubble next to the cursor with the key just pressed and the
# action it ran, so a demo (or a new user) can follow the keys without
# looking at the key log panel. Shown while the key log panel is shown, fed
# by it (KeyLogPanel#push), and fades out after a moment. It goes right of
# the end of the cursor's line, where it covers no text (below the line if
# that is too long), with a dashed border to set it apart from the text. It
# starts with the current mode, in the colors of the mode badge. It
# is drawn over the editor, above easy jump's labels, and takes no mouse
# input.
class KeyHint
  SHOW_SECS = 2.0 # fully shown
  FADE_SECS = 0.8 # then fading out
  OPACITY = 0.8
  GAP = 44 # px between the end of the line and the bubble

  # Test-visible: the markup shown, and the Gtk::Label
  attr_reader :markup, :label

  def initialize
    @label = Gtk::Label.new
    @label.use_markup = true
    @label.halign = :start
    @label.valign = :start
    @label.can_target = false
    @label.wrap = false
    @label.add_css_class("key-hint")
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
    @label.style_context.add_provider(css)
    @label.visible = false
    @parent = nil
    @timer = nil
  end

  def visible?
    @label.visible?
  end

  # body: Pango markup of the key and action; the mode tag goes before it
  def show(body)
    attach
    return if @parent.nil?
    @body = body
    render
    @label.opacity = OPACITY
    @label.visible = true
    remove_timer
    # Placed once the action has run, so it follows the cursor's new place
    GLib::Idle.add { place; false }
    @shown_at = Time.now
    @timer = GLib::Timeout.add(40) { fade }
  end

  def hide
    remove_timer
    @label.visible = false
  end

  private

  # The mode is read when shown and again when placed, after the action
  # has run (v shows VISUAL)
  def render
    @markup = mode_tag + @body.to_s
    @label.markup = @markup
  end

  def mode_tag
    text, cls = vma.gui.mode_badge_info
    return "" if text.to_s.empty?
    name = :"badge_#{cls.to_s.sub(/\Amode-/, "")}"
    bg = (theme_color(name) rescue nil) || theme_color(:badge_bg)
    "<span background='#{bg}' foreground='#{theme_color(:badge_fg)}' font_family='monospace' size='small' weight='heavy'> #{CGI.escapeHTML(text.to_s)} </span>  "
  end

  # Into the active window's overlay, as its topmost child (easy jump adds
  # its labels to the same overlay later)
  def attach
    ov = vma.gui.active_window && vma.gui.active_window[:overlay]
    return if ov.nil?
    return if ov.equal?(@parent) && ov.last_child.equal?(@label)
    @parent&.remove_overlay(@label)
    ov.add_overlay(@label)
    @parent = ov
  end

  # Right of the end of the cursor's line; if the line is too long, below it
  # (above it near the bottom of the view)
  def place
    v = vma.gui.view
    return if v.nil? || @parent.nil? || !@label.visible?
    render
    b = vma.buf
    x, y = v.pos_to_coord(b.pos)
    line_h = v.get_iter_location(v.buffer.get_iter_at(offset: b.pos)).height rescue 20
    w = [@label.width, 80].max
    h = [@label.height, 24].max
    eol = b.index("\n", b.pos) || b.size
    xe, _ye = v.pos_to_coord(eol)
    if xe + GAP + w <= @parent.width
      left = xe + GAP
      top = y + (line_h - h) / 2
    else
      left = x.clamp(0, [@parent.width - w, 0].max)
      top = y + line_h + 4
      top = y - h - 4 if top + h > @parent.height && y - h - 4 >= 0
    end
    @label.margin_start = [left, 0].max
    @label.margin_top = [top, 0].max
  rescue => e
    debug "KeyHint#place: #{e.message}"
  end

  def fade
    t = Time.now - @shown_at
    return true if t < SHOW_SECS
    if t >= SHOW_SECS + FADE_SECS
      @label.visible = false
      @timer = nil
      return false
    end
    @label.opacity = OPACITY * (1 - (t - SHOW_SECS) / FADE_SECS)
    true
  end

  def remove_timer
    GLib::Source.remove(@timer) rescue nil if @timer
    @timer = nil
  end
end
end # module Vimamsa
