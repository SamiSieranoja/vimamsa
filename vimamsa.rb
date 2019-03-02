#!/usr/bin/ruby
# require 'ripl/multi_line'
# Ripl.config[:multi_line_prompt] = ' > '
require "pathname"

selfpath = __FILE__
selfpath = File.readlink(selfpath) if File.lstat(selfpath).symlink?
scriptdir = File.expand_path(File.dirname(selfpath))

binpath = "#{scriptdir}/vimamsa"

argexp = [binpath]
for arg in ARGV
  puts arg
  argexp << Pathname(arg).expand_path.to_s
end

Dir.chdir(scriptdir)
exec(*argexp)