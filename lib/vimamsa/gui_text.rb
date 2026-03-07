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
