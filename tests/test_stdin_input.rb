# Piped input: `ls | vimamsa` opens it in a new buffer
# (lib/vimamsa/stdin_input.rb, exe/vimamsa, Editor#open_file_listener / #start)
require "open3"
require "tmpdir"

class TestStdinInput < VmaTest
  EXE = File.expand_path("../exe/vimamsa", __dir__)

  # Not a terminal: stdout of the launcher in these tests
  class NotTty
    def tty? = false
  end

  def wait_until(secs = 10)
    t = Time.now
    until yield
      return false if Time.now - t > secs
      drain_idle
      sleep 0.02
    end
    true
  end

  def test_capture_pipe
    Dir.mktmpdir { |d|
      r, w = IO.pipe
      w.write("one\ntwo\n")
      w.close
      path = StdinInput.capture(d, io: r, out: NotTty.new)
      assert path && File.file?(path), "no file"
      assert_eq "one\ntwo\n", File.binread(path)
      assert path.start_with?(File.join(d, "stdin")), path
    }
  end

  def test_capture_empty_pipe
    Dir.mktmpdir { |d|
      r, w = IO.pipe
      w.close
      assert_eq nil, StdinInput.capture(d, io: r, out: NotTty.new)
    }
  end

  # A pipe that never gets data (left by the program that started the editor)
  # must not hang the editor
  def test_capture_idle_pipe_gives_up
    Dir.mktmpdir { |d|
      r, w = IO.pipe
      t = Time.now
      assert_eq nil, StdinInput.capture(d, io: r, out: NotTty.new, first_data_timeout: 0.3)
      assert Time.now - t < 3, "waited too long"
      w.close
    }
  end

  def test_split_request
    files, rest = StdinInput.split_request("#{StdinInput.request_text("/d/s1")}/a/b.txt\n")
    assert_eq ["/d/s1"], files
    assert_eq "/a/b.txt\n", rest
  end

  def test_open_buffer
    Dir.mktmpdir { |d|
      f = File.join(d, "in.txt")
      File.binwrite(f, "a\r\nb")
      b = StdinInput.open_buffer(f)
      assert b, "no buffer"
      assert_eq b.id, vma.buf.id
      assert_buf "a\nb\n"
      assert_eq nil, b.fname, "should have no file name"
      assert !File.exist?(f), "temp file left behind"
    }
  end

  # The running editor (this one) gets the piped text in a new buffer
  def test_pipe_to_running_editor
    text = "-rw-r--r-- 1 x x 1 a.txt\n-rw-r--r-- 1 x x 2 b.txt\n"
    out, st = Open3.capture2e(*vma_editor_command(EXE), "--user-dir", $vma_user_dir, stdin_data: text)
    assert st.success?, "launcher: #{st.exitstatus} #{out[-300..]}"
    assert wait_until(10) { vma.buf.to_s == text }, "buffer: #{vma.buf.to_s[0, 80].inspect}"
    assert_eq nil, vma.buf.fname
  end

  # No editor running for the user dir: the new editor starts with the text
  def test_pipe_starts_editor
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    Dir.mktmpdir { |ud|
      report = File.join(ud, "report")
      File.write(File.join(ud, "custom.rb"), <<~RUBY)
        def hook_custom_after_init
          GLib::Timeout.add(1500) {
            File.write(#{report.inspect}, vma.buf.to_s)
            vma.shutdown
            false
          }
        end
      RUBY
      out, st = Open3.capture2e(*vma_editor_command(EXE), "--user-dir", ud, stdin_data: "piped\nlines\n")
      assert File.exist?(report), "no report (exit #{st.exitstatus}): #{out[-400..]}"
      assert_eq "piped\nlines\n", File.read(report)
    }
  end
end
