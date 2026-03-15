#!/usr/bin/ruby
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

require "vimamsa"
$vmag = VMAgui.new()
$vmag.run

