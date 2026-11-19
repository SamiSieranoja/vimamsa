#!/bin/bash
# Build the Vimamsa AppImage in an Ubuntu 24.04 container (needs Docker).
#   scripts/appimage/build.sh            # builds HEAD
#   VMA_REF=v0.1.26 scripts/appimage/build.sh
#   VMA_REF=WORKTREE scripts/appimage/build.sh   # include uncommitted changes
# Output: build/appimage/Vimamsa-<version>-x86_64.AppImage. The Ruby build and
# appimagetool are cached in build/appimage/cache. See doc/bundling_plan.md.
set -euo pipefail
REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
OUT="$REPO/build/appimage"
IMAGE=vimamsa-appimage-build
mkdir -p "$OUT"
docker build -q -t "$IMAGE" "$REPO/scripts/appimage" >/dev/null
docker run --rm \
  -v "$REPO:/src:ro" -v "$OUT:/build" \
  -e VMA_REF="${VMA_REF:-HEAD}" -e RUBY_VERSION="${RUBY_VERSION:-3.4.9}" \
  "$IMAGE" bash /src/scripts/appimage/build_in_container.sh
# Files written in the container belong to root
docker run --rm -v "$OUT:/build" "$IMAGE" chown -R "$(id -u):$(id -g)" /build
