

def hpt_open_link()
end

def hpt_check_cur_word(w)
  puts "check_cur_word(w)"
  m = w.match(/⟦(.*)⟧/)
  if m
    fpfx = m[1]
    if $buffer.fname
      dn = File.dirname($buffer.fname)
      fcand1 = "#{dn}/#{fpfx}"
      fcand2 = "#{dn}/#{fpfx}.txt"
      fn = nil
      fn = fcand1 if File.exists?(fcand1)
      fn = fcand2 if File.exists?(fcand2)
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
