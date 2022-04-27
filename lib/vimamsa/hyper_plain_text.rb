def hpt_check_cur_word(w)
  debug "check_cur_word(w)"
  m = w.match(/⟦(.*)⟧/)
  if m
    fpfx = m[1]
    if $buffer.fname
      dn = File.dirname($buffer.fname)

      fcands = []
      if fpfx[0] != "/"
        fcands << "#{dn}/#{fpfx}"
        fcands << "#{dn}/#{fpfx}.txt"
      end
      fcands << File.expand_path("#{fpfx}")
      fcands << File.expand_path("#{fpfx}.txt")

      fn = nil
      for fc in fcands
        if File.exists?(fc)
          fn = fc
          break
        end
      end

      if fn
        message "HPT opening file #{fn}"
        return fn
        # open_existing_file(fn)
        # return true
      else
        message "File not found: #{fpfx}"
      end
    end
  end
  return nil
end

# Scan images inserted with ⟦img:filepath⟧ syntax
def hpt_scan_images()
  return if !buf.fname
  return if !buf.fname.match(/.*txt$/)
  imgpos = scan_indexes(buf, /⟦img:.+?⟧/)
  imgtags = buf.scan(/(⟦img:(.+?)⟧)/)
  c = 0
  imgpos.each.with_index { |x, i|
    a = imgpos[i]
    t = imgtags[i]
    insert_pos = a + t[0].size + c
    imgfn = File.expand_path(t[1])
    next if !File.exist?(imgfn)
    # Show as image in gui, handle as empty space in txt file
    if buf[insert_pos..(insert_pos + 2)] != "\n \n"
      buf.insert_txt_at("\n \n", insert_pos)
      buf.view.handle_deltas
      c += 3
    end
    buf.add_image(imgfn, insert_pos + 1)
  }
end
