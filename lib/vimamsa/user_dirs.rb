require "fileutils"

module Vimamsa
# Where vimamsa keeps its files:
#   config dir  files the user edits: settings.rb, custom.rb, styles/,
#               bookmarks, named macros. $XDG_CONFIG_HOME/vimamsa, by
#               default ~/.config/vimamsa (vma_user_dir, get_dot_path).
#   data dir    files the program generates: session, buffer list, histories,
#               file index, recorded macros, backups, crash reports, the
#               listen dir. $XDG_DATA_HOME/vimamsa, by default
#               ~/.local/share/vimamsa (vma_data_dir, get_data_path).
# With --user-dir DIR (and in tests, and with --tmp-user-dir) both are DIR, so
# those runs touch nothing else. Loaded by exe/vimamsa before the rest, as its
# check for a running editor uses the listen dir.
module UserDirs
  # Files and dirs that moved from the config dir to the data dir, by name
  MOVED_TO_DATA = %w[
    session.txt buffers.txt cmd_history.txt dictation_prompts.json
    file_history file_index file_panel_shown macros backup crash
  ]

  module_function

  def default_config_dir
    base = ENV["XDG_CONFIG_HOME"].to_s
    base = File.expand_path("~/.config") if base.empty?
    File.join(File.expand_path(base), "vimamsa")
  end

  def default_data_dir
    base = ENV["XDG_DATA_HOME"].to_s
    base = File.expand_path("~/.local/share") if base.empty?
    File.join(File.expand_path(base), "vimamsa")
  end

  # The default config dir, or one given by --user-dir?
  def default_config_dir?(dir)
    File.expand_path(dir) == default_config_dir
  end

  # The data dir that goes with config dir dir
  def data_dir_for(dir)
    default_config_dir?(dir) ? default_data_dir : File.expand_path(dir)
  end

  # One-time move of the files of older versions to their new places, when
  # the new place has nothing yet: the generated files from the config dir to
  # the data dir, and from the even older ~/.vimamsa the command history and
  # backups (its other files are older copies of those in the config dir);
  # macros saved with save_macro from ~/.config/.vimamsa to the config dir.
  # A dir whose new place exists already is merged file by file, a file that
  # is in both places is left where it was. Nothing is deleted, except the
  # old listen dir if empty. Returns [[from, to], ...] of what was moved.
  def migrate(config_dir: default_config_dir, data_dir: default_data_dir,
              legacy_dir: File.expand_path("~/.vimamsa"),
              legacy_macro_dir: File.expand_path("~/.config/.vimamsa"))
    return [] if File.expand_path(config_dir) == File.expand_path(data_dir)
    moved = []
    MOVED_TO_DATA.each { |n| move(File.join(config_dir, n), File.join(data_dir, n), moved) }
    %w[cmd_history.txt backup].each { |n| move(File.join(legacy_dir, n), File.join(data_dir, n), moved) }
    Dir[File.join(legacy_macro_dir, "macro_*.rb")].each { |f| move(f, File.join(config_dir, File.basename(f)), moved) }
    old_listen = File.join(config_dir, "listen")
    Dir.rmdir(old_listen) if File.directory?(old_listen) && Dir.empty?(old_listen)
    moved
  rescue SystemCallError => e
    warn "vimamsa: moving old files to #{data_dir} stopped: #{e.message}"
    moved
  end

  # Moves from to to: a file only if to doesn't exist; a dir whole, or its
  # entries one by one into an existing dir
  def move(from, to, moved)
    return if !File.exist?(from)
    if !File.exist?(to)
      FileUtils.mkdir_p(File.dirname(to))
      FileUtils.mv(from, to)
      moved << [from, to]
    elsif File.directory?(from) && File.directory?(to)
      Dir.children(from).each { |c| move(File.join(from, c), File.join(to, c), moved) }
    end
  end
end
end
