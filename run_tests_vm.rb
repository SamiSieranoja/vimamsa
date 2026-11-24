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
# Exit codes: the suite's 0 / 1; 2 required variable not set; 4 Guest
# Additions not answering; 5 the guest never reached the test phase; 6 packing
# the working tree failed.
require "tempfile"
require "tmpdir"
require "fileutils"
require_relative "scripts/lib/script_helpers"
include ScriptHelpers

# Tracked docs that tests regenerate in the guest with VMA_UPDATE_DOC=1
GENERATED_DOCS = ["doc/vimlike_vim_conflicts.md",
                  # test_demo_replay.rb
                  *%w[basic easyjump files].map { |n| "tests/demo_records/#{n}.txt" }]

# Left out of the copy sent to the guest (tar --exclude patterns)
TAR_EXCLUDES = %w[
  ./.git/hooks *_vma_autosave .*_vma_autosave *.gem *.o *.so *.tar.xz
  __pycache__ *.log claude-log.* dot_git_old ./build 2del_* bug*.txt *.mp3 *.wav
]

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

# The password goes to VBoxManage in a chmod-600 file, so it isn't visible in
# `ps` (the guest script gets it as SUDO_PASS through --putenv, as before).
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

  # 2. Tarball the working tree (with .git, for `gem build`; without heavy
  # junk). tar exits with 1 for "file changed as we read it" (e.g. .git
  # churning during the read): only a fatal error (2 and up) aborts.
  step "Packing working tree"
  system("tar", "czf", tarball.path, "-C", repo, "--warning=no-file-changed",
         *TAR_EXCLUDES.map { |e| "--exclude=#{e}" }, ".")
  fail!("tar failed (exit #{$?.exitstatus})", 6) if $?.exitstatus.to_i > 1

  # 3. Copy the tarball and the guest runner into the VM (copyto overwrites).
  step "Copying source + runner into guest"
  run!(*gc, "copyto", *cred, tarball.path, "#{guest_home}/vimamsa_src.tgz", label: "VBoxManage copyto")
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
    "SUDO_PASS" => ENV["VM_PASS"], "VMA_DISPLAY" => display, "VMA_TEST_ARGS" => ARGV.join(" "),
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
