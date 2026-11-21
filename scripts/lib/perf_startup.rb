# Startup time of the editor, for comparing two versions (a performance
# regression check). Used by tests/test_perf_startup.rb and
# scripts/perf_compare.rb. Standard library only.
#
# Startup time = from starting exe/vimamsa until the editor has finished
# initializing (hook_custom_after_init, called at the end of Editor#start)
# and the main loop has run once (first idle), measured with the system-wide
# monotonic clock. Each version runs with its own throwaway config dir and the
# same file to open. Runs alternate between the versions, after a warm-up run
# of each, so a slow moment of the machine affects both. Versions are
# compared by their fastest run: other work on the machine only ever makes a
# run slower, so the fastest one is the least disturbed (the median is
# reported too).
require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"

module PerfStartup
  module_function

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # A config dir whose custom.rb writes the time to <dir>/ready when the
  # editor is up, and quits
  def make_user_dir(dir)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "custom.rb"), <<~RUBY)
      cnf.lsp.enabled = false
      def hook_custom_after_init
        GLib::Idle.add {
          File.write(#{File.join(dir, "ready").inspect}, Process.clock_gettime(Process::CLOCK_MONOTONIC).to_s)
          GLib::Timeout.add(300) { vma.shutdown; false }
          false
        }
      end
    RUBY
    dir
  end

  # Seconds until the editor in tree (a source checkout) was up
  def startup_time(tree, user_dir, file: nil, timeout: 90)
    ready = File.join(user_dir, "ready")
    FileUtils.rm_f(ready)
    t0 = now
    pid = Process.spawn(RbConfig.ruby, File.join(tree, "exe/vimamsa"), "--user-dir", user_dir, *[file].compact,
                        out: File::NULL, err: File.join(user_dir, "log.txt"))
    t = nil
    loop {
      if File.exist?(ready) && (s = File.read(ready)) != ""
        t = s.to_f - t0
        break
      end
      if Process.waitpid(pid, Process::WNOHANG)
        pid = nil
        raise "editor in #{tree} quit before it was up (log: #{user_dir}/log.txt)"
      end
      raise "editor in #{tree} not up after #{timeout} s (log: #{user_dir}/log.txt)" if now - t0 > timeout
      sleep 0.01
    }
    # Let it quit by itself (custom.rb shuts it down)
    t1 = now
    while pid && Process.waitpid(pid, Process::WNOHANG).nil?
      if now - t1 > 20
        Process.kill("KILL", pid)
        Process.wait(pid)
      end
      sleep 0.05
    end
    pid = nil
    t
  ensure
    if pid
      Process.kill("KILL", pid) rescue nil
      Process.wait(pid) rescue nil
    end
  end

  # Yields a checkout of ref (a temporary git worktree of repo). It gets this
  # tree's compiled extension (lib/vmaext.so): its source isn't tracked, so
  # an old commit can't be built.
  def with_checkout(repo, ref)
    dir = Dir.mktmpdir("vma-perf-ref")
    FileUtils.rmdir(dir)
    out, st = Open3.capture2e("git", "-C", repo, "worktree", "add", "--detach", "--force", dir, ref)
    raise "git worktree add #{ref} failed: #{out}" if !st.success?
    so = File.join(repo, "lib", "vmaext.so")
    FileUtils.cp(so, File.join(dir, "lib")) if File.exist?(so)
    yield dir
  ensure
    if dir && File.exist?(dir)
      system("git", "-C", repo, "worktree", "remove", "--force", dir, out: File::NULL, err: File::NULL)
      FileUtils.rm_rf(dir)
    end
  end

  # { "current" => [seconds...], ref => [...] } for runs startups of each
  def compare(repo, ref, runs: 5, file: nil, log: ->(s) { puts s })
    Dir.mktmpdir("vma-perf") { |tmp|
      with_checkout(repo, ref) { |old|
        trees = { "current" => repo, ref => old }
        dirs = trees.to_h { |name, _| [name, make_user_dir(File.join(tmp, name.gsub(/\W/, "_")))] }
        times = trees.to_h { |name, _| [name, []] }
        trees.each { |name, tree| startup_time(tree, dirs[name], file: file) } # warm-up
        runs.times { |i|
          trees.each { |name, tree|
            t = startup_time(tree, dirs[name], file: file)
            times[name] << t
            log.("  run #{i + 1} #{name}: #{format("%.2f", t)} s")
          }
        }
        times
      }
    }
  end

  def median(a)
    s = a.sort
    s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0
  end

  # The commit to compare with by default: the previous one, or the current
  # commit when the working tree has uncommitted changes to the code (then
  # those changes are what's being checked)
  def default_ref(repo)
    out, = Open3.capture2("git", "-C", repo, "status", "--porcelain", "--", "lib", "exe", "ext")
    out.strip.empty? ? "HEAD~1" : "HEAD"
  end

  # Slower = the median grew by more than ratio and by more than min_secs
  # (small absolute changes are noise)
  def slower?(cur, ref, ratio: 0.25, min_secs: 0.3)
    cur - ref > ref * ratio && cur - ref > min_secs
  end
end
