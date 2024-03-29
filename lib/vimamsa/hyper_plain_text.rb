def hpt_check_cur_word(w)
  debug "check_cur_word(w)"
  m = w.match(/⟦((audio|img):)?(.*)⟧/)
  if m
    fpfx = m[3]
    if vma.buf.fname
      dn = File.dirname(vma.buf.fname)

      fcands = []
      if fpfx[0] != "/" and fpfx[0] != "~"
        fcands << "#{dn}/#{fpfx}"
        fcands << "#{dn}/#{fpfx}.txt"
      end
      fcands << File.expand_path("#{fpfx}")
      fcands << File.expand_path("#{fpfx}.txt")

      fn = nil

      for fc in fcands
        if File.exist?(fc)
          fn = fc
          break
        end
      end

      if fn
        if m[2] == "audio"
          # Thread.new { Audio.play(fn) }
          Audio.play(fn) if cnf.audio.enabled?
        else
          if !file_is_text_file(fn)
            message "Not text file #{fn}"
            return nil
          end
          message "HPT opening file #{fn}"
          return fn
        end
        # open_existing_file(fn)
        # return true
      else
        message "File not found: #{fpfx}"
        newfn = fcands[0]
        if File.extname(newfn) == ""
          newfn = fcands[1]
        end
         Gui.confirm("File does not exist. Create a new file? \r #{newfn}",
                    proc{hpt_create_new_file(newfn)})
                   
      end
    end
  end
  return nil
end


def hpt_create_new_file(fn)
  create_new_file(fn)
end

def translate_path(fn, bf)
  if File.exist?(fn)
    outfn = fn
  elsif fn[0] == "$"
    outfn = ppath(fn[1..-1]) # Path to source location
  elsif fn[0] == "~"
    outfn = File.expand_path(fn)
  elsif !bf.fname.nil?
    pd = File.dirname(bf.fname)
    outfn = "#{pd}/#{fn}"
  else
    outfn = File.expand_path(fn)
  end
  return outfn
end

# Scan audio files inserted with ⟦audio:filepath⟧ syntax
#TODO: merge code with hpt_scan_images
def hpt_scan_audio(bf = nil)
  bf = buf() if bf.nil?
  return if bf.nil?
  return if !bf.fname
  return if !bf.fname.match(/.*txt$/)
  imgpos = scan_indexes(bf, /⟦audio:.+?⟧/)
  imgtags = bf.scan(/(⟦audio:(.+?)⟧)/)
  c = 0
  imgpos.each.with_index { |x, i|
    a = imgpos[i]
    t = imgtags[i]
    insert_pos = a + t[0].size + c
    fn = t[1]
    imgfn = translate_path(fn, bf)
    next if !File.exist?(imgfn)
    # Show as image in gui, handle as empty space in txt file

    if bf[insert_pos..(insert_pos + 2)] != "\n \n"
      bf.insert_txt_at("\n \n", insert_pos)
      bf.view.handle_deltas
      c += 3
    end
    bf.add_audio(imgfn, insert_pos + 1)
  }
  # vma.gui.delex.run #TODO:gtk4
end

# Scan images inserted with ⟦img:filepath⟧ syntax
def hpt_scan_images(bf = nil)
  bf = buf() if bf.nil?
  return if bf.nil?
  return if !bf.fname
  return if !bf.fname.match(/.*txt$/)
  imgpos = scan_indexes(bf, /⟦img:.+?⟧/)
  imgtags = bf.scan(/(⟦img:(.+?)⟧)/)
  c = 0
  imgpos.each.with_index { |x, i|
    a = imgpos[i]
    t = imgtags[i]
    insert_pos = a + t[0].size + c
    fn = t[1]
    imgfn = translate_path(fn, bf)
    next if !File.exist?(imgfn)
    # Show as image in gui, handle as empty space in txt file

    if bf[insert_pos..(insert_pos + 2)] != "\n \n"
      bf.insert_txt_at("\n \n", insert_pos)
      bf.view.handle_deltas
      c += 3
    end
    bf.add_image(imgfn, insert_pos + 1)
  }

  # Need to scale after buffer loaded
  run_as_idle proc { vma.gui.scale_all_images }

  # vma.gui.delex.run #TODO:gtk4
end
