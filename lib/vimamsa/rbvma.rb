
module Vimamsa
extend self

# Make all Vimamsa methods callable as bare method calls from any class.
# Must run before any Vimamsa sub-files are required so that ConfId/Conf
# can resolve set/get as instance methods at load time.
class Object
  include Vimamsa
end

# require "bundler/setup"
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
require "vimamsa/string_util"
# Clipboard must load before main: main.rb runs Editor.new at load time,
# and Editor#initialize creates a Clipboard.
require "vimamsa/clipboard"
# exit!
require "vimamsa/main"
require "vimamsa/terminal"

require "vimamsa/key_binding_tree"
require "vimamsa/key_bindings_report"

require "vimamsa/desktop_install"

# Graphical stuff:
require "vimamsa/gui"
require "vimamsa/gui_form_generator"
require "vimamsa/gui_text"
require "vimamsa/gui_menu"
require "vimamsa/gui_dialog"
require "vimamsa/gui_command_line"
require "vimamsa/gui_settings"
require "vimamsa/gui_theme"
require "vimamsa/gui_file_panel"
require "vimamsa/gui_func_panel"
require "vimamsa/gui_keylog_panel"
require "vimamsa/gui_select_window"
require "vimamsa/gui_sourceview"
require "vimamsa/gui_sourceview_autocomplete"
require "vimamsa/gui_image"
require "vimamsa/hyper_plain_text"
require "vimamsa/color_highlight"

require "vimamsa/ack"
require "vimamsa/buffer"
require "vimamsa/buffer_cursor"
require "vimamsa/buffer_changetext"
# require "vimamsa/buffer_list"
require "vimamsa/buffer_list"
require "vimamsa/buffer_manager"
require "vimamsa/constants"
require "vimamsa/debug"
require "vimamsa/crash_handler"
require "vimamsa/tests"
require "vimamsa/test_framework"
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


end # module Vimamsa
