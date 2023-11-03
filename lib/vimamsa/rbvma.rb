require "date"
require "fileutils"

require "gtk4"
require "gtksourceview5"

require "json"
require "listen"
require "pathname"
require "ripl"
require "ripl/multi_line"
require "shellwords"
require "cgi"
require "uri"
require "vimamsa/conf"
require "vimamsa/util"
# exit!
require "vimamsa/main"
require "vimamsa/terminal"

require "vimamsa/actions"
require "vimamsa/key_binding_tree"
require "vimamsa/key_actions"

# Graphical stuff:
require "vimamsa/gui"
require "vimamsa/gui_form_generator"
require "vimamsa/gui_text"
require "vimamsa/gui_menu"
require "vimamsa/gui_dialog"
require "vimamsa/gui_select_window"
require "vimamsa/gui_sourceview"
require "vimamsa/gui_image"
require "vimamsa/hyper_plain_text"

require "vimamsa/ack"
require "vimamsa/buffer"
require "vimamsa/buffer_cursor"
require "vimamsa/buffer_changetext"
require "vimamsa/buffer_list"
require "vimamsa/buffer_manager"
require "vimamsa/constants"
require "vimamsa/debug"
require "vimamsa/tests"
require "vimamsa/easy_jump"
require "vimamsa/encrypt"
require "vimamsa/file_finder"
require "vimamsa/file_manager"
require "vimamsa/hook"
require "vimamsa/macro"
require "vimamsa/search"
require "vimamsa/search_replace"
# load "vendor/ver/lib/ver/vendor/textpow.rb"
# load "vendor/ver/lib/ver/syntax/detector.rb"
# load "vendor/ver/config/detect.rb"

def unimplemented
  debug "unimplemented"
end

cnf.debug = false
$update_cursor = false


