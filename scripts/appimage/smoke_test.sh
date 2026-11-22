#!/bin/bash
# Run an AppImage on a clean Ubuntu 24.04 (no GTK, no Ruby, no typelibs) in
# Docker, with only the libraries any desktop provides (the ones the bundle
# leaves to the host), and run a few test files with it.
#   scripts/appimage/smoke_test.sh build/appimage/Vimamsa-0.1.27-x86_64.AppImage
set -euo pipefail
APPIMAGE="$(realpath "$1")"
REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
TESTS="${SMOKE_TESTS:-tests/test_basic_editing.rb tests/test_bundling.rb}"

docker run --rm -v "$APPIMAGE:/app/Vimamsa.AppImage:ro" -v "$REPO/tests:/src/tests:ro" \
  -v "$REPO/exe:/src/exe:ro" -v "$REPO/lib:/src/lib:ro" -e TESTS="$TESTS" ubuntu:24.04 bash -c '
set -e
apt-get update -qq >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
  xvfb xauth fonts-dejavu-core libfontconfig1 libfreetype6 libharfbuzz0b libgl1 libegl1 \
  libgles2 libx11-6 libx11-xcb1 libxcb1 libwayland-client0 libwayland-cursor0 \
  libwayland-egl1 libasound2t64 libpulse0 >/dev/null
if ls /usr/lib/x86_64-linux-gnu/libgtk-4* >/dev/null 2>&1 || command -v ruby >/dev/null; then
  echo "!! test box is not clean (GTK or Ruby installed)"; exit 1
fi
cd /tmp && cp /app/Vimamsa.AppImage . && ./Vimamsa.AppImage --appimage-extract >/dev/null
files=$(for t in $TESTS; do echo /src/$t; done)
timeout 600 xvfb-run -a ./squashfs-root/AppRun --user-dir /tmp/ud --test $files > run.log 2>&1 || true
grep -E "^  (FAIL|ERROR|SKIP)|Results" run.log || { tail -30 run.log; exit 1; }
grep -qE "Results: [0-9]+ passed, 0 failed" run.log
'
