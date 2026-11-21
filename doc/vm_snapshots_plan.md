# Plan: resettable test VM ("blank" the VM to simulate a fresh install)

## Context

`run_tests_vm.rb` (host) + `vm_guest_run.sh` (guest) run the suite in the test
VirtualBox VM named by `$VM_NAME`. The VM isn't blank any more:
- Provisioning runs once and is then skipped forever because of the marker
  `~/.vimamsa_vm_provisioned`.
- Every run leaves state behind: gems, `~/.config/vimamsa-test`, apt updates and
  whatever earlier runs installed.

So "does it install and run on a fresh Ubuntu?" isn't being tested any more. It will
matter more for the AppImage (`doc/bundling_plan.md`), which has to run on a machine
with *no* `-dev` packages, Ruby or gems at all.

Current state (checked 2026-11-19):
- VirtualBox 7.0
- the test VM has one disk and **no snapshots**

## Approach: VirtualBox snapshots

A snapshot freezes the disk (and, if it's taken while the VM is running, its RAM). Later
writes go to a differencing image. Restoring a snapshot throws all changes away in
seconds.

Two snapshots:

| Snapshot | Contents | Used for |
|---|---|---|
| `clean` | fresh Ubuntu 24.04 desktop install + Guest Additions + the test user (`$VM_USER`) logged in on `$VM_DISPLAY`. **No** build tools, Ruby gems or GTK `-dev` packages. | "blank" runs: the full install path from scratch (`gem install`), and later the AppImage on a clean system |
| `provisioned` | `clean` + `vm_guest_run.sh` provisioning (apt `-dev` packages, gems) | normal test runs: fast, and every run starts from the same known state instead of piling up leftovers |

Take both **while the VM is running with the desktop logged in** (`--live`). Restoring
then resumes straight into the logged-in session on `:0`, which `guestcontrol` and the
GUI tests need. No autologin or boot wait is needed. Guest Additions resync the guest
clock after resume.

### Commands (VBoxManage 7.0)

```sh
# take (VM running, desktop logged in)
VBoxManage snapshot "$VM_NAME" take clean --live --description "Ubuntu 24.04 + GA, no vimamsa deps"
# restore (VM must be powered off first)
VBoxManage controlvm "$VM_NAME" poweroff
VBoxManage snapshot "$VM_NAME" restore clean        # or: restore provisioned
VBoxManage startvm "$VM_NAME" --type gui            # resumes the saved session
# replace an outdated snapshot
VBoxManage snapshot "$VM_NAME" delete provisioned
VBoxManage snapshot "$VM_NAME" take provisioned --live
```

## Creating the `clean` baseline (one-time, manual)

The current test VM is already provisioned, so it can't become `clean`. Removing
`-dev` packages and gems by hand would never be truly clean. Instead:

1. Snapshot the **current** state as `provisioned` right away. This is a quick win:
   normal runs become reproducible today.
2. Create a fresh VM for the clean baseline. Either:
   - `VBoxManage unattended install <vm> --iso=ubuntu-24.04.x-desktop-amd64.iso --user="$VM_USER" --password-file=… --install-additions --start-vm=gui`
     Check that VirtualBox 7.0's unattended install handles the 24.04 desktop ISO
     (its subiquity installer). If not, install by hand.
   - or install by hand from the ISO: user `$VM_USER`, Guest Additions, autologin on.

   Then make sure `VBoxManage guestcontrol … run /bin/true` works, and take `clean`
   (`--live`).
3. Run `FORCE_PROVISION=1 ./run_tests_vm.rb` against it. If it passes, take
   `provisioned` on the new VM. Then retire the old VM, or point `VM_NAME` (set in the
   user's shell profile) at the new one.

Record the ISO version (e.g. 24.04.3) in the snapshot description.

## Script changes

`run_tests_vm.rb` gets a reset step before "Ensure the VM is running":

- `VM_RESET=provisioned` (**new default**): power off, restore `provisioned`, start.
  Each run starts identical, so no leftovers between runs. This costs about 10–30 s
  for poweroff, restore and resume.
- `VM_RESET=clean` (or a `--fresh` flag): restore `clean`. `vm_guest_run.sh` then
  provisions from zero. This is the "fresh install" simulation. **If the suite
  passes, retake `provisioned` from the result** (delete the old one, take the new
  one). That way dependency changes in `vm_guest_run.sh` or the gemspec carry into
  normal runs without manual steps.
- `VM_RESET=none`: the current behavior (keep state). Useful for debugging a failure
  inside the VM.
- If the snapshot doesn't exist, fall back to `none` with a warning, so the script
  keeps working on a VM without snapshots.
- The `~/.vimamsa_vm_provisioned` marker and `FORCE_PROVISION` stay: `clean` has no
  marker, so it provisions. `provisioned` has it, so it skips.

### "Occasionally": when a fresh run happens

Automatically, in `run_tests_vm.rb`, so nobody has to remember:
- the host keeps a state file (e.g. `~/.local/share/vimamsa/vm_fresh_state`, in line
  with the XDG item in `doc/TODO.md`) with the date of the last *passing* fresh run
  and a hash of the install inputs: `vimamsa.gemspec`, `Gemfile`/`Gemfile.lock`,
  `vm_guest_run.sh`, `ext/vmaext/extconf.rb`
- a run becomes a fresh run (`VM_RESET=clean`) when:
  - the hash changed (new dependency or provisioning step), **or**
  - the last fresh run is older than **7 days**, **or**
  - it's explicitly asked for (`--fresh` / `VM_RESET=clean`)
- it prints which mode it chose and why, e.g.
  `>> Fresh-install run: vimamsa.gemspec changed since last fresh run`
- `VM_RESET=provisioned` explicitly skips the automatic choice for a quick run.

Fresh runs are slow: apt plus compiling the Ruby-GNOME gems takes several minutes.
That's why they're occasional rather than every run.

### Keeping `clean` from going stale

`clean` is frozen at its install date. That's realistic: users install from an ISO
and then update. But apt update downloads grow over time. Every few months (or
with a new Ubuntu point release), rebuild `clean` from a newer ISO, or restore it, run
`apt full-upgrade`, and retake it. Note the date in the snapshot description.

## AppImage testing (later)

Once the AppImage exists, add `VM_RESET=clean` runs that **don't provision**. They
copy in only the AppImage and run the smoke test (`doc/bundling_plan.md`, "Testing the
bundle"). This is the real check that nothing is missing from the bundle, because
`clean` has no GTK `-dev` packages or Ruby. Other distros (Fedora, KDE) would be more
VMs with the same `clean` snapshot scheme.

## Disk and safety

- Snapshots grow as differencing images. Expect a few GB for `provisioned` and a few
  more per run until the next restore. Restoring throws the run's growth away, so
  steady-state use stays at about `clean` + `provisioned`. Check that the VM
  folder's disk has room for that.
- Snapshot *restore* destroys the VM's current state. That's intended for a
  test-only VM, but the script should only reset VMs that have a `clean` or
  `provisioned` snapshot. Never reset a VM that has none, so pointing `VM_NAME` at
  the wrong VM (some other VirtualBox VM) can't wipe it.
- The guest password stays out of the repo, as now (`VM_PASS` + chmod-600 password
  file).

## Order

1. Take `provisioned` of the current VM now. Add `VM_RESET` with the `provisioned` /
   `none` modes.
2. Build a fresh 24.04 VM and take `clean`. Add the `clean` mode, plus retaking
   `provisioned` after a passing fresh run.
3. Automatic fresh-run trigger (hash + 7 days) with the state file.
4. Update the VM section of CLAUDE.md.
5. Later: AppImage-only runs on `clean`, and more distro VMs.
