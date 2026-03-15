#!/usr/bin/env ruby
$stdout.sync = true
$stderr.sync = true
# run_tests.rb — Discover and run all vimamsa tests, write a report.
#
# Usage:
#   ruby run_tests.rb [REPORT_FILE]    default report: test_report.txt
#
# For headless / CI use:
#   xvfb-run ruby run_tests.rb

require "open3"

SCRIPT_DIR = File.expand_path("..", __FILE__)
REPORT     = File.expand_path(ARGV.first || "test_report.txt", SCRIPT_DIR)

# ── Discover test files ───────────────────────────────────────────────────────
test_files = Dir.glob(File.join(SCRIPT_DIR, "tests", "test_*.rb")).sort

if test_files.empty?
  warn "ERROR: No test files found in tests/"
  exit 1
end

# ── Guard: need a display ─────────────────────────────────────────────────────
unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
  xvfb = `which xvfb-run 2>/dev/null`.strip
  if xvfb.empty?
    warn "ERROR: No display found (DISPLAY/WAYLAND_DISPLAY unset) and xvfb-run not available."
    warn "       Install xvfb or run from a desktop session."
    exit 1
  end
  puts "No display detected — re-running under xvfb-run."
  exec("xvfb-run", "-a", RbConfig.ruby, __FILE__, *ARGV)
end

# ── Print header ──────────────────────────────────────────────────────────────
puts "=== Vimamsa test runner ==="
puts "Running #{test_files.size} test file(s):"
test_files.each { |f| puts "  #{File.basename(f)}" }
puts ""

# ── Run tests ─────────────────────────────────────────────────────────────────
# All files loaded in a single vimamsa session (one GTK startup).
# stdout  → streamed live and captured for the report
# stderr  → suppressed (GTK/GLib noise)
cmd = [RbConfig.ruby, "exe/run_tests.rb", "--test", *test_files]
raw = ""
IO.popen([*cmd, err: File::NULL], chdir: SCRIPT_DIR) do |io|
  io.each_line do |line|
    print line
    raw << line
  end
end
puts ""

# ── Parse summary ─────────────────────────────────────────────────────────────
summary_line = raw.lines.grep(/^Results:/).last.to_s
passed = summary_line[/(\d+) passed/, 1].to_i
failed = summary_line[/(\d+) failed/, 1].to_i
errors = raw.lines.count { |l| l.match?(/^\s+ERROR\s/) }

timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")

# ── Write report ──────────────────────────────────────────────────────────────
File.open(REPORT, "w") do |f|
  f.puts "Vimamsa Test Report — #{timestamp}"
  f.puts "=" * 52
  f.puts ""
  f.puts "Test files (#{test_files.size}):"
  test_files.each { |tf| f.puts "  #{File.basename(tf)}" }
  f.puts ""
  f.puts "-" * 52
  f.puts raw
  f.puts "-" * 52
  f.puts ""
  f.puts "Summary"
  f.puts "-" * 52
  f.puts "  Passed : #{passed}"
  f.puts "  Failed : #{failed}"
  f.puts "  Errors : #{errors}"
  f.puts "\n  ALL TESTS PASSED" if failed + errors == 0
  f.puts ""
end

puts "Report written to: #{REPORT}"
puts "  Passed: #{passed}  Failed: #{failed}  Errors: #{errors}"

exit(failed + errors == 0 ? 0 : 1)
