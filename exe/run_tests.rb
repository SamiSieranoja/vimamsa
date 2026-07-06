#!/usr/bin/ruby
# Usage:
#   run_tests.rb                          # run all tests in tests/
#   run_tests.rb tests/test_foo.rb        # run specific file
#   run_tests.rb TestFooClass             # run specific class (all files)
#   run_tests.rb tests/test_foo.rb TestFooClass  # specific class from specific file
#   run_tests.rb foo,bar,baz              # run tests/test_foo.rb, test_bar.rb, test_baz.rb
#   run_tests.rb test_random_edit duration=60   # pass duration option to stress test
#   run_tests.rb --headless               # invisible window (xvfb-run, or Broadway if
#                                         # xvfb not installed); does not disturb
#                                         # normal use; e2e kbd tests skip

require "ripl/multi_line"
require "tempfile"
require "pathname"

ENV["GTK_THEME"] = "Adwaita:light"

selfpath = __FILE__
selfpath = File.readlink(selfpath) if File.lstat(selfpath).symlink?
scriptdir = File.expand_path(File.dirname(selfpath) + "/..")

$LOAD_PATH.unshift(File.expand_path("lib"))
$LOAD_PATH.unshift(File.expand_path("ext"))
begin
  gem_spec = Gem::Specification.find_by_name("vimamsa")
  $LOAD_PATH.unshift(File.join(gem_spec.gem_dir, "ext", "vmaext")) if gem_spec
rescue Gem::MissingSpecError
end

raw_args     = ARGV.dup.reject { |a| a == "--test" }

# --headless: run on an invisible display instead of the desktop. No window
# appears and focus is not touched, so tests can run in the background during
# normal use. E2E virtual-keyboard tests detect this and skip (uinput events
# go to the real seat, not to a headless display).
#
# Preferred backend: xvfb-run (private X server per run, auto display
# allocation and teardown). Fallback: GTK's Broadway backend (no extra
# packages, but a fixed shared display :9).
if raw_args.delete("--headless")
  if system("which xvfb-run > /dev/null 2>&1")
    # Re-exec self under a private Xvfb server. GTK must take the x11 backend
    # and not the real Wayland session. xvfb-run exits with our exit code.
    ENV["GDK_BACKEND"] = "x11"
    ENV.delete("WAYLAND_DISPLAY")
    exec("xvfb-run", "-a", "-s", "-screen 0 1600x1000x24",
         RbConfig.ruby, File.expand_path(selfpath), *(ARGV - ["--headless"]))
  end
  require "socket"
  # Display :9 listens on broadway10.socket (broadwayd numbers sockets display+1).
  # A killed broadwayd leaves its socket file behind; a new daemon then fails to
  # bind and the app hangs connecting to the dead socket — so probe it and clean up.
  sock = File.join(ENV["XDG_RUNTIME_DIR"] || "/run/user/#{Process.uid}", "broadway10.socket")
  broadwayd_alive = false
  if File.socket?(sock)
    begin
      UNIXSocket.new(sock).close
      broadwayd_alive = true # reuse the running daemon
    rescue SystemCallError
      File.unlink(sock)
    end
  end
  unless broadwayd_alive
    bpid = Process.spawn("gtk4-broadwayd", ":9", :out => "/dev/null", :err => "/dev/null")
    Process.detach(bpid)
    at_exit do
      begin
        Process.kill("TERM", bpid)
      rescue Errno::ESRCH, Errno::EPERM
      end
    end
    sleep 0.5 # let broadwayd create its socket before GTK connects
  end
  ENV["GDK_BACKEND"] = "broadway"
  ENV["BROADWAY_DISPLAY"] = ":9"
end

test_files   = raw_args.select { |a| a.end_with?(".rb") && File.file?(a) }
class_filter = raw_args.select { |a| a.match?(/\A[A-Z]/) }

# Parse key=value options (e.g. duration=60)
raw_args.each do |a|
  $vma_test_duration = $1.to_i if a =~ /\Aduration=(\d+)\z/
end

# Expand comma-separated shorthand: "foo,bar" -> tests/test_foo.rb, tests/test_bar.rb
# Accepts both "foo" and "test_foo" as shorthand for tests/test_foo.rb.
raw_args.each do |a|
  next if a.end_with?(".rb") || a.match?(/\A[A-Z]/) || a.match?(/\A\w+=/)
  a.split(",").each do |name|
    name = name.strip.sub(/\Atest_/, "")
    path = File.join(scriptdir, "tests", "test_#{name}.rb")
    test_files << path if File.file?(path)
  end
end

if test_files.empty?
  test_files = Dir[File.join(scriptdir, "tests", "test_*.rb")].sort
  # test_random_edit: stress test, run explicitly.
  # test_notepad_bindings / test_vim_bindings: load alternative keybinding
  # schemes, which would corrupt bindings for later test files in the
  # shared process.
  excluded = ["test_random_edit.rb", "test_notepad_bindings.rb", "test_vim_bindings.rb"]
  test_files.reject! { |f| excluded.include?(File.basename(f)) }
end

$vma_test_class_filter = class_filter.empty? ? nil : class_filter

ARGV.replace(["--test"] + test_files)

require "vimamsa"
include Vimamsa
$vmag = Vimamsa::VMAgui.new()
$vmag.run

# GTK has quit and the results are printed. Exit without normal teardown:
# StrIdx's C++ indexing threads race with static destructors at exit and can
# segfault after a fully successful run (timing-dependent, seen under
# --headless). exit! skips at_exit, so stop our broadwayd explicitly first.
STDOUT.flush
if defined?(bpid) && bpid
  begin
    Process.kill("TERM", bpid)
  rescue Errno::ESRCH, Errno::EPERM
  end
end
exit!($vma_tests_ok == false ? 1 : 0)
