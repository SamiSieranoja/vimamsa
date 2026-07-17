# Hex color highlighting module
#
# Paints every hex color code (#RGB / #RGBA / #RRGGBB / #RRGGBBAA) in the buffer
# with that color as its background (e.g. "#3DCBB5" shows up teal), in any file
# type — source and .txt (hyper plaintext) alike.
#
# Enable/disable from Settings ▸ Modules ▸ "Hex Color Highlight", the `C , ; h c`
# key binding, or `cnf.modules.color_highlight.enabled`. Highlighting runs on a
# debounced idle after edits, driven by the :view_content_set / :view_text_changed
# hooks that VSourceView fires (so no core code hard-depends on this module).

module Vimamsa

# Matches hex color codes: #RGB, #RGBA, #RRGGBB, #RRGGBBAA.
# The trailing lookahead prevents matching a prefix of a longer hex run.
COLOR_HEX_RE = /#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})(?![0-9a-fA-F])/ unless defined?(COLOR_HEX_RE)

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
  # background. Cheap enough to re-run on a debounced idle after edits; tags are
  # reused across runs. Wipes prior swatches first, so calling it while the
  # module is disabled just clears them.
  def highlight_colors
    return if @bufo.nil?
    vbuf = buffer
    @color_tags ||= {} # bg hex string => Gtk::TextTag

    unless @color_tags.empty?
      s = vbuf.start_iter
      e = vbuf.end_iter
      @color_tags.each_value { |t| vbuf.remove_tag(t, s, e) }
    end
    return unless cnf.modules.color_highlight.enabled?

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
  return unless cnf.modules.color_highlight.enabled?
  DelayExecutioner.exec(id: :highlight_colors, wait: 0.4,
                        callable: proc { vma.gui.view&.highlight_colors; false })
end

def color_highlight_rehighlight_all
  vma.gui.buffers.each_value { |v| v.highlight_colors }
end

# Hook handlers (registered once by color_highlight_init).
def color_highlight_on_content_set(view)
  run_as_idle(proc { view.highlight_colors }) if view
end

def color_highlight_on_text_changed(_view = nil)
  schedule_color_highlight
end

def color_highlight_init
  reg_act(:toggle_highlight_colors, proc {
    en = cnf.modules.color_highlight.enabled? == false
    cnf.modules.color_highlight.enabled = en
    color_highlight_rehighlight_all
    message("Color code highlighting: #{en ? "ON" : "OFF"}")
  }, "Toggle hex color code highlighting on/off")
  add_keys "color_highlight", { "C , ; h c" => :toggle_highlight_colors }

  # Register the view hooks once. The guard survives module reloads (a global
  # set only here persists across `load`), so a no_restart re-enable never
  # double-registers.
  unless $color_highlight_hooks_registered
    vma.hook.register(:view_content_set, method(:color_highlight_on_content_set))
    vma.hook.register(:view_text_changed, method(:color_highlight_on_text_changed))
    $color_highlight_hooks_registered = true
  end

  color_highlight_rehighlight_all
end

def color_highlight_disable
  unbindkey "C , ; h c"
  unreg_act(:toggle_highlight_colors)
  # cnf.modules.color_highlight.enabled is already false here, so this wipes the
  # swatches. The registered hooks stay but no-op via that gate.
  color_highlight_rehighlight_all
end

end # module Vimamsa
