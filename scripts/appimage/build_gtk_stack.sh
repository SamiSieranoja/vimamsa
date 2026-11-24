#!/bin/bash
# Builds a newer GTK stack from source into $PREFIX (default /opt/gtk), for the
# optional "gtk-new" AppImage (Dockerfile.gtk-new, doc/appimage_old_base_plan.md).
# Run in the container with the names of the parts to build, in order, e.g.
#   build_gtk_stack.sh wayland wayland-protocols glib-bootstrap gobject-introspection glib
# (Dockerfile.gtk-new gives each part its own layer, so a failed build doesn't
# start over). Sources are pinned by SHA-256 and deleted after the install.
set -euo pipefail
PREFIX="${PREFIX:-/opt/gtk}"
JOBS="$(nproc)"

# name|url|sha256
SOURCES='
wayland|https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.26.0/downloads/wayland-1.26.0.tar.xz|64176eaa46e4969903e286f8e5ef8331affc17fdf03ac9b58381d2b23162b7a3
wayland-protocols|https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.50/downloads/wayland-protocols-1.50.tar.xz|4460c20cfcf68b994a5ee206ed15fc19ad312f16c96075186e83b0e3f4aa48a5
glib|https://download.gnome.org/sources/glib/2.90/glib-2.90.1.tar.xz|93c941aa17d5eb1d53fe838365f29a8b4e539c222a256d974ec8f30fc413e396
gobject-introspection|https://download.gnome.org/sources/gobject-introspection/1.86/gobject-introspection-1.86.0.tar.xz|920d1a3fcedeadc32acff95c2e203b319039dd4b4a08dd1a2dfd283d19c0b9ae
fontconfig|https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.17.1/fontconfig-2.17.1.tar.xz|9f5cae93f4fffc1fbc05ae99cdfc708cd60dfd6612ffc0512827025c026fa541
harfbuzz|https://github.com/harfbuzz/harfbuzz/releases/download/12.3.2/harfbuzz-12.3.2.tar.xz|6f6db164359a2da5a84ef826615b448b33e6306067ad829d85d5b0bf936f1bb8
cairo|https://cairographics.org/releases/cairo-1.18.6.tar.xz|1c767308174337a74694da0f3ec069c271452163a1ef4540964c50c301f157d4
pango|https://download.gnome.org/sources/pango/1.58/pango-1.58.2.tar.xz|342385b6ca3b7c73455d7c80a13b7dbe4489e00bc3bd4c5bd6ed4dce421e374a
gtk|https://download.gnome.org/sources/gtk/4.24/gtk-4.24.2.tar.xz|05561abc25d1b1400136bf79ab68830cb4b053d1922ae97e551b3f19755bf3cb
gtksourceview|https://download.gnome.org/sources/gtksourceview/5.18/gtksourceview-5.18.0.tar.xz|051a78fe38f793328047e5bcd6d855c6425c0b480c20d9432179e356742c6ac0
vte|https://download.gnome.org/sources/vte/0.80/vte-0.80.5.tar.xz|58a4e00ab5d4a95b4be4dc57b48308deafd72d6839dbbd076648fa353321cc41
'

# meson options per part (everything not needed by the editor is off)
opts() {
  case "$1" in
    wayland) echo "-Ddocumentation=false -Dtests=false -Ddtd_validation=false" ;;
    wayland-protocols) echo "-Dtests=false" ;;
    # glib's own typelibs need g-ir-scanner, which needs glib: build glib
    # without them, then gobject-introspection, then glib again with them
    glib-bootstrap) echo "-Dintrospection=disabled -Dtests=false -Dman-pages=disabled -Ddocumentation=false -Dselinux=disabled -Dsysprof=disabled -Dlibelf=disabled" ;;
    glib) echo "-Dintrospection=enabled -Dtests=false -Dman-pages=disabled -Ddocumentation=false -Dselinux=disabled -Dsysprof=disabled -Dlibelf=disabled" ;;
    gobject-introspection) echo "-Dtests=false -Dgtk_doc=false" ;;
    # The host's font configuration (/etc/fonts) and cache dir, not $PREFIX's
    fontconfig) echo "--sysconfdir=/etc --localstatedir=/var -Ddoc=disabled -Dtests=disabled -Dcache-build=disabled -Dnls=disabled" ;;
    harfbuzz) echo "-Dglib=enabled -Dgobject=enabled -Dintrospection=enabled -Dfreetype=enabled -Dcairo=disabled -Dchafa=disabled -Dicu=disabled -Dtests=disabled -Ddocs=disabled -Dutilities=disabled -Dbenchmark=disabled" ;;
    cairo) echo "-Dtests=disabled -Dgtk2-utils=disabled -Dspectre=disabled -Dsymbol-lookup=disabled -Dlzo=disabled -Dgtk_doc=false" ;;
    pango) echo "-Dintrospection=enabled -Ddocumentation=false -Dman-pages=false -Dbuild-testsuite=false -Dbuild-examples=false -Dsysprof=disabled -Dlibthai=disabled -Dxft=disabled" ;;
    # No GStreamer media backend (doc/appimage_old_base_plan.md); no Vulkan
    # (needs glslc, which 22.04 doesn't have): GTK uses its GL renderer
    gtk) echo "-Dmedia-gstreamer=disabled -Dvulkan=disabled -Dprint-cpdb=disabled -Dprint-cups=disabled -Dcloudproviders=disabled -Dsysprof=disabled -Dtracker=disabled -Dcolord=disabled -Daccesskit=disabled -Dintrospection=enabled -Ddocumentation=false -Dscreenshots=false -Dman-pages=false -Dbuild-demos=false -Dbuild-testsuite=false -Dbuild-examples=false -Dbuild-tests=false" ;;
    gtksourceview) echo "-Dintrospection=enabled -Dvapi=false -Ddocumentation=false -Dsysprof=false -Dbuild-testsuite=false -Dinstall-tests=false" ;;
    # 0.80, not 0.84: 0.82+ need C++23 library parts (std::out_ptr) that
    # 22.04's g++ 12 lacks, and a newer g++ would need a newer libstdc++ than
    # a 22.04 host has. 0.80 needs C++20 and GTK >= 4.14.
    vte) echo "-Dgtk3=false -Dgtk4=true -Dgir=true -Dvapi=false -Ddocs=false -Dgnutls=false -Dicu=false -D_systemd=false -Dglade=false" ;;
  esac
}

build() { # part
  local part=$1 src=$1
  [ "$part" = glib-bootstrap ] && src=glib
  local line url sha
  line=$(echo "$SOURCES" | grep "^$src|") || { echo "!! unknown part: $part"; exit 1; }
  url=$(echo "$line" | cut -d'|' -f2); sha=$(echo "$line" | cut -d'|' -f3)
  local w=/tmp/stack/$part
  rm -rf "$w" && mkdir -p "$w" && cd "$w"
  echo ">> $part: $(basename "$url")"
  wget -q -O src.tar.xz "$url"
  echo "$sha  src.tar.xz" | sha256sum -c --quiet || { echo "!! checksum mismatch: $url"; exit 1; }
  tar xJf src.tar.xz --strip-components=1 && rm src.tar.xz
  local env=()
  # VTE: g++ 12, 22.04's newest (its default is 11)
  [ "$part" = vte ] && env=(CC=gcc-12 CXX=g++-12)
  # shellcheck disable=SC2046
  env "${env[@]}" meson setup _b --prefix="$PREFIX" --libdir=lib --buildtype=release \
    -Dwrap_mode=default $(opts "$part") >/tmp/stack/$part.setup.log 2>&1 ||
    { tail -40 /tmp/stack/$part.setup.log; exit 1; }
  ninja -C _b -j"$JOBS" >/tmp/stack/$part.build.log 2>&1 ||
    { grep -E -B2 -A8 'error:|FAILED' /tmp/stack/$part.build.log | head -80; exit 1; }
  ninja -C _b install >/dev/null
  cd / && rm -rf "$w"
  ldconfig
}

for p in "$@"; do build "$p"; done
