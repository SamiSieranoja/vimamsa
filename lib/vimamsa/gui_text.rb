module Gui
  def self.highlight_match(bf, str, color: "#aa0000ff")
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
