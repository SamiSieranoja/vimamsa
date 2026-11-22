require "tmpdir"

# cnf.startup_file is the buffer shown on startup even when the previous
# session is restored (restoring would otherwise leave its last file current).
class TestStartupFile < VmaTest
  # Runs the main loop until the block is true (a session restore opens its
  # files one per main loop turn)
  def wait_until(secs = 10)
    t = Time.now
    until yield || Time.now - t > secs
      drain_idle
      sleep 0.01
    end
    yield
  end

  def test_startup_file_stays_current_after_session_restore
    Dir.mktmpdir do |dir|
      startup = "#{dir}/startup.txt"
      a = "#{dir}/a.txt"
      b = "#{dir}/b.txt"
      File.write(startup, "startup\n")
      File.write(a, "a\n")
      File.write(b, "b\n")
      session = get_data_path("session.txt")
      File.write(session, "#{a}\n#{b}\n")

      open_new_file(startup)
      vma.instance_variable_set(:@startup_fname, startup)
      ENV["VIMAMSA_RESTORE_SESSION"] = "1"
      begin
        vma.check_session_restore
        assert wait_until { vma.buffers.get_buffer_by_filename(b) && vma.gui.status_indicator(:session_restore).nil? }
        assert_eq startup, vma.buf.fname
        assert vma.buffers.get_buffer_by_filename(a), "session file a restored"
        assert vma.buffers.get_buffer_by_filename(b), "session file b restored"
      ensure
        ENV.delete("VIMAMSA_RESTORE_SESSION")
        vma.instance_variable_set(:@startup_fname, nil)
        File.delete(session) if File.exist?(session)
        [b, a, startup].each { |f|
          id = vma.buffers.get_buffer_by_filename(f)
          vma.buffers.close_buffer(id) if id
        }
        drain_idle
      end
    end
  end

  def test_without_startup_file_last_session_file_is_current
    Dir.mktmpdir do |dir|
      a = "#{dir}/a.txt"
      b = "#{dir}/b.txt"
      File.write(a, "a\n")
      File.write(b, "b\n")
      begin
        done = false
        vma.restore_session_files([a, b]) { done = true }
        assert wait_until { done }, "restore didn't finish"
        assert_eq b, vma.buf.fname
      ensure
        [b, a].each { |f|
          id = vma.buffers.get_buffer_by_filename(f)
          vma.buffers.close_buffer(id) if id
        }
        drain_idle
      end
    end
  end

  # A session opens one file per main loop turn with its progress in the
  # status bar ("Restoring session: 2/5 c.txt"), gone at the end; a file
  # that can't be opened is skipped
  def test_restore_shows_progress
    Dir.mktmpdir do |dir|
      files = %w[a b c d e].map { |n| f = "#{dir}/#{n}.txt"; File.write(f, "#{n}\n"); f }
      bad = "#{dir}/gone.txt" # deleted after the list was made
      seen = []
      done = false
      begin
        vma.restore_session_files(files[0, 2] + [bad] + files[2..]) { done = true }
        assert_eq "Restoring session: 0/6", vma.gui.status_indicator(:session_restore), "no progress before the first file"
        wait_until { seen << vma.gui.status_indicator(:session_restore); done }
        assert done, "restore didn't finish"
        # some file in between (one main loop drain can open several)
        assert seen.compact.any? { |t| t.match?(%r{\ARestoring session: [1-5]/6 }) }, seen.compact.uniq.inspect
        assert_eq nil, vma.gui.status_indicator(:session_restore), "progress still shown"
        files.each { |f| assert vma.buffers.get_buffer_by_filename(f), "#{f} not restored" }
      ensure
        files.each { |f|
          id = vma.buffers.get_buffer_by_filename(f)
          vma.buffers.close_buffer(id) if id
        }
        drain_idle
      end
    end
  end

end
