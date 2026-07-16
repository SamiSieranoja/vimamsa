#!/usr/bin/env bash
# Runs INSIDE the ub_blank VM guest (copied in and executed by run_tests_vm.sh via
# VBoxManage guestcontrol). Unpacks the synced working tree, provisions the box the
# first time, builds the native extension, then runs the test suite on the real
# desktop (DISPLAY :0) so the GTK window actually appears in the VM.
#
# Env (passed via `guestcontrol run --putenv`):
#   SUDO_PASS       guest sudo password (used with `sudo -S`; never written to disk)
#   VMA_DISPLAY     X display of the logged-in desktop session (default :0)
#   VMA_TEST_ARGS   optional args forwarded to exe/run_tests.rb (test filters)
#   FORCE_PROVISION set to 1 to re-run apt/gem provisioning even if the marker exists
set -euo pipefail

SRC_TGZ="$HOME/vimamsa_src.tgz"
DEST="$HOME/vimamsa"
MARKER="$HOME/.vimamsa_vm_provisioned"

sudo_do() { echo "${SUDO_PASS:-}" | sudo -S -p '' "$@"; }

# 1. Unpack the synced working tree fresh each run.
echo ">> Unpacking source into $DEST"
rm -rf "$DEST"
mkdir -p "$DEST"
tar xzf "$SRC_TGZ" -C "$DEST"
cd "$DEST"

# 2. Provision (idempotent). apt + bundler only on the first run (or when forced).
if [ ! -f "$MARKER" ] || [ "${FORCE_PROVISION:-}" = "1" ]; then
  echo ">> Provisioning guest (apt packages + bundler) — this is slow the first time"
  export DEBIAN_FRONTEND=noninteractive
  sudo_do apt-get update
  sudo_do apt-get install -y \
    ruby ruby-dev build-essential git pkg-config \
    libgtk-4-dev libgtksourceview-5-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libvte-2.91-gtk4-dev libssl-dev \
    ack clang-format x11-xserver-utils
  sudo_do gem install bundler -v '~> 2.4'
else
  echo ">> Guest already provisioned (marker $MARKER present) — skipping apt"
fi

# Enable the uinput virtual keyboard so the E2E tests can type real key events.
# Do this every run (the module load / device perms don't survive a reboot).
sudo_do modprobe uinput 2>/dev/null || true
sudo_do chmod 0666 /dev/uinput 2>/dev/null || true

# 3. Build + install the gem. Compiles ext/vmaext and (first run) installs the
#    ruby-gnome gems and the external StrIdx C++ gem. Copy the built .so back into
#    the tree so `require "vmaext"` resolves when running from source.
echo ">> Building and installing the vimamsa gem"
rm -f vimamsa-0.1.*.gem
gem build vimamsa.gemspec
# NB: no --local — installing the local .gem must be allowed to fetch its runtime
# deps (gtk4, gtksourceview5, StrIdx, language_server-protocol, …) from rubygems.org.
sudo_do gem install vimamsa-0.1.*.gem
# A system `gem install` compiles the extension under Gem.dir/extensions/<platform>/
# <abi>/vimamsa-<ver>/vmaext.so (not under gems/.../ext), so locate it with find.
GEM_DIR="$(ruby -e 'puts Gem.dir')"
so_path="$(find "$GEM_DIR" -name vmaext.so -path '*vimamsa*' 2>/dev/null | head -1)"
[ -z "$so_path" ] && so_path="$(find "$GEM_DIR" -name vmaext.so 2>/dev/null | head -1)"
if [ -z "$so_path" ]; then
  echo "!! Could not locate compiled vmaext.so under $GEM_DIR" >&2
  exit 2
fi
cp "$so_path" lib/
touch "$MARKER"

# 4. Run the suite on the real desktop (no --headless: the window shows on-screen).
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
# Prefer the real Wayland seat: the uinput E2E tests only run on the GTK Wayland
# backend. Keep DISPLAY + XAUTHORITY set too so xmodmap (an X tool, via Xwayland)
# can still read the keymap.
if [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
  export GDK_BACKEND=wayland
  export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
fi
export DISPLAY="${VMA_DISPLAY:-:0}"
if [ -z "${XAUTHORITY:-}" ]; then
  for f in "$HOME/.Xauthority" \
           "/run/user/$(id -u)/gdm/Xauthority" \
           /run/user/"$(id -u)"/.mutter-Xwaylandauth.*; do
    if [ -f "$f" ]; then export XAUTHORITY="$f"; break; fi
  done
fi
echo ">> Running tests on GDK_BACKEND=${GDK_BACKEND:-x11} DISPLAY=$DISPLAY (XAUTHORITY=${XAUTHORITY:-unset})"
# VBoxManage `guestcontrol run` does NOT propagate the guest process's exit code to
# the host, so emit an unambiguous sentinel the host parses for pass/fail.
set +e
# shellcheck disable=SC2086  # word-splitting of VMA_TEST_ARGS is intentional
ruby exe/run_tests.rb ${VMA_TEST_ARGS:-}
suite_rc=$?
set -e
echo "VMA_SUITE_EXIT=${suite_rc}"
exit "$suite_rc"
