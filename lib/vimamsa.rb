require "vimamsa/version"
require "vmaext"

require "vimamsa/rbvma"

module Vimamsa
  # Your code goes here...
  def self.test
    puts "Vimamsa test"
    puts srn_dst("foobar", "baz")
  end
end
