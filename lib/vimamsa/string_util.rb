def flip_true_false(str)
  str.gsub(/\b(true|false)\b/i) do |match|
    if match.match?(/\Atrue\z/i)
      replacement = "false"
    else
      replacement = "true"
    end

    # preserve casing style
    if match == match.upcase
      replacement.upcase
    elsif match[0] == match[0].upcase
      replacement.capitalize
    else
      replacement.downcase
    end
  end
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


