require "open3"


# Run idle proc once
# Delay execution of proc until Gtk has fully processed the last calls.
def run_as_idle(p)
  if p.class == Proc
    Thread.new {
      GLib::Idle.add(proc { p.call; false })
    }
  end
end

def open_url(url)
  system("xdg-open", url)
end

def open_with_default_program(url)
  system("xdg-open", url)
end

def run_cmd(cmd)
  tmpf = Tempfile.new("vmarun", "/tmp").path
  cmd = "#{cmd} > #{tmpf}"
  debug "CMD:\n#{cmd}"
  system("bash", "-c", cmd)
  res_str = File.read(tmpf)
  return res_str
end

def exec_cmd(bin_name, arg1 = nil, arg2 = nil, arg3 = nil, arg4 = nil, arg5 = nil)
  assert_binary_exists(bin_name)
  if !arg5.nil?
    p = Open3.popen2(bin_name, arg1, arg2, arg3, arg4, arg5)
  elsif !arg4.nil?
    p = Open3.popen2(bin_name, arg1, arg2, arg3, arg4)
  elsif !arg3.nil?
    p = Open3.popen2(bin_name, arg1, arg2, arg3)
  elsif !arg2.nil?
    p = Open3.popen2(bin_name, arg1, arg2)
  elsif !arg1.nil?
    p = Open3.popen2(bin_name, arg1)
  else
    p = Open3.popen2(bin_name)
  end

  ret_str = p[1].read
  return ret_str
end

def mkdir_if_not_exists(_dirpath)
  dirpath = File.expand_path(_dirpath)
  Dir.mkdir(dirpath) unless File.exist?(dirpath)
end

class HSafe
  def initialize(hash)
    @h = hash
    @a = []
  end

  def [](x)
    @a << x
    return self
  end

  def val
    b = @a.reverse
    hh = @h
    while !b.empty?
      x = b.pop
      puts "x=#{x}"
      pp b
      ok = false
      if hh.class == Hash or hh.class == Array
        ok = true
      else
        if hh.methods.include?(:[])
          ok = true
        end
      end
      return nil if !ok
      if hh[x].nil?
        return nil
      else
        hh = hh[x]
      end
    end
    return hh
  end
end

# h= Hash.new
# h[2] = Hash.new
# h[2]["sdf"] = Hash.new
# h[2]["sdf"][:ll] = 2323
# pp HSafe.new(h)[2]["sdf"][:ll].val
# pp HSafe.new(h)[2]["sdf"][:llz].val
# pp HSafe.new(h)["SDFSDFD"]["sdf"][:llz].val

# From https://stackoverflow.com/questions/2108727/which-in-ruby-checking-if-program-exists-in-path-from-ruby
# Cross-platform way of finding an executable in the $PATH.
#
#   which('ruby') #=> /usr/bin/ruby

# Execute proc after wait_time seconds after last .run call.
# Used for image scaling after window resize

class DelayExecutioner
  def initialize(wait_time, _proc)
    @wait_time = wait_time
    @proc = _proc
    @lastt = Time.now
    @thread_running = false
  end

  def start_thread
    Thread.new {
      while true
        sleep 0.1
        if Time.now - @lastt > @wait_time
          @proc.call
          @thread_running = false
          break
        end
      end
    }
  end

  def run()
    @lastt = Time.now
    if @thread_running == false
      @thread_running = true
      start_thread
    end
  end
end

def which(cmd)
  exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
  ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
    exts.each do |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    end
  end
  nil
end

def assert_binary_exists(bin)
  if which(bin).nil?
    raise "Binary #{bin} doesn't exist"
  end
end

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
  # content.gsub!(/\t/, "    ")
  content.gsub!(/\b/, "")

  #    content = filter_buffer(content)
  debug("END FILTER")
  return content
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

def expand_if_existing(fpath)
  return nil if fpath.class != String
  fpath = File.expand_path(fpath)
  fpath = nil if !File.exist?(fpath)
  return fpath
end

def ppath(s)
  selfpath = __FILE__
  selfpath = File.readlink(selfpath) if File.lstat(selfpath).symlink?
  scriptdir = File.expand_path(File.dirname(selfpath))
  p = "#{scriptdir}/../../#{s}"
  return File.expand_path(p)
end

def is_existing_file(s)
  return false if !s
  if is_path(s) and File.exist?(File.expand_path(s))
    return true
  end
  return false
end

def is_image_file(fpath)
  return false if !File.exist?(fpath)
  return false if !fpath.match(/.(jpg|jpeg|png)$/i)
  #TODO: check contents of file
  return true
end

def is_text_file(fpath)
  return false if !File.exist?(fpath)
  return false if !fpath.match(/.(txt|cpp|h|rb|c|php|java|py)$/i)
  #TODO: check contents of file
  return true
end

def is_path(s)
  m = s.match(/(~[a-z]*)?\/.*\//)
  if m != nil
    return true
  end
  return false
end
