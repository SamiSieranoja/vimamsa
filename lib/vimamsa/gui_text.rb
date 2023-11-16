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

  def self.highlight_match_old(bf, str, color: "#aa0000ff")
    vbuf = bf.view.buffer
    r = Regexp.new(Regexp.escape(str), Regexp::IGNORECASE)

    hlparts = []

    tt = vma.gui.view.buffer.tag_table.lookup("highlight_match_tag")
    if tt.nil?
      tt = vma.gui.view.buffer.create_tag("highlight_match_tag")
    end

    tt.weight = 650
    tt.foreground = color

    ind = scan_indexes(bf, r)
    ind.each { |x|
      itr = vbuf.get_iter_at(:offset => x)
      itr2 = vbuf.get_iter_at(:offset => x + str.size)
      vbuf.apply_tag(tt, itr, itr2)
    }
  end
end
