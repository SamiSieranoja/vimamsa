# vimamsa --tmp-user-dir: a new user dir in the temp dir, deleted on quit
# (lib/vimamsa/tmp_user_dir.rb, exe/vimamsa); kill / ctrl-c quit normally
require "open3"
require "rbconfig"
require "tmpdir"

class TestTmpUserDir < VmaTest
  EXE = File.expand_path("../exe/vimamsa", __dir__)

  def test_ours
    d = TmpUserDir.create
    assert TmpUserDir.ours?(d)
    assert File.basename(d).start_with?("vimamsa-user-")
    assert TmpUserDir.delete(d)
    assert !File.exist?(d)
    # never other dirs
    Dir.mktmpdir("other-") { |o|
      assert !TmpUserDir.ours?(o)
      assert !TmpUserDir.delete(o)
      assert File.exist?(o)
      nested = File.join(o, "vimamsa-user-x")
      FileUtils.mkdir_p(nested)
      assert !TmpUserDir.ours?(nested), "not directly in the temp dir"
    }
    assert !TmpUserDir.ours?(nil)
    assert !TmpUserDir.ours?(File.expand_path("~/.config/vimamsa"))
  end

  # A real start: the dir is made, the editor comes up in it (the intro page
  # writes settings.rb), and a TERM quits the editor and deletes the dir
  def test_created_and_deleted_on_quit
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    out = +""
    dir = nil
    Open3.popen2e(*vma_editor_command(EXE), "--tmp-user-dir") { |_in, oe, th|
      reader = Thread.new { oe.each_line { |l| out << l } rescue nil }
      t = Time.now
      until (dir = out[/Temporary user dir \(deleted on quit\): (\S+)/, 1]) || Time.now - t > 30
        sleep 0.05
      end
      assert dir, "no dir reported: #{out[-500..]}"
      assert TmpUserDir.ours?(dir)
      t = Time.now
      sleep 0.1 until File.exist?(File.join(dir, "settings.rb")) || !th.alive? || Time.now - t > 60
      assert File.exist?(File.join(dir, "custom.rb")), "editor didn't start in #{dir}: #{out[-800..]}"
      assert File.exist?(File.join(dir, "settings.rb")), "intro not shown at start"
      Process.kill("TERM", th.pid)
      t = Time.now
      sleep 0.1 while th.alive? && Time.now - t < 20
      if th.alive?
        Process.kill("KILL", th.pid)
        assert false, "editor didn't quit on TERM"
      end
      reader.join(2)
    }
    assert !File.exist?(dir), "#{dir} not deleted on quit"
  ensure
    TmpUserDir.delete(dir) if dir
  end

  # A dir with a crash report stays (the report would be lost otherwise)
  def test_kept_with_crash_report
    d = TmpUserDir.create
    FileUtils.mkdir_p(File.join(d, "crash"))
    File.write(File.join(d, "crash", "stderr.log"), "log")
    File.write(File.join(d, "crash", "crash_20261121_000000_1.txt"), "report")
    assert !TmpUserDir.delete(d)
    assert File.exist?(File.join(d, "crash", "crash_20261121_000000_1.txt"))
    FileUtils.rm_f(File.join(d, "crash", "crash_20261121_000000_1.txt"))
    assert TmpUserDir.delete(d), "only stderr.log: deleted"
    assert !File.exist?(d)
  ensure
    FileUtils.rm_rf(d) if d && File.exist?(d)
  end

  def test_help_mentions_it
    assert Vimamsa::CLI_USAGE.include?("--tmp-user-dir")
  end
end
