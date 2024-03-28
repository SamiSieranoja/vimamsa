require "vimamsa/version"

require "vmaext"

$:.unshift File.expand_path(File.dirname(__FILE__)+"/../ext/stridx")
require "stridx"

require "vimamsa/rbvma"

module Vimamsa
  def self.test
    puts "Vimamsa c-extension test"
    puts srn_dst("foobar", "baz")
  end
end
