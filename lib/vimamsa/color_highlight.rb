
module Vimamsa

# Matches hex color codes: #RGB, #RGBA, #RRGGBB, #RRGGBBAA.
# The trailing lookahead prevents matching a prefix of a longer hex run.
COLOR_HEX_RE = /#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})(?![0-9a-fA-F])/

module ColorHighlight
  # Map a matched hex string to [background "#rrggbb", foreground "#000000"/"#ffffff"].
  # Shorthand (#rgb / #rgba) is expanded; any alpha byte is dropped for the swatch.
  def self.display_colors(hex)
    h = hex.delete("#")
    h = h.chars.map { |c| c + c }.join if h.size == 3 || h.size == 4
    r = h[0, 2].to_i(16)
    g = h[2, 2].to_i(16)
    b = h[4, 2].to_i(16)
    bg = format("#%02x%02x%02x", r, g, b)
    lum = 0.299 * r + 0.587 * g + 0.114 * b # perceived brightness
    fg = lum > 140 ? "#000000" : "#ffffff"
    [bg, fg]
  end
end

class VSourceView < GtkSource::View
  # Paint every hex color code in the buffer with its own color as the
  # background (e.g. "#3DCBB5" shows up teal). Works in any file — source
  # code and .txt (hyper plaintext) alike. Cheap enough to re-run on a
  # debounced idle after edits; tags are reused across runs.
  def highlight_colors
    return if @bufo.nil?
    vbuf = buffer
    @color_tags ||= {} # bg hex string => Gtk::TextTag

    # Wipe previous swatches, then repaint from the current text.
    unless @color_tags.empty?
      s = vbuf.start_iter
      e = vbuf.end_iter
      @color_tags.each_value { |t| vbuf.remove_tag(t, s, e) }
    end
    return if cnf.highlight_colors.enabled? == false

    @bufo.to_s.scan(COLOR_HEX_RE) do
      m = $~
      (bg, fg) = ColorHighlight.display_colors(m[0])
      tag = @color_tags[bg]
      if tag.nil?
        tag = vbuf.create_tag("vma_color_#{bg}")
        tag.background = bg
        tag.foreground = fg
        @color_tags[bg] = tag
      end
      si = vbuf.get_iter_at(:offset => m.begin(0))
      ei = vbuf.get_iter_at(:offset => m.end(0))
      vbuf.apply_tag(tag, si, ei)
    end
  end
end

# Re-highlight the current view's color codes, debounced so a burst of
# keystrokes only triggers one scan.
def schedule_color_highlight
  return if cnf.highlight_colors.enabled? == false
  DelayExecutioner.exec(id: :highlight_colors, wait: 0.4,
                        callable: proc { vma.gui.view&.highlight_colors; false })
end

end # module Vimamsa
