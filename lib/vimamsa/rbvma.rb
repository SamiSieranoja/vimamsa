
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

# cairo (required by gtk4) requires the red-colors gem, which takes 0.5 s to
# load; lazy/colors.rb loads it on first use instead. Without the gem's spec
# (e.g. a bundle that doesn't have it) GTK loads it the normal way.
$vma_red_colors_dir = (Gem::Specification.find_by_name("red-colors").full_gem_path rescue nil)
lazy_dir = File.join(__dir__, "lazy")
$LOAD_PATH.unshift(lazy_dir) if $vma_red_colors_dir
begin
  require "gtk4"
ensure
  $LOAD_PATH.delete(lazy_dir)
end
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
require "vimamsa/line_tree"
# Clipboard must load before main: main.rb runs Editor.new at load time,
# and Editor#initialize creates a Clipboard.
require "vimamsa/registers"
require "vimamsa/dot_repeat"
require "vimamsa/demo_player"
require "vimamsa/demo_recorder"
require "vimamsa/run_ruby"
require "vimamsa/intro_page"
require "vimamsa/cli_help"
require_relative "tmp_user_dir" # also loaded by exe/vimamsa, before the rest
require_relative "user_dirs" # also loaded by exe/vimamsa, before the rest
require_relative "wait_files" # also loaded by exe/vimamsa, before the rest
require_relative "stdin_input" # also loaded by exe/vimamsa, before the rest
require "vimamsa/clipboard"
# exit!
require "vimamsa/main"
require "vimamsa/terminal"

require "vimamsa/key_binding_tree"
require "vimamsa/key_bindings_report"

require "vimamsa/desktop_install"
require "vimamsa/appimage_env"

# Graphical stuff:
require "vimamsa/bundled_fonts"
Vimamsa::BundledFonts.setup!   # install bundled Oxanium before the GUI renders
require "vimamsa/gui"
require "vimamsa/form_input"
require "vimamsa/gui_form_generator"
require "vimamsa/gui_text"
require "vimamsa/gui_menu"
require "vimamsa/gui_dialog"
require "vimamsa/gui_command_line"
require "vimamsa/gui_settings"
require "vimamsa/gui_theme"
require "vimamsa/gui_file_panel"
require "vimamsa/gui_func_panel"
require "vimamsa/gui_key_hint"
require "vimamsa/gui_keylog_panel"
require "vimamsa/gui_select_window"
require "vimamsa/key_names"
require "vimamsa/gui_sourceview"
require "vimamsa/gui_sourceview_autocomplete"
require "vimamsa/gui_image"
require "vimamsa/hyper_plain_text"

require "vimamsa/ack"
require "vimamsa/buffer"
require "vimamsa/buffer_cursor"
require "vimamsa/buffer_changetext"
require "vimamsa/text_objects"
require "vimamsa/vim_operators"
require "vimamsa/key_bindings_vim_core"
require "vimamsa/fold"
# require "vimamsa/buffer_list"
require "vimamsa/buffer_list"
require "vimamsa/buffer_manager"
require "vimamsa/bookmarks"
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
