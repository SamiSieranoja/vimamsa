

def hpt_open_link()
end

def hpt_check_cur_word(w)
  puts "check_cur_word(w)"
  m = w.match(/⟦(.*)⟧/)
  if m
    fpfx = m[1]
    if $buffer.fname
      dn = File.dirname($buffer.fname)

      fcands=[]
      fcands << "#{dn}/#{fpfx}"
      fcands << "#{dn}/#{fpfx}.txt"
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
        open_existing_file(fn)
        return true
      else
        message "File not found: #{fpfx}"
      end
    end
  end
  return false
end




