module Vimamsa
  def flip_term(str)
    puts "STR:#{str}"
    y = str.downcase
    replacements = [["true", "false"], ["left", "right"], ["begin", "end"], ["spring","summer", "autumn","winter"]]
    rep = nil
    for x in replacements
      i = x.find_index(y)
      if i
        i += 1
        if i >= x.size
          i = 0
        end
        rep = x[i]
        # rep = (x - [y])[0]
        if str == str.upcase
          rep = rep.upcase
        elsif str[0] == str[0].upcase
          rep = rep.capitalize
        else
          rep = rep.downcase
        end
        return rep
      end
    end
    return rep
  end

  def to_camel_case(str)
    words = str.split(/\W+/) # Split the input string into words
    camel_case_words = words.map.with_index do |word, index|
      index == 0 ? word.downcase : word.capitalize
    end
    camel_case_words.join
  end

  # Get all indexes for start of matching regexp
  def scan_indexes(txt, regex)
    # indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) + 1 }
    indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) }
    return indexes
  end

  def is_path(s)
    m = s.match(/(~[a-z]*)?\/.*\//)
    if m != nil
      return true
    end
    return false
  end

  def sanitize_input(str)
    if str.encoding != Encoding::UTF_8
      str = text.encode(Encoding::UTF_8)
    end
    str.gsub!(/\r\n/, "\n")
    return str
  end

  def is_url(s)
    return s.match(/(https?|file):\/\/.*/) != nil
  end
end # module Vimamsa
