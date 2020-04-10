def read_file(text, path)
  path = Pathname(path.to_s).expand_path
  FileUtils.touch(path) unless File.exist?(path)
  if !File.exist?(path)
    #TODO: fail gracefully
    return
  end

  encoding = text.encoding
  content = path.open("r:#{encoding.name}") { |io| io.read }

  debug("GUESS ENCODING")
  unless content.valid_encoding? # take a guess
    GUESS_ENCODING_ORDER.find { |enc|
      content.force_encoding(enc)
      content.valid_encoding?
    }
    content.encode!(Encoding::UTF_8)
  end
  debug("END GUESS ENCODING")

  #TODO: Should put these as option:
  content.gsub!(/\r\n/, "\n")
  content.gsub!(/\t/, "    ")
  content.gsub!(/\b/, "")

  #    content = filter_buffer(content)
  debug("END FILTER")
  return content
end

def is_url(s)
  return s.match(/(https?|file):\/\/.*/) != nil
end

def is_existing_file(s)
  if is_path(s) and File.exist?(File.expand_path(s))
    return true
  end
  return false
end

def is_path(s)
  m = s.match(/(~[a-z]*)?\/.*\//)
  if m != nil
    return true
  end
  return false
end

