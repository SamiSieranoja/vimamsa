# Packs the working tree's source into a tarball for a test machine (the VM,
# run_tests_vm.rb; containers, run_tests_docker.rb): the tracked files, new
# files under the source dirs, and a shallow packed clone as .git.
# Standard library only.
require "open3"
require "fileutils"
require "tmpdir"
require "shellwords"
require_relative "script_helpers"

module SourcePack
  extend ScriptHelpers

  # The tracked files, plus untracked (not ignored) files under these dirs,
  # e.g. a new test or lib file. The rest of the working tree's untracked
  # files (scratch files, perf data, AppImages) stay out.
  SOURCE_DIRS = %w[lib exe ext tests modules lang styles help scripts doc]
  # Top-level dirs left out even when tracked (img: gem build needs every
  # tracked file, so none for now)
  SKIP_DIRS = %w[]
  # History in the copy's .git (perf_startup ref=HEAD~N needs N < this)
  CLONE_DEPTH = 50
  # Left out even when tracked or under SOURCE_DIRS (File.fnmatch on the
  # basename)
  COPY_EXCLUDES = %w[
    *_vma_autosave .*_vma_autosave *.gem *.o *.so *.tar.xz *.log claude-log.*
    bug*.txt *.mp3 *.wav *.bak
  ]
  # Untracked files bigger than this are left out (with a note)
  MAX_UNTRACKED_BYTES = 2_000_000

  module_function

  # Paths (relative to repo) to send
  def files(repo)
    git = ->(*a) { Open3.capture2("git", "-C", repo, *a).first.split("\0") }
    tracked = git.("ls-files", "-z", "--cached")
    untracked = git.("ls-files", "-z", "--others", "--exclude-standard")
      .select { |f| SOURCE_DIRS.include?(f.split("/").first) }
    skipped = []
    untracked.reject! { |f|
      big = File.size?(File.join(repo, f)).to_i > MAX_UNTRACKED_BYTES
      skipped << f if big
      big
    }
    warn "   (left out, untracked and over #{MAX_UNTRACKED_BYTES / 1_000_000} MB: #{skipped.join(", ")})" if skipped.any?
    (tracked + untracked).uniq.select { |f|
      b = File.basename(f)
      File.file?(File.join(repo, f)) && !SKIP_DIRS.include?(f.split("/").first) &&
        COPY_EXCLUDES.none? { |pat| File.fnmatch(pat, b) }
    }
  end

  # Write the tarball (gzip) of repo's source to out. The .git is a fresh
  # clone of the last CLONE_DEPTH commits (packed; the repo's own .git can
  # hold tens of MB of loose objects) with the working tree's index, for
  # `gem build` (git ls-files) and the tests that use history. tar exits
  # with 1 for "file changed as we read it": only 2 and up is an error.
  def pack(repo, out)
    Dir.mktmpdir("vma_pack") { |tmp|
      list = File.join(tmp, "files")
      File.write(list, files(repo).join("\0"))
      clone = File.join(tmp, "clone")
      run!("git", "clone", "--quiet", "--no-checkout", "--depth=#{CLONE_DEPTH}", "file://#{repo}", clone,
           label: "git clone")
      FileUtils.cp(File.join(repo, ".git", "index"), File.join(clone, ".git", "index"))
      tar = File.join(tmp, "src.tar")
      system("tar", "cf", tar, "-C", repo, "--warning=no-file-changed", "--null", "-T", list)
      fail!("tar failed (exit #{$?.exitstatus})", 6) if $?.exitstatus.to_i > 1
      system("tar", "rf", tar, "-C", clone, ".git")
      fail!("tar failed (exit #{$?.exitstatus})", 6) if $?.exitstatus.to_i > 1
      system("gzip -1 -c #{tar.shellescape} > #{out.shellescape}")
      fail!("gzip failed", 6) if !$?.success?
    }
  end
end
