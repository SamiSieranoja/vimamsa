# vimamsa --wait FILE: return once FILE's buffer is closed, for git's
# core.editor (lib/vimamsa/wait_files.rb, exe/vimamsa, Editor#open_file_listener)
require "rbconfig"
require "tmpdir"
require "timeout"

class TestWaitFiles < VmaTest
  EXE = File.expand_path("../exe/vimamsa", __dir__)

  # Run the main loop until the block is true (or the time is up)
  def wait_until(secs = 10)
    t = Time.now
    until yield
      return false if Time.now - t > secs
      drain_idle
      sleep 0.02
    end
    true
  end

  # Exit status of pid, or nil if it is still running after secs
  def wait_exit(pid, secs)
    t = Time.now
    while Time.now - t < secs
      _, st = Process.waitpid2(pid, Process::WNOHANG)
      return st if st
      drain_idle
      sleep 0.05
    end
    nil
  end

  def test_parse_request
    req = WaitFiles.request_text(["/a/b.txt", "/c d/e"], "/m/w1")
    assert_eq [["/a/b.txt", "/m/w1"], ["/c d/e", "/m/w1"]], WaitFiles.parse_request(req)
    # a plain request (no --wait): paths without a marker
    assert_eq [["/x/y"], ["/z"]].map { |p| p + [nil] }, WaitFiles.parse_request("/x/y\n/z")
  end

  def test_buffer_close_releases_marker
    Dir.mktmpdir("vma-wait") { |d|
      fn = File.join(d, "COMMIT_EDITMSG")
      File.write(fn, "msg\n")
      m = WaitFiles.create_marker(d)
      b = open_new_file(fn)
      WaitFiles.watch(b, m)
      assert_eq Process.pid.to_s, File.read(m), "editor pid not written to the marker"
      bufs.close_buffer(b.id)
      assert !File.exist?(m), "marker left after the buffer was closed"
    }
  end

  def test_shutdown_releases_all
    Dir.mktmpdir("vma-wait") { |d|
      m = WaitFiles.create_marker(d)
      WaitFiles.watch(buf, m)
      WaitFiles.release_all
      assert !File.exist?(m)
      assert_eq({}, WaitFiles.waiting)
    }
  end

  def test_wait_for_release_dead_editor
    Dir.mktmpdir("vma-wait") { |d|
      m = WaitFiles.create_marker(d)
      pid = Process.spawn(RbConfig.ruby, "-e", "exit 0")
      Process.wait(pid)
      File.write(m, pid.to_s)
      assert_eq false, Timeout.timeout(5) { WaitFiles.wait_for_release(m, poll: 0.01) }
    }
  end

  # Every path of a request is opened (each Idle block has its own path),
  # and all of them are waited on
  def test_request_with_two_paths
    Dir.mktmpdir("vma-wait") { |d|
      a = File.join(d, "a.txt"); File.write(a, "a\n")
      b = File.join(d, "b.txt"); File.write(b, "b\n")
      m = WaitFiles.create_marker(d)
      req = File.join(d, "req")
      File.write(req, WaitFiles.request_text([a, b], m))
      vma.open_file_listener([req])
      assert wait_until(5) { [a, b].all? { |f| vma.buffers.get_buffer_by_filename(f) } }, "not both opened"
      ids = [a, b].map { |f| vma.buffers.get_buffer_by_filename(f) }
      assert_eq [[m], [m]], ids.map { |i| WaitFiles.waiting[i] }
      bufs.close_buffer(ids[0])
      bufs.close_buffer(ids[1])
      assert !File.exist?(m)
    }
  end

  # A request file the launcher already took back (timed out) is skipped
  def test_request_taken_back
    vma.open_file_listener([File.join(Dir.tmpdir, "vma-no-such-request-#{Process.pid}")])
  end

  # The running editor (this one) takes the request; the launcher returns
  # only after the buffer is closed
  def test_wait_with_running_editor
    Dir.mktmpdir("vma-wait") { |d|
      fn = File.join(d, "COMMIT_EDITMSG")
      File.write(fn, "first line\n")
      pid = Process.spawn(*vma_editor_command(EXE), "--user-dir", $vma_user_dir, "--wait", fn,
                          out: File::NULL, err: File::NULL)
      begin
        assert wait_until(15) { vma.buf.fname == fn }, "file not opened in the running editor"
        assert_eq nil, wait_exit(pid, 0.5), "launcher returned before the buffer was closed"
        bufs.close_buffer(vma.buf.id)
        st = wait_exit(pid, 10)
        assert st, "launcher still waiting after the buffer was closed"
        assert st.success?, "exit status #{st.exitstatus}"
      ensure
        (Process.kill(:KILL, pid); Process.wait(pid)) rescue nil
      end
    }
  end

  # No editor running for this user dir: the launcher starts one and returns
  # when it quits (here by TERM, which quits as from the menu). The file
  # doesn't exist yet: the new editor creates it and waits on it.
  def test_wait_starts_editor
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    Dir.mktmpdir("vma-wait-ud") { |ud|
      fn = File.join(ud, "new", "msg.txt")
      pid = Process.spawn(*vma_editor_command(EXE), "--user-dir", ud, "--wait", fn,
                          out: File::NULL, err: File::NULL)
      editor = nil
      begin
        # the editor's listen dir exists once it has started
        assert wait_until(60) { File.directory?(File.join(ud, "listen")) }, "editor did not start"
        marker = Dir[File.join(ud, "wait", "wait_*")].first
        assert marker, "no marker"
        editor = File.read(marker).to_i
        assert editor > 0 && editor != pid, "no editor pid in the marker"
        assert wait_until(20) { File.exist?(fn) }, "file not created by the new editor"
        assert_eq nil, wait_exit(pid, 0.5), "launcher returned while the editor runs"
        sleep 2 # let it finish starting up
        Process.kill(:TERM, editor)
        st = wait_exit(pid, 30)
        assert st, "launcher still waiting after the editor quit"
        assert st.success?, "exit status #{st.exitstatus}: marker not released on quit"
      ensure
        (Process.kill(:KILL, pid); Process.wait(pid)) rescue nil
        (Process.kill(:KILL, editor) if editor && editor > 0) rescue nil
      end
    }
  end
end
