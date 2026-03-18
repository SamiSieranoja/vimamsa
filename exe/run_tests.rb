#!/usr/bin/ruby
# Usage:
#   run_tests.rb                          # run all tests in tests/
#   run_tests.rb tests/test_foo.rb        # run specific file
#   run_tests.rb TestFooClass             # run specific class (all files)
#   run_tests.rb tests/test_foo.rb TestFooClass  # specific class from specific file
#   run_tests.rb foo,bar,baz              # run tests/test_foo.rb, test_bar.rb, test_baz.rb

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

raw_args     = ARGV.dup
test_files   = raw_args.select { |a| a.end_with?(".rb") && File.file?(a) }
class_filter = raw_args.select { |a| a.match?(/\A[A-Z]/) }

# Expand comma-separated shorthand: "foo,bar" -> tests/test_foo.rb, tests/test_bar.rb
raw_args.each do |a|
  next if a.end_with?(".rb") || a.match?(/\A[A-Z]/)
  a.split(",").each do |name|
    path = File.join(scriptdir, "tests", "test_#{name.strip}.rb")
    test_files << path if File.file?(path)
  end
end

test_files = Dir[File.join(scriptdir, "tests", "test_*.rb")].sort if test_files.empty?

$vma_test_class_filter = class_filter.empty? ? nil : class_filter

ARGV.replace(["--test"] + test_files)

require "vimamsa"
$vmag = VMAgui.new()
$vmag.run
