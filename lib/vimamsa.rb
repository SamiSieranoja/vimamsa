require "vimamsa/version"

require "vmaext"

require "stridx"

require "vimamsa/rbvma"

module Vimamsa
  def self.test
    puts "Vimamsa c-extension test"
    puts srn_dst("foobar", "baz")
  end
end
