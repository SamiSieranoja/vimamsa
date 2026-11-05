require "tmpdir"

# cnf.startup_file is the buffer shown on startup even when the previous
# session is restored (restoring would otherwise leave its last file current).
class TestStartupFile < VmaTest
  def test_startup_file_stays_current_after_session_restore
    Dir.mktmpdir do |dir|
      startup = "#{dir}/startup.txt"
      a = "#{dir}/a.txt"
      b = "#{dir}/b.txt"
      File.write(startup, "startup\n")
      File.write(a, "a\n")
      File.write(b, "b\n")
      session = get_dot_path("session.txt")
      File.write(session, "#{a}\n#{b}\n")

      open_new_file(startup)
      vma.instance_variable_set(:@startup_fname, startup)
      ENV["VIMAMSA_RESTORE_SESSION"] = "1"
      begin
        vma.check_session_restore
        drain_idle
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
        vma.restore_session_files([a, b])
        drain_idle
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
end
