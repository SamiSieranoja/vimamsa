# Config dir and data dir (user_dirs.rb): the XDG defaults, --user-dir
# keeping both in one dir, which files go where, and the one-time move of
# the files of older versions
require "tmpdir"

class TestUserDirs < VmaTest
  REPO = File.expand_path("..", __dir__)

  def with_env(vars)
    old = vars.keys.to_h { |k| [k, ENV[k]] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  def test_xdg_defaults
    with_env("XDG_CONFIG_HOME" => nil, "XDG_DATA_HOME" => nil) {
      assert_eq File.expand_path("~/.config/vimamsa"), UserDirs.default_config_dir
      assert_eq File.expand_path("~/.local/share/vimamsa"), UserDirs.default_data_dir
      assert_eq File.expand_path("~/.local/share/vimamsa"), UserDirs.data_dir_for("~/.config/vimamsa")
    }
    with_env("XDG_CONFIG_HOME" => "/tmp/xc", "XDG_DATA_HOME" => "/tmp/xd") {
      assert_eq "/tmp/xc/vimamsa", UserDirs.default_config_dir
      assert_eq "/tmp/xd/vimamsa", UserDirs.data_dir_for("/tmp/xc/vimamsa")
    }
    # --user-dir: data in the same dir
    assert_eq "/tmp/somedir", UserDirs.data_dir_for("/tmp/somedir")
  end

  # The test run uses its own user dir, and data goes there too
  def test_test_run_isolated
    assert !UserDirs.default_config_dir?(vma_user_dir)
    assert_eq File.expand_path(vma_user_dir), File.expand_path(vma_data_dir)
  end

  # With separate dirs, generated files go to the data dir and the user's
  # files to the config dir
  def test_files_go_to_their_dirs
    Dir.mktmpdir { |d|
      old = $vma_data_dir
      $vma_data_dir = d
      begin
        vma.marshal_save("file_index", [])
        assert File.exist?(File.join(d, "file_index")), "file_index not in the data dir"
        assert_eq File.join(d, "file_history"), vma.var_file_path("file_history")
        assert_eq get_dot_path("bookmarks"), vma.var_file_path("bookmarks")
        assert_eq get_dot_path("named_macros"), vma.var_file_path("named_macros")
        vma.save_session
        assert File.exist?(File.join(d, "session.txt")), "session not in the data dir"
        assert_eq File.join(d, "crash"), Vimamsa::CrashHandler.crash_dir
        f = File.join(d, "afile.txt")
        File.write(f, "x\n")
        jump_to_file(f)
        b = vma.buf
        assert_eq f, b.fname
        b.backup # written on a thread
        t = Time.now
        sleep 0.02 while Dir[File.join(d, "backup", "*afile.txt_*")].empty? && Time.now - t < 2
        assert Dir[File.join(d, "backup", "*afile.txt_*")].any?, "backup not in the data dir"
        vma.buffers.close_buffer(b.id)
      ensure
        $vma_data_dir = old
      end
    }
  end

  # No code uses fixed paths (~/.vimamsa, ~/.config/vimamsa): they would
  # skip --user-dir, and the tests would touch the real user's files.
  # user_dirs.rb names the old places, to move their files.
  def test_no_fixed_user_paths
    files = Dir[File.join(REPO, "{lib,modules}/**/*.rb")] + [File.join(REPO, "exe/vimamsa")]
    files -= [File.join(REPO, "lib/vimamsa/user_dirs.rb")]
    bad = files.flat_map { |f|
      File.readlines(f).each_with_index.map { |l, i|
        next if l.strip.start_with?("#")
        "#{f.sub(REPO + "/", "")}:#{i + 1}: #{l.strip}" if l =~ %r{["']~/\.(vimamsa|config/vimamsa|config/\.vimamsa)}
      }.compact
    }
    assert bad.empty?, "fixed user paths:\n#{bad.join("\n")}"
  end

  def test_migrate
    Dir.mktmpdir { |t|
      conf, data = File.join(t, "conf"), File.join(t, "data")
      legacy, lmacro = File.join(t, "legacy"), File.join(t, "lmacro")
      w = ->(path, txt = "x") { FileUtils.mkdir_p(File.dirname(path)); File.write(path, txt) }
      w.(File.join(conf, "session.txt"), "s")
      w.(File.join(conf, "file_history"))
      w.(File.join(conf, "bookmarks"))
      w.(File.join(conf, "settings.rb"))
      w.(File.join(conf, "backup", "a_1"))
      w.(File.join(conf, "crash", "stderr.log"), "old log")
      FileUtils.mkdir_p(File.join(conf, "listen"))
      w.(File.join(data, "crash", "stderr.log"), "new log") # written at start, before the move
      w.(File.join(legacy, "cmd_history.txt"), ":e x")
      w.(File.join(legacy, "backup", "c_1"))
      w.(File.join(legacy, "backup", "a_1"), "older a")
      w.(File.join(legacy, "file_history"), "older")
      w.(File.join(lmacro, "macro_q.rb"), "macro")
      moved = UserDirs.migrate(config_dir: conf, data_dir: data, legacy_dir: legacy, legacy_macro_dir: lmacro)
      %w[session.txt file_history cmd_history.txt backup/a_1 backup/c_1].each { |n|
        assert File.exist?(File.join(data, n)), "#{n} not moved"
      }
      assert_eq "s", File.read(File.join(data, "session.txt"))
      assert_eq "x", File.read(File.join(data, "backup", "a_1")), "the config dir's backup wins"
      assert_eq "older a", File.read(File.join(legacy, "backup", "a_1")), "a file in both places left as it was"
      assert_eq "new log", File.read(File.join(data, "crash", "stderr.log"))
      assert File.exist?(File.join(conf, "crash", "stderr.log")), "the old log is kept"
      assert File.exist?(File.join(legacy, "file_history")), "older copies in ~/.vimamsa stay"
      assert File.exist?(File.join(conf, "settings.rb")) && File.exist?(File.join(conf, "bookmarks")), "config files moved"
      assert File.exist?(File.join(conf, "macro_q.rb")), "saved macro not moved to the config dir"
      assert !File.exist?(File.join(conf, "listen")), "empty old listen dir left"
      assert !File.exist?(File.join(conf, "session.txt"))
      assert moved.include?([File.join(conf, "session.txt"), File.join(data, "session.txt")])
      # once: a second run moves nothing
      assert_eq [], UserDirs.migrate(config_dir: conf, data_dir: data, legacy_dir: legacy, legacy_macro_dir: lmacro)
      # one dir (--user-dir): nothing moves
      assert_eq [], UserDirs.migrate(config_dir: conf, data_dir: conf, legacy_dir: legacy, legacy_macro_dir: lmacro)
    }
  end
end
