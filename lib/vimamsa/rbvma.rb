#require "gtksourceview4"
require "date"
require "fileutils"
require "gtk3"
require "gtksourceview4"
require "json"
require "listen"
require "pathname"
require "ripl"
require "ripl/multi_line"
require "shellwords"
require "cgi"
require "uri"

require "vimamsa/util"
require "vimamsa/main"

require "vimamsa/actions"
require "vimamsa/key_binding_tree"
require "vimamsa/key_actions"

# Graphical stuff:
require "vimamsa/gui"
require "vimamsa/gui_menu"
require "vimamsa/gui_select_window"
require "vimamsa/gui_sourceview"
require "vimamsa/gui_image"
require "vimamsa/hyper_plain_text"

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
require "vimamsa/macro"
require "vimamsa/search"
require "vimamsa/search_replace"
require "vimamsa/conf"
# load "vendor/ver/lib/ver/vendor/textpow.rb"
# load "vendor/ver/lib/ver/syntax/detector.rb"
# load "vendor/ver/config/detect.rb"

$vma = Editor.new

def vma()
  return $vma
end

def unimplemented
  debug "unimplemented"
end


$debug = false

def scan_indexes(txt, regex)
  # indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0) + 1 }
  indexes = txt.enum_for(:scan, regex).map { Regexp.last_match.begin(0)  }
  return indexes
end

$update_cursor = false


