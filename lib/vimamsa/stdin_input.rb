require "securerandom"
require "fileutils"

module Vimamsa
# Piped input: `ls -ltrh | tail -n 3 | vimamsa` opens the text in a new buffer
# (no file name: saving asks for one), in the running editor if there is one.
#
# The launcher (exe/vimamsa) reads stdin into a file in the data dir's "stdin"
# dir. A running editor gets a "#vma-stdin FILE" line in its listen request
# (Editor#open_file_listener); otherwise the new editor opens $vma_stdin_file
# at startup (Editor#start). The editor deletes the file once it is read.
#
# Loaded by exe/vimamsa before the rest (launcher side), and from rbvma.rb.
module StdinInput
  HEADER = "#vma-stdin "

  module_function

  # ── Launcher side ────────────────────────────────────────────────────────

  # Read piped stdin into a file in data_dir and return its path; nil when
  # stdin is not piped input (a terminal, /dev/null) or is empty.
  #
  # A program that starts the editor (a test runner, VirtualBox guest control)
  # may leave it a pipe that never gets data, and waiting for that would hang
  # the editor. So the wait for the first data is unlimited only when stdout
  # is a terminal (`... | vimamsa` typed in a shell), otherwise short.
  def capture(data_dir, io: $stdin, out: $stdout, first_data_timeout: 2.0)
    return nil if io.tty?
    st = (io.stat rescue nil)
    return nil unless st && (st.pipe? || st.file?)
    if st.pipe? && !out.tty?
      return nil unless IO.select([io], nil, nil, first_data_timeout)
    end
    data = io.binmode.read
    return nil if data.nil? || data.empty?
    dir = File.join(data_dir, "stdin")
    FileUtils.mkdir_p(dir)
    path = File.join(dir, "stdin_#{Process.pid}_#{SecureRandom.hex(4)}.txt")
    File.binwrite(path, data)
    path
  end

  # Listen request line(s) that make a running editor open the file
  def request_text(path)
    "#{HEADER}#{path}\n"
  end

  # ── Editor side ──────────────────────────────────────────────────────────

  # Split a listen request into [stdin files, the rest of the request]
  def split_request(text)
    files = []
    rest = text.each_line.reject { |l|
      next false unless l.start_with?(HEADER)
      f = l[HEADER.size..].strip
      files << f unless f.empty?
      true
    }.join
    [files, rest]
  end

  # A new buffer with the text of the file (as UTF-8 with \n line endings, like
  # opened files), which is then deleted. Returns the buffer, or nil.
  def open_buffer(path)
    return nil if path.nil? || !File.file?(path)
    text = text_to_utf8(File.binread(path))
    text << "\n" unless text.end_with?("\n")
    b = create_new_buffer(text, "stdin")
    n = text.count("\n")
    message("Opened piped input (#{n} line#{n == 1 ? "" : "s"})")
    b
  ensure
    begin
      File.delete(path) if path && File.exist?(path)
    rescue SystemCallError
      nil
    end
  end
end
end
