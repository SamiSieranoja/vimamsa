require "tmpdir"
require "fileutils"

module Vimamsa
# vimamsa --tmp-user-dir: a new, empty config/data dir in the system temp
# dir, deleted when the editor quits (exe/vimamsa). An editor restart
# (restart_editor) keeps it: the new process gets it in ENV_KEY and deletes
# it in its turn. Only dirs made here are ever deleted (ours?).
module TmpUserDir
  PREFIX = "vimamsa-user-"
  ENV_KEY = "VIMAMSA_TMP_USER_DIR"

  module_function

  def create
    Dir.mktmpdir(PREFIX)
  end

  # Made by create: directly in the system temp dir, named PREFIX...
  def ours?(dir)
    return false if dir.nil? || dir.to_s.empty?
    d = File.expand_path(dir)
    File.dirname(d) == File.expand_path(Dir.tmpdir) && File.basename(d).start_with?(PREFIX)
  end

  # Deletes dir, unless it holds a crash report (crash_handler.rb writes
  # them into the user dir): then it stays, and is named on stderr
  def delete(dir)
    return false if !ours?(dir) || !File.directory?(dir)
    reports = Dir[File.join(dir, "crash", "crash_*")]
    if reports.any?
      warn "vimamsa: kept the temporary user dir #{dir}: it has a crash report (#{File.basename(reports.max)})"
      return false
    end
    FileUtils.rm_rf(dir)
    true
  end
end
end
