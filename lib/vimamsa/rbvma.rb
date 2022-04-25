require "gtk3"
require "gtksourceview3"
#require "gtksourceview4"
require "ripl"
require "fileutils"
require "pathname"
require "date"
require "ripl/multi_line"
require "json"
require "listen"

require "vimamsa/util"
require "vimamsa/main"

require "vimamsa/actions"
require "vimamsa/key_binding_tree"
require "vimamsa/key_actions"


require "vimamsa/gui"
require "vimamsa/gui_menu"
require "vimamsa/gui_select_window"
require "vimamsa/gui_sourceview"

require "vimamsa/ack"
require "vimamsa/buffer"
require "vimamsa/buffer_list"
require "vimamsa/buffer_manager"
require "vimamsa/constants"
require "vimamsa/debug"
require "vimamsa/easy_jump"
require "vimamsa/encrypt"
require "vimamsa/file_finder"
require "vimamsa/file_manager"
require "vimamsa/hook"
require "vimamsa/hyper_plain_text"
require "vimamsa/macro"
require "vimamsa/search"
require "vimamsa/search_replace"
# load "vendor/ver/lib/ver/vendor/textpow.rb"
# load "vendor/ver/lib/ver/syntax/detector.rb"
# load "vendor/ver/config/detect.rb"

$vma = Editor.new

def vma()
  return $vma
end

def unimplemented
  puts "unimplemented"
end


$debug = false

def scan_indexes(txt, regex)
  # indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) + 1 }
  indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) }
  return indexes
end

$update_cursor = false


