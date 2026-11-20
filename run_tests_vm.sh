#!/usr/bin/env bash
# Run the vimamsa test suite inside the VirtualBox VM named by $VM_NAME, on its real
# logged-in desktop (so the GTK window actually appears in the VM).
#
# Reaches the guest via VBoxManage guestcontrol (Guest Additions) — no SSH or
# shared folder needed. Syncs the current working tree (incl. uncommitted changes),
# provisions the guest on first run, builds the native extension, then runs
# exe/run_tests.rb on DISPLAY :0. Exits with the suite's exit code (0 pass / 1 fail).
#
# Usage (VM_NAME, VM_USER and VM_PASS exported, e.g. in ~/.bashrc):
#   ./run_tests_vm.sh [test filter args...]
# Examples:
#   ./run_tests_vm.sh                         # full suite
#   ./run_tests_vm.sh undo                    # tests/test_undo.rb only
#   FORCE_PROVISION=1 ./run_tests_vm.sh       # re-run apt provisioning
#
# Env:
#   VM_NAME         (required) VirtualBox VM name
#   VM_USER         (required) guest login username
#   VM_PASS         (required) guest login/sudo password for user $VM_USER
#   VM_DISPLAY      guest desktop X display   (default: :0)
#   FORCE_PROVISION set to 1 to force guest re-provisioning
set -euo pipefail

VM_NAME="${VM_NAME:-}"
VM_USER="${VM_USER:-}"
VM_DISPLAY="${VM_DISPLAY:-:0}"
GUEST_HOME="/home/${VM_USER}"

missing=()
[ -n "$VM_NAME" ] || missing+=(VM_NAME)
[ -n "$VM_USER" ] || missing+=(VM_USER)
[ -n "${VM_PASS:-}" ] || missing+=(VM_PASS)
if [ ${#missing[@]} -gt 0 ]; then
  echo "!! Not set: ${missing[*]}. Export VM_NAME (VirtualBox VM), VM_USER (guest user)" >&2
  echo "   and VM_PASS (guest password), e.g. in ~/.bashrc." >&2
  exit 2
fi

REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

# Temp files: a chmod-600 passwordfile (so the password isn't visible in `ps`)
# and the source tarball. Both are removed on exit.
PF="$(mktemp)"
TAR="$(mktemp --suffix=.tgz)"
chmod 600 "$PF"
printf '%s' "$VM_PASS" > "$PF"
cleanup() { rm -f "$PF" "$TAR"; }
trap cleanup EXIT

# In VBoxManage 7.x the credentials/options belong to the run/copyto subcommand
# (after it), and use `--opt=value` syntax.
GC=(VBoxManage guestcontrol "$VM_NAME")
CRED=(--username="$VM_USER" --passwordfile="$PF")

# 1. Ensure the VM is running and Guest Additions answer.
if ! VBoxManage list runningvms | grep -q "\"$VM_NAME\""; then
  echo ">> Starting VM $VM_NAME"
  VBoxManage startvm "$VM_NAME" --type gui
fi
echo ">> Waiting for Guest Additions in $VM_NAME"
for i in $(seq 1 60); do
  if "${GC[@]}" run "${CRED[@]}" --exe=/bin/true -- true >/dev/null 2>&1; then break; fi
  if [ "$i" = 60 ]; then
    echo "!! Guest Additions not responding after 60s. Is the guest booted and logged in?" >&2
    exit 4
  fi
  sleep 2
done

# 2. Tarball the working tree (include .git for `gem build`; drop heavy junk).
#    tolerate exit 1 ("file changed as we read it" — e.g. .git churning during the
#    read); only a fatal tar error (>=2) should abort.
echo ">> Packing working tree"
set +e
tar czf "$TAR" -C "$REPO" \
  --warning=no-file-changed \
  --exclude='./.git/hooks' \
  --exclude='*_vma_autosave' \
  --exclude='.*_vma_autosave' \
  --exclude='*.gem' \
  --exclude='*.o' \
  --exclude='*.so' \
  --exclude='*.tar.xz' \
  --exclude='__pycache__' \
  --exclude='*.log' \
  --exclude='claude-log.*' \
  --exclude='dot_git_old' \
  --exclude='./build' \
  --exclude='2del_*' \
  --exclude='bug*.txt' \
  --exclude='*.mp3' --exclude='*.wav' \
  .
trc=$?
set -e
if [ "$trc" -gt 1 ]; then
  echo "!! tar failed (exit $trc)" >&2
  exit 6
fi

# 3. Copy the tarball and the guest runner into the VM (copyto overwrites by default).
echo ">> Copying source + runner into guest"
"${GC[@]}" copyto "${CRED[@]}" "$TAR" "${GUEST_HOME}/vimamsa_src.tgz"
"${GC[@]}" copyto "${CRED[@]}" "${REPO}/vm_guest_run.sh" "${GUEST_HOME}/vm_guest_run.sh"

# 4. Run the guest script, streaming output (tee'd so we can parse the result).
#    Secrets/env go via --putenv, never onto the repo. NOTE: VBoxManage does not
#    propagate the guest exit code, so pass/fail is taken from the VMA_SUITE_EXIT
#    sentinel the guest prints, not from VBoxManage's own exit status.
echo ">> Running test suite in guest (DISPLAY $VM_DISPLAY)"
OUT="$(mktemp)"
trap 'rm -f "$PF" "$TAR" "$OUT"' EXIT
set +e
"${GC[@]}" run "${CRED[@]}" --exe=/bin/bash --wait-stdout --wait-stderr \
  --putenv="SUDO_PASS=${VM_PASS}" \
  --putenv="VMA_DISPLAY=${VM_DISPLAY}" \
  --putenv="VMA_TEST_ARGS=$*" \
  --putenv="FORCE_PROVISION=${FORCE_PROVISION:-}" \
  --putenv="VMA_E2E_INTERACTIVE=${VMA_E2E_INTERACTIVE:-}" \
  --putenv="VMA_UPDATE_DOC=${VMA_UPDATE_DOC:-}" \
  -- "${GUEST_HOME}/vm_guest_run.sh" 2>&1 | tee "$OUT"
set -e

sentinel="$(grep -oE 'VMA_SUITE_EXIT=[0-9]+' "$OUT" | tail -1 | cut -d= -f2)"
if [ -z "$sentinel" ]; then
  echo "!! Did not receive a VMA_SUITE_EXIT sentinel from the guest — the run did not" >&2
  echo "   reach the test phase (provisioning/build failure above)." >&2
  exit 5
fi
echo ">> Suite exit code (from guest): $sentinel"

# VMA_UPDATE_DOC=1: tests that generate a tracked doc (test_vim_conflicts)
# wrote it in the guest; copy it back into this working tree.
if [ "${VMA_UPDATE_DOC:-}" = "1" ]; then
  for f in doc/vimlike_vim_conflicts.md; do
    echo ">> Copying regenerated $f from guest"
    "${GC[@]}" copyfrom "${CRED[@]}" --target-directory="${REPO}/doc/" "${GUEST_HOME}/vimamsa/$f" ||
      echo "!! could not copy $f back" >&2
  done
fi
exit "$sentinel"
