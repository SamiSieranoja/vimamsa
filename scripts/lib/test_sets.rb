# Which test files a run covers, for run_tests_docker.rb and
# run_tests_parallel.rb. Standard library only.
module TestSets
  # Left out of the default set, as in exe/run_tests.rb: these run on their
  # own, by name
  EXCLUDED = %w[test_random_edit.rb test_notepad_bindings.rb test_vim_bindings.rb
                test_perf_startup.rb test_demo_replay.rb]

  module_function

  # A test file whose class says `needs_desktop` (lib/vimamsa/test_framework.rb)
  def needs_desktop?(path)
    File.foreach(path).any? { |l| l.match?(/^\s*needs_desktop\b/) }
  end

  # Test files (relative to repo) for args: shorthands ("undo", "foo,bar")
  # or paths; none = the default set. Returns [files, unknown args].
  def files(repo, args)
    files = []
    args.each { |a|
      if a.end_with?(".rb")
        files << a
      else
        a.split(",").each { |n| files << "tests/test_#{n.strip.sub(/\Atest_/, "")}.rb" }
      end
    }
    unknown = files.reject { |f| File.file?(File.join(repo, f)) }
    return [files, unknown] if files.any?
    files = Dir.chdir(repo) { Dir["tests/test_*.rb"].sort }
    [files.reject { |f| EXCLUDED.include?(File.basename(f)) }, []]
  end

  # [files that need the desktop, the others]
  def split(repo, files)
    files.partition { |f| needs_desktop?(File.join(repo, f)) }
  end
end
