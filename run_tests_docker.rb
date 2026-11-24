#!/usr/bin/env ruby
# Run the tests that don't need a real desktop in Docker containers, several
# at once, each on its own invisible display (xvfb). The working tree's
# source (incl. uncommitted changes) is unpacked into each container; the
# image (scripts/test_docker/Dockerfile) holds the packages and gems.
#
# Usage:
#   ./run_tests_docker.rb                 # the default set, minus needs_desktop files
#   ./run_tests_docker.rb -j 8            # in 8 containers (default: CPUs / 3, max 8)
#   ./run_tests_docker.rb undo,fold       # these files (shorthands as run_tests.rb)
#   ./run_tests_docker.rb --all           # include needs_desktop files too (to find
#                                         # out which tests need the desktop)
#
# The files are split between the containers by their times in earlier runs
# (build/test_docker/times.json, updated after each run). Logs per container:
# build/test_docker/shard-N.log. Exit code 0 when every container passed.
require "json"
require "digest"
require "fileutils"
require "etc"
require_relative "scripts/lib/script_helpers"
require_relative "scripts/lib/source_pack"
require_relative "scripts/lib/test_sets"
include ScriptHelpers

REPO = File.expand_path(__dir__)
WORK = File.join(REPO, "build", "test_docker")
TIMES = File.join(WORK, "times.json")
# Split files into n groups of about equal time, longest first
def shards(files, n)
  times = (JSON.parse(File.read(TIMES)) rescue {})
  # No time yet: guess from the size (about 1 s per 2 kB of test code)
  est = files.to_h { |f| [f, times[f] || File.size(File.join(REPO, f)) / 2000.0] }
  groups = Array.new([n, files.size].min) { [[], 0.0] }
  files.sort_by { |f| -est[f] }.each { |f|
    g = groups.min_by { |_, t| t }
    g[0] << f
    g[1] += est[f]
  }
  groups.map(&:first)
end

# Build the image if this Dockerfile + gem list isn't built yet; its tag
def image
  dir = File.join(WORK, "image")
  FileUtils.mkdir_p(dir)
  FileUtils.cp(File.join(REPO, "scripts/test_docker/Dockerfile"), dir)
  spec = Dir.chdir(REPO) { Gem::Specification.load("vimamsa.gemspec") }
  gems = spec.dependencies.map { |d| "#{d.name} #{d.requirement.to_s.delete(" ")}" }
  File.write(File.join(dir, "gems.txt"), gems.join("\n") + "\n")
  tag = "vimamsa-test:" + Digest::SHA256.hexdigest(File.read(File.join(dir, "Dockerfile")) + gems.join)[0, 12]
  if !system("docker", "image", "inspect", tag, out: File::NULL, err: File::NULL)
    step "Building the test image #{tag} (the first time compiles the GTK gems: slow)"
    run!("docker", "build", "-q", "--build-arg", "UID=#{Process.uid}", "-t", tag, dir, out: File::NULL,
         label: "docker build")
  end
  tag
end

all = !ARGV.delete("--all").nil?
jobs = nil
if (i = ARGV.index("-j"))
  jobs = ARGV[i + 1].to_i
  ARGV.slice!(i, 2)
end
jobs = [[Etc.nprocessors / 3, 1].max, 8].min if jobs.nil? || jobs < 1

files, unknown = TestSets.files(REPO, ARGV)
fail!("unknown test file: #{unknown.join(", ")}", 2) if unknown.any?
# Without named files: the default set, minus the needs_desktop ones
files = TestSets.split(REPO, files)[1] if ARGV.empty? && !all
fail!("no test files to run", 2) if files.empty?
FileUtils.mkdir_p(File.join(WORK, "cache"))
FileUtils.mkdir_p(File.join(WORK, "out"))
Dir[File.join(WORK, "out", "*")].each { |f| File.delete(f) }
tag = image
step "Packing working tree"
SourcePack.pack(REPO, File.join(WORK, "src.tgz"))

docker = ->(name, env = {}) {
  ["docker", "run", "--rm", "--name", name, "--init",
   "-v", "#{File.join(WORK, "src.tgz")}:/in/src.tgz:ro",
   "-v", "#{File.join(WORK, "cache")}:/cache",
   "-v", "#{File.join(WORK, "out")}:/out",
   "-v", "#{File.join(REPO, "scripts/test_docker/run_in_container.sh")}:/in/run.sh:ro",
   *env.flat_map { |k, v| ["-e", "#{k}=#{v}"] },
   tag, "bash", "/in/run.sh"]
}
run_id = "vma-test-#{Process.pid}"
# The extension once, so the containers don't all build it
run!(*docker.("#{run_id}-build", "VMA_BUILD_ONLY" => "1"), label: "building the extension")

groups = shards(files, jobs)
step "#{files.size} test files in #{groups.size} containers"
t0 = Time.now
threads = groups.each_with_index.map { |group, i|
  log = File.join(WORK, "shard-#{i}.log")
  Thread.new {
    cmd = docker.("#{run_id}-#{i}", "VMA_TEST_ARGS" => group.join(" "), "VMA_TIMES_OUT" => "/out/times-#{i}.json")
    system(*cmd, out: log, err: [:child, :out])
    out = File.read(log, encoding: "UTF-8").scrub
    res = out[/^Results: .*$/]
    step "container #{i} done in #{(Time.now - t0).round} s: #{res || "no result (see #{log})"}"
    { log: log, out: out, ok: !!out[/^VMA_SUITE_EXIT=0$/], result: res }
  }
}
# ctrl-c: stop the containers too
trap("INT") {
  ids = `docker ps -q --filter name=#{run_id}`.split
  system("docker", "kill", *ids, out: File::NULL) if ids.any?
  exit 130
}
results = threads.map(&:value)

# Remember the times for the next split
times = (JSON.parse(File.read(TIMES)) rescue {})
Dir[File.join(WORK, "out", "times-*.json")].each { |f| times.merge!(JSON.parse(File.read(f))) rescue nil }
File.write(TIMES, JSON.pretty_generate(times.sort.to_h))

passed = results.sum { |r| r[:result].to_s[/(\d+) passed/, 1].to_i }
failed = results.flat_map { |r| r[:out].scan(/^  (?:FAIL|ERROR) .*$/) }
skipped = results.sum { |r| r[:result].to_s[/(\d+) skipped/, 1].to_i }
broken = results.reject { |r| r[:result] }
puts "\n#{"=" * 50}"
puts "Results: #{passed} passed, #{failed.size} failed, #{skipped} skipped " \
     "(#{groups.size} containers, #{(Time.now - t0).round} s)"
failed.each { |l| puts l }
broken.each { |r| puts "  NO RESULT: #{r[:log]}" }
puts "=" * 50
exit(results.all? { |r| r[:ok] } ? 0 : 1)
