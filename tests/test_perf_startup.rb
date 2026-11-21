# Startup time compared with an earlier commit (scripts/lib/perf_startup.rb).
# Not in the default suite (about a minute): run it by name, e.g.
#   ./run_tests_vm.rb perf_startup              # vs the previous commit
#   ./run_tests_vm.rb perf_startup ref=HEAD~10 runs=7
# Without ref=: the previous commit, or the current one when lib/, exe/ or
# ext/ have uncommitted changes. Fails when the fastest startup grew by more
# than 25% and more than 0.3 s.
require_relative "../scripts/lib/perf_startup"

class TestPerfStartup < VmaTest
  REPO = File.expand_path("..", __dir__)

  def test_startup_not_much_slower
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    skip "not a git checkout" unless File.exist?(File.join(REPO, ".git"))
    ref = $vma_test_ref || PerfStartup.default_ref(REPO)
    runs = $vma_test_runs || 5
    puts "  startup time: current vs #{ref}, #{runs} runs each"
    times = PerfStartup.compare(REPO, ref, runs: runs, file: File.join(REPO, "README.md"))
    cur, old = times["current"].min, times[ref].min
    pct = (cur - old) / old * 100
    puts format("  fastest: current %.2f s, %s %.2f s (%+.0f%%)", cur, ref, old, pct)
    puts format("  median:  current %.2f s, %s %.2f s", PerfStartup.median(times["current"]), ref, PerfStartup.median(times[ref]))
    assert !PerfStartup.slower?(cur, old),
           format("startup is %.2f s (%+.0f%%) slower than at %s: %s vs %s", cur - old, pct, ref,
                  times["current"].map { |t| t.round(2) }.inspect, times[ref].map { |t| t.round(2) }.inspect)
  end
end
