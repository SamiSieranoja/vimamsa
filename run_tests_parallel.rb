#!/usr/bin/env ruby
# The full test suite, split: the tests that need the real desktop (their
# class says `needs_desktop`) run in the test VM (run_tests_vm.rb), all the
# others in Docker containers on invisible displays (run_tests_docker.rb),
# both at the same time.
#
# Usage:
#   ./run_tests_parallel.rb            # default set
#   ./run_tests_parallel.rb -j 8       # 8 containers (run_tests_docker.rb -j)
#
# Logs: build/test_parallel/{vm,docker}.log. Exit code 0 when both passed.
require "fileutils"
require_relative "scripts/lib/script_helpers"
require_relative "scripts/lib/test_sets"
include ScriptHelpers

REPO = File.expand_path(__dir__)
OUT = File.join(REPO, "build", "test_parallel")
FileUtils.mkdir_p(OUT)

jobs = []
if (i = ARGV.index("-j"))
  jobs = ["-j", ARGV[i + 1].to_s]
  ARGV.slice!(i, 2)
end
fail!("run_tests_parallel.rb runs the default set; for some files use run_tests_docker.rb " \
      "or run_tests_vm.rb", 2) if ARGV.any?

files, = TestSets.files(REPO, [])
desktop, headless = TestSets.split(REPO, files)
step "#{headless.size} test files in containers, #{desktop.size} in the VM (needs_desktop)"

t0 = Time.now
runs = {
  "docker" => [File.join(REPO, "run_tests_docker.rb"), *jobs, *headless],
  "vm" => (desktop.empty? ? nil : [File.join(REPO, "run_tests_vm.rb"), *desktop]),
}.compact.map { |name, cmd|
  log = File.join(OUT, "#{name}.log")
  Thread.new {
    system(*cmd, out: log, err: [:child, :out], chdir: REPO)
    out = File.read(log, encoding: "UTF-8").scrub
    res = out.scan(/^Results: .*$/).last
    step "#{name} done in #{(Time.now - t0).round} s: #{res || "no result (see #{log})"}"
    { name: name, ok: $?.success? && !res.nil?, res: res, fails: out.scan(/^  (?:FAIL|ERROR) .*$/), log: log }
  }
}.map(&:value)

puts "\n#{"=" * 50}"
runs.each { |r| puts "#{r[:name]}: #{r[:res] || "no result (#{r[:log]})"}" }
runs.flat_map { |r| r[:fails].map { |f| "#{r[:name]}: #{f.strip}" } }.uniq.each { |f| puts "  #{f}" }
ok = runs.all? { |r| r[:ok] }
puts "#{ok ? "PASSED" : "FAILED"} in #{(Time.now - t0).round} s"
puts "=" * 50
exit(ok ? 0 : 1)
