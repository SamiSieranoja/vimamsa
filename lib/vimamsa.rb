require "vimamsa/version"

require "gtk3"
require "gtksourceview4"
test1 = Gtk::TextView.new

require "vmaext"

require "vimamsa/rbvma"

module Vimamsa
  # Your code goes here...
  def self.test
    puts "Vimamsa test"
    puts srn_dst("foobar", "baz")
  end
end
