#!/usr/bin/env ruby
# Run the vimamsa test suite inside the VirtualBox VM named by $VM_NAME, on its
# real logged-in desktop (so the GTK window actually appears in the VM).
#
# Reaches the guest via VBoxManage guestcontrol (Guest Additions): no SSH or
# shared folder needed. Syncs the current working tree (incl. uncommitted
# changes), provisions the guest on first run, builds the native extension,
# then runs exe/run_tests.rb on DISPLAY :0 (vm_guest_run.sh, in the guest).
# Exits with the suite's exit code (0 pass / 1 fail).
#
# Usage (VM_NAME, VM_USER and VM_PASS exported, e.g. in ~/.bashrc):
#   ./run_tests_vm.rb [test filter args...]
# Examples:
#   ./run_tests_vm.rb                         # full suite
#   ./run_tests_vm.rb undo                    # tests/test_undo.rb only
#   FORCE_PROVISION=1 ./run_tests_vm.rb       # re-run apt provisioning
#   ./run_tests_vm.rb --appimage build/appimage/Vimamsa-0.1.28-x86_64.AppImage [filter]
#                                             # test that AppImage (its own code)
#   ./run_tests_vm.rb --appimage-dev FILE.AppImage [filter]
#                                             # this tree's code on its runtime
#   VMA_UPDATE_DOC=1 ./run_tests_vm.rb vim_conflicts  # also copy back generated docs
#
# Env:
#   VM_NAME         (required) VirtualBox VM name
#   VM_USER         (required) guest login username
#   VM_PASS         (required) guest login/sudo password for user $VM_USER
#   VM_DISPLAY      guest desktop X display   (default: :0)
#   FORCE_PROVISION set to 1 to force guest re-provisioning
#   VMA_UPDATE_DOC  set to 1 to copy regenerated docs back (GENERATED_DOCS)
#   VMA_E2E_INTERACTIVE  passed on to the guest (run_e2e_vm.sh sets it)
#
# One run at a time per VM: a second run waits for the first (they would share
# the guest's source dir and desktop and break each other).
#
# Exit codes: the suite's 0 / 1; 2 required variable not set; 4 Guest
# Additions not answering; 5 the guest never reached the test phase; 6 packing
# the working tree failed.
require "tempfile"
require "tmpdir"
require "fileutils"
require "shellwords"
require_relative "scripts/lib/script_helpers"
include ScriptHelpers

# Tracked docs that tests regenerate in the guest with VMA_UPDATE_DOC=1
GENERATED_DOCS = ["doc/vimlike_vim_conflicts.md",
                  # test_demo_replay.rb
                  *%w[basic easyjump files].map { |n| "tests/demo_records/#{n}.txt" }]

# What is sent to the guest: the tracked files, plus untracked (not ignored)
# files under these dirs, e.g. a new test or lib file. The rest of the working
# tree's untracked files (scratch files, perf data, AppImages) stay out.
SOURCE_DIRS = %w[lib exe ext tests modules lang styles help scripts doc]
# Top-level dirs left out even when tracked: nothing in the tests reads them
# (the README's media)
SKIP_DIRS = %w[]  # (img: gem build needs every tracked file)
# History in the guest's .git (perf_startup ref=HEAD~N needs N < this)
CLONE_DEPTH = 50
# Left out even when tracked or under SOURCE_DIRS (File.fnmatch on the
# basename)
COPY_EXCLUDES = %w[
  *_vma_autosave .*_vma_autosave *.gem *.o *.so *.tar.xz *.log claude-log.*
  bug*.txt *.mp3 *.wav *.bak
]
# Untracked files bigger than this are left out (with a note)
MAX_UNTRACKED_BYTES = 2_000_000

# Paths (relative to repo) to send to the guest
def files_to_copy(repo)
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

# --appimage FILE / --appimage-dev FILE: test an AppImage instead of a build of
# this tree. The tests are this tree's; with --appimage-dev the code is too,
# run on the AppImage's Ruby, gems and libraries. The rest of ARGV goes to
# exe/run_tests.rb as before (filters, --headless).
appimage = nil
appimage_dev = false
%w[--appimage --appimage-dev].each { |opt|
  next if (i = ARGV.index(opt)).nil?
  appimage = ARGV[i + 1]
  appimage_dev = opt == "--appimage-dev"
  fail!("#{opt} needs an AppImage file", 2) if appimage.nil? || !File.file?(appimage)
  appimage = File.expand_path(appimage)
  ARGV.slice!(i, 2)
}

missing = missing_env("VM_NAME", "VM_USER", "VM_PASS")
if missing.any?
  fail!("Not set: #{missing.join(" ")}. Export VM_NAME (VirtualBox VM), VM_USER (guest user)\n" \
        "and VM_PASS (guest password), e.g. in ~/.bashrc.", 2)
end

vm = ENV["VM_NAME"]
user = ENV["VM_USER"]
display = ENV["VM_DISPLAY"].to_s.empty? ? ":0" : ENV["VM_DISPLAY"]
guest_home = "/home/#{user}"
repo, ok = Open3.capture2("git", "-C", __dir__, "rev-parse", "--show-toplevel")
repo = ok.success? ? repo.strip : __dir__

# One run at a time per VM. The lock is released when this process exits.
lock = File.open(File.join(Dir.tmpdir, "vimamsa_vm_#{vm}.lock"), File::RDWR | File::CREAT, 0o600)
if !lock.flock(File::LOCK_EX | File::LOCK_NB)
  other = (File.read(lock.path).strip rescue "")
  step "Waiting for another test run in #{vm} to finish#{other.empty? ? "" : " (#{other})"}"
  lock.flock(File::LOCK_EX)
end
lock.truncate(0)
lock.write("pid #{Process.pid}, #{ARGV.empty? ? "full suite" : ARGV.join(" ")}")
lock.flush

# The password goes to VBoxManage in a chmod-600 file, so it isn't visible in
# `ps`. The guest script gets it the same way (a file it deletes), never on
# a command line.
pwfile = Tempfile.new("vma_vm_pw")
tarball = Tempfile.new(["vimamsa_src", ".tgz"])
begin
  File.chmod(0o600, pwfile.path)
  pwfile.write(ENV["VM_PASS"])
  pwfile.flush

  # In VBoxManage 7.x the credentials/options belong to the run/copyto
  # subcommand (after it), and use --opt=value syntax.
  gc = ["VBoxManage", "guestcontrol", vm]
  cred = ["--username=#{user}", "--passwordfile=#{pwfile.path}"]

  # 1. Ensure the VM is running and Guest Additions answer.
  running, = Open3.capture2("VBoxManage", "list", "runningvms")
  if !running.include?("\"#{vm}\"")
    step "Starting VM #{vm}"
    run!("VBoxManage", "startvm", vm, "--type", "gui", label: "VBoxManage startvm")
  end
  step "Waiting for Guest Additions in #{vm}"
  answered = 60.times.any? { |i|
    sleep 2 if i > 0
    system(*gc, "run", *cred, "--exe=/bin/true", "--", "true", out: File::NULL, err: File::NULL)
  }
  fail!("Guest Additions not responding after 2 min. Is the guest booted and logged in?", 4) if !answered

  # 2. Tarball the working tree's source (files_to_copy) and a .git for
  # `gem build` (git ls-files) and the tests that use history: a fresh clone
  # of the last CLONE_DEPTH commits (packed; the repo's own .git can hold tens
  # of MB of loose objects) with the working tree's index. tar exits with 1 for "file changed
  # as we read it": only a fatal error (2 and up) aborts.
  step "Packing working tree"
  Dir.mktmpdir("vma_vm_pack") { |tmp|
    list = File.join(tmp, "files")
    File.write(list, files_to_copy(repo).join("\0"))
    clone = File.join(tmp, "clone")
    run!("git", "clone", "--quiet", "--no-checkout", "--depth=#{CLONE_DEPTH}", "file://#{repo}", clone,
         label: "git clone")
    FileUtils.cp(File.join(repo, ".git", "index"), File.join(clone, ".git", "index"))
    tar = File.join(tmp, "src.tar")
    system("tar", "cf", tar, "-C", repo, "--warning=no-file-changed", "--null", "-T", list)
    fail!("tar failed (exit #{$?.exitstatus})", 6) if $?.exitstatus.to_i > 1
    system("tar", "rf", tar, "-C", clone, ".git")
    fail!("tar failed (exit #{$?.exitstatus})", 6) if $?.exitstatus.to_i > 1
    system("gzip -1 -c #{tar.shellescape} > #{tarball.path.shellescape}")
    fail!("gzip failed", 6) if !$?.success?
  }
  step "  #{(File.size(tarball.path) / 1e6).round(1)} MB"

  # 3. Copy the tarball and the guest runner into the VM (copyto overwrites).
  step "Copying source + runner into guest"
  run!(*gc, "copyto", *cred, tarball.path, "#{guest_home}/vimamsa_src.tgz", label: "VBoxManage copyto")
  # The sudo password, in a private dir; the guest script reads and deletes it
  # (the guest's mkdir: guestcontrol mkdir --mode doesn't give 0700)
  run!(*gc, "run", *cred, "--exe=/bin/sh", "--", "-c",
       "rm -rf #{guest_home}/.vma_run && mkdir -m 700 #{guest_home}/.vma_run", label: "VBoxManage run mkdir")
  run!(*gc, "copyto", *cred, pwfile.path, "#{guest_home}/.vma_run/sudo_pass", label: "VBoxManage copyto")
  run!(*gc, "copyto", *cred, File.join(repo, "vm_guest_run.sh"), "#{guest_home}/vm_guest_run.sh",
       label: "VBoxManage copyto")
  guest_appimage = "#{guest_home}/vimamsa.AppImage"
  if appimage
    step "Copying #{File.basename(appimage)} into guest#{appimage_dev ? " (this tree's code on its runtime)" : ""}"
    run!(*gc, "copyto", *cred, appimage, guest_appimage, label: "VBoxManage copyto")
  end

  # 4. Run the guest script, streaming its output. VBoxManage doesn't pass on
  # the guest's exit code, so pass/fail comes from the VMA_SUITE_EXIT sentinel
  # the guest prints, not from VBoxManage's own exit status.
  step "Running test suite in guest (DISPLAY #{display})"
  putenv = {
    "SUDO_PASS_FILE" => "#{guest_home}/.vma_run/sudo_pass", "VMA_DISPLAY" => display, "VMA_TEST_ARGS" => ARGV.join(" "),
    "FORCE_PROVISION" => ENV["FORCE_PROVISION"].to_s, "VMA_E2E_INTERACTIVE" => ENV["VMA_E2E_INTERACTIVE"].to_s,
    "VMA_UPDATE_DOC" => ENV["VMA_UPDATE_DOC"].to_s,
    "VMA_APPIMAGE" => appimage ? guest_appimage : "", "VMA_APPIMAGE_DEV" => appimage_dev ? "1" : "",
  }.map { |k, v| "--putenv=#{k}=#{v}" }
  out, = run_streaming(*gc, "run", *cred, "--exe=/bin/bash", "--wait-stdout", "--wait-stderr",
                       *putenv, "--", "#{guest_home}/vm_guest_run.sh")

  sentinel = out.scan(/VMA_SUITE_EXIT=(\d+)/).last&.first
  if sentinel.nil?
    fail!("Did not receive a VMA_SUITE_EXIT sentinel from the guest: the run did not\n" \
          "reach the test phase (provisioning/build failure above).", 5)
  end
  step "Suite exit code (from guest): #{sentinel}"

  # VMA_UPDATE_DOC=1: tests that generate a tracked doc wrote it in the guest;
  # copy it back into this working tree. copyfrom doesn't truncate an existing
  # file, so copy into an empty directory first.
  if ENV["VMA_UPDATE_DOC"] == "1"
    Dir.mktmpdir { |tmp|
      GENERATED_DOCS.each { |f|
        step "Copying regenerated #{f} from guest"
        if system(*gc, "copyfrom", *cred, "--target-directory=#{tmp}/", "#{guest_home}/vimamsa/#{f}")
          FileUtils.mkdir_p(File.dirname(File.join(repo, f)))
          FileUtils.mv(File.join(tmp, File.basename(f)), File.join(repo, f), force: true)
        else
          warn "!! could not copy #{f} back"
        end
      }
    }
  end
  exit sentinel.to_i
ensure
  pwfile.close!
  tarball.close!
end
