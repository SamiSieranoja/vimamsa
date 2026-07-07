
module Vimamsa
module Gui
  def self.hilight_range(bf, r, color: "#aa0000ff", weight: nil, tag: nil)
    vbuf = bf.view.buffer

    if tag.nil?
      tag = vma.gui.view.buffer.create_tag
      tag.weight = weight if !weight.nil?
      tag.foreground = color
    end

    itr = vbuf.get_iter_at(:offset => r.begin)
    itr2 = vbuf.get_iter_at(:offset => r.last)
    vbuf.apply_tag(tag, itr, itr2)
  end

  # Briefly highlight buffer range `r`, then clear it after cnf.flash.duration.
  # If a block is given it runs *after* the flash clears — used by delete so the
  # range is shown before the text is removed. When flashing is inactive
  # (disabled in config, running under --test, running a macro, no GUI view, or
  # an empty/inverted range) the block runs immediately and no highlight is
  # drawn, preserving synchronous behaviour. Macros must stay synchronous: the
  # deferred timeout used for the flash reorders the delete relative to the rest
  # of the macro and breaks playback.
  def self.flash_range(bf, r, &after)
    active = cnf.flash.enabled? && !ARGV.include?("--test") &&
             !vma.macro&.running_macro &&
             bf.view && r && r.begin <= r.last
    unless active
      after&.call
      return
    end

    vbuf = bf.view.buffer
    tag = vbuf.tag_table.lookup("vma_flash")
    if tag.nil?
      tag = vbuf.create_tag("vma_flash")
      tag.background = cnf.match.highlight.color!
    end
    lo = r.begin
    hi = [r.last + 1, bf.size].min # +1: cover the last char inclusively
    vbuf.apply_tag(tag, vbuf.get_iter_at(:offset => lo), vbuf.get_iter_at(:offset => hi))

    GLib::Timeout.add((cnf.flash.duration! * 1000).to_i) do
      vbuf.remove_tag(tag, vbuf.get_iter_at(:offset => lo), vbuf.get_iter_at(:offset => hi))
      after&.call
      # `after` may have edited the buffer (e.g. delete-to-mark). The normal
      # post-action refresh already ran when the key was pressed, so flush the
      # deferred edit to the GTK view and redraw the cursor here.
      bf.view.handle_deltas
      bf.view.draw_cursor
      false
    end
  end

  def self.highlight_match(bf, str, color: "#aa0000ff", weight: 650)
    r = Regexp.new(Regexp.escape(str), Regexp::IGNORECASE)
    tag = vma.gui.view.buffer.create_tag
    tag.weight = weight
    tag.foreground = color
    ind = scan_indexes(bf, r)
    ind.each { |x|
      r = x..(x + str.size)
      self.hilight_range(bf, r, tag: tag)
    }
  end
end
end # module Vimamsa
