module Vimamsa
# vimamsa --help (exe/vimamsa): the command line options, then the actions.
# The usage text needs nothing else, so it is printed before the rest of the
# code loads; the actions are registered the way Editor#start does it, without
# starting the GUI.

CLI_USAGE = <<~TXT
  Usage: vimamsa [options] [file | dir ...]

  Opens the files in the editor window (if an editor is already running, the
  file is opened there). A directory is added to the file and content search
  paths.

  Options:
    --user-dir DIR   config and data dir instead of ~/.config/vimamsa
                     (also --user-dir=DIR)
    --intro          show the introduction page (Help ▸ Introduction) at start
    -h, --help       this help, and the list of actions
TXT

def self.print_cli_usage(io = $stdout)
  io.puts CLI_USAGE
  io.flush
end

# Registers the built-in actions without starting the editor, as Editor#start
# does: key_actions.rb, the default keymap (vimlike), the text converters and
# the minor modes (buffer manager, bookmarks, grep, file explorer, file
# history). Modules register more when they are enabled.
def self.cli_load_actions
  ed = vma
  $hook = Hook.new
  ed.instance_variable_set(:@hook, $hook)
  require "vimamsa/actions"
  ed.instance_variable_set(:@actions, ActionList.new)
  require "vimamsa/key_actions"
  ed.kbd = KeyBindingTree.new(actions: ed.actions)
  require "vimamsa/key_bindings_vimlike"
  require "vimamsa/text_transforms"
  BufferManager.init
  Bookmarks.init
  Grep.init
  FileManager.init
  require "vimamsa/file_history"
  FileHistory.new # registers file.history.prune; only reads the history
  ed.actions
end

# "  id  description" lines, sorted by id
def self.cli_action_lines(actions)
  ids = actions.dotted_ids.map(&:to_s).sort
  w = ids.map(&:size).max.to_i
  ids.map { |id|
    a = actions[id]
    desc = a.respond_to?(:method_name) ? a.method_name.to_s : ""
    desc = "" if desc == id
    "  #{id.ljust(w)}  #{desc}".rstrip
  }
end

def self.print_cli_actions(io = $stdout)
  actions = cli_load_actions
  io.puts
  io.puts "Actions (#{actions.dotted_ids.size}). Bind one to keys in custom.rb with"
  io.puts "bindkey \"C , x\", \"<action>\", or run it on the command line (:) as"
  io.puts "a.<action>!, e.g. a.buf.save!  Enabled modules add more."
  io.puts
  io.puts cli_action_lines(actions)
  io.flush
end
end # module Vimamsa
