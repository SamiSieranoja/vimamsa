#!/usr/bin/env ruby
# Compare the editor's startup time with an earlier commit, on this machine
# (the same check as tests/test_perf_startup.rb, without the test runner).
# Opens editor windows on the current display, one after another.
#
#   ruby scripts/perf_compare.rb [--ref REF] [--runs N]
#     --ref   commit to compare with (default: the previous commit, or the
#             current one when lib/, exe/ or ext/ have uncommitted changes)
#     --runs  startups of each version (default 5)
#
# Exit code: 0 ok, 1 the current version starts much slower (fastest run
# more than 25% and 0.3 s slower).
require "optparse"
require_relative "lib/perf_startup"
require_relative "lib/script_helpers"
include ScriptHelpers

repo = File.expand_path("..", __dir__)
opts = { ref: nil, runs: 5 }
OptionParser.new { |o|
  o.on("--ref REF") { |v| opts[:ref] = v }
  o.on("--runs N", Integer) { |v| opts[:runs] = v }
}.parse!
fail!("--runs must be at least 1", 2) if opts[:runs] < 1
fail!("needs a display (DISPLAY or WAYLAND_DISPLAY)", 2) if missing_env("DISPLAY", "WAYLAND_DISPLAY").size == 2
ref = opts[:ref] || PerfStartup.default_ref(repo)

step "Startup time: current vs #{ref}, #{opts[:runs]} runs each"
times = PerfStartup.compare(repo, ref, runs: opts[:runs], file: File.join(repo, "README.md"))
cur, old = times["current"].min, times[ref].min
pct = (cur - old) / old * 100
step format("Fastest: current %.2f s, %s %.2f s (%+.0f%%)", cur, ref, old, pct)
step format("Median:  current %.2f s, %s %.2f s", PerfStartup.median(times["current"]), ref, PerfStartup.median(times[ref]))
fail!(format("Startup is %.2f s slower than at %s", cur - old, ref), 1) if PerfStartup.slower?(cur, old)
