module Vimamsa
  def flip_term(str)
    y = str.downcase
    replacements = [
      %w[true false],
      %w[left right],
      %w[begin end],
      %w[spring summer autumn winter],
      ("a".."z").to_a,
      %w[january february march april may june july august september october november december],
      %w[jan feb mar apr may jun jul aug sep oct nov dec],
      %w[monday tuesday wednesday thursday friday saturday sunday],
      %w[mon tue wed thu fri sat sun],
      %w[zero one two three four five six seven eight nine ten],
      %w[north east south west],
      %w[am pm],
      %w[todo doing done],
      %w[yes no],
      %w[on off],
      %w[enabled disabled],
      %w[enable disable],
      %w[active inactive],
      %w[open closed],
      %w[public private],
      %w[visible hidden],
      %w[show hide],
      %w[up down],
      %w[top bottom],
      %w[first last],
      %w[next previous],
      %w[before after],
      %w[min max],
      %w[minimum maximum],
      %w[increase decrease],
      %w[push pop],
      %w[add remove],
      %w[include exclude],
      %w[read write],
      %w[input output],
      %w[source target],
      %w[start stop],
      # %w[start finish],
      %w[create destroy],
      %w[connect disconnect],
      %w[attach detach],
      %w[lock unlock],
      %w[valid invalid],
      %w[success failure],
      %w[pass fail],
      %w[positive negative],
      %w[ascending descending],
      %w[horizontal vertical],
      %w[portrait landscape],
      %w[absolute relative],
      %w[local remote],
      %w[client server],
      %w[request response],
      %w[parent child],
      %w[head tail],
      %w[prefix suffix],
      %w[foreground background],
      %w[light dark],
      %w[black white],
    ]

    rep = nil
    for x in replacements
      i = x.find_index(y)
      if i
        i = (i + 1) % x.size
        rep = x[i]
        rep = preserve_case(str, rep)
        return rep
      end
    end
    flip_numbered_term(str)
  end

  def flip_numbered_term(str)
    return nil unless str =~ /\A(.*?)(\d+)\z/

    prefix = Regexp.last_match(1)
    number = Regexp.last_match(2)

    next_number = number.to_i + 1

    # Preserve zero padding: item001 -> item002
    "#{prefix}#{next_number.to_s.rjust(number.length, "0")}"
  end

  def preserve_case(original, replacement)
    if original == original.upcase
      replacement.upcase
    elsif original[0] == original[0]&.upcase
      replacement.capitalize
    else
      replacement.downcase
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
end # module Vimamsa
