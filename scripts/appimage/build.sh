#!/bin/bash
# Build the Vimamsa AppImage in an Ubuntu 24.04 container (needs Docker).
#   scripts/appimage/build.sh            # builds HEAD
#   VMA_REF=v0.1.26 scripts/appimage/build.sh
#   VMA_REF=WORKTREE scripts/appimage/build.sh   # include uncommitted changes
# Output: build/appimage/Vimamsa-<version>-x86_64.AppImage. The Ruby build and
# appimagetool are cached in build/appimage/cache. See doc/bundling_plan.md.
#
# Optional, not the default: --gtk-new (or VMA_APPIMAGE_VARIANT=gtk-new) builds
# on Ubuntu 22.04 with GTK 4.24 from source (Dockerfile.gtk-new; the bundle needs
# glibc >= 2.35). Output and cache in build/appimage-gtk-new/ (a Ruby cached by
# the default build needs glibc 2.39). See doc/appimage_old_base_plan.md.
set -euo pipefail
VARIANT="${VMA_APPIMAGE_VARIANT:-}"
for a in "$@"; do
  case "$a" in
    --gtk-new) VARIANT=gtk-new ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
if [ "$VARIANT" = gtk-new ]; then
  OUT="$REPO/build/appimage-gtk-new"
  IMAGE=vimamsa-appimage-build-gtk-new
  DOCKERFILE="$REPO/scripts/appimage/Dockerfile.gtk-new"
elif [ -z "$VARIANT" ]; then
  OUT="$REPO/build/appimage"
  IMAGE=vimamsa-appimage-build
  DOCKERFILE="$REPO/scripts/appimage/Dockerfile"
else
  echo "unknown VMA_APPIMAGE_VARIANT: $VARIANT" >&2; exit 2
fi
mkdir -p "$OUT"
docker build -q -t "$IMAGE" -f "$DOCKERFILE" "$REPO/scripts/appimage" >/dev/null
docker run --rm \
  -v "$REPO:/src:ro" -v "$OUT:/build" \
  -e VMA_REF="${VMA_REF:-HEAD}" -e RUBY_VERSION="${RUBY_VERSION:-3.4.9}" \
  "$IMAGE" bash /src/scripts/appimage/build_in_container.sh
# Files written in the container belong to root
docker run --rm -v "$OUT:/build" "$IMAGE" chown -R "$(id -u):$(id -g)" /build
