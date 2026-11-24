#!/bin/bash
# Builds build/appimage/Vimamsa-<version>-x86_64.AppImage inside the container
# from scripts/appimage/Dockerfile. Started by scripts/appimage/build.sh, which
# mounts the repository read-only at /src and build/appimage at /build.
#
#   VMA_REF       git ref to build (default HEAD), or WORKTREE for HEAD plus uncommitted
#                 changes and new files under lib/ modules/ exe/ tests/
#   RUBY_VERSION  Ruby to bundle (default 3.4.9; the build is cached in /build/cache)
#   VMA_GTK_PREFIX  set only by Dockerfile.gtk-new (the optional build, see
#                 doc/appimage_old_base_plan.md): the GTK stack built from source
#                 there. Unset (the default build), nothing below changes.
set -euo pipefail

RUBY_VERSION="${RUBY_VERSION:-3.4.9}"
VMA_REF="${VMA_REF:-HEAD}"
SYSLIB=/usr/lib/x86_64-linux-gnu
GP="${VMA_GTK_PREFIX:-}"
# gtk-new: libraries a host may have in an older version than the bundle needs.
# They are bundled, and AppRun uses the host's copy instead when it is newer.
HOST_OR_BUNDLED="libwayland-client.so.0 libwayland-cursor.so.0 libwayland-egl.so.1 libharfbuzz.so.0 libfontconfig.so.1"
B=/build
CACHE=$B/cache
APPDIR=$B/AppDir
U=$APPDIR/usr
mkdir -p "$CACHE"

step() { echo; echo ">> $*"; }

# ── 1. Ruby, relocatable (finds its stdlib and gems relative to bin/ruby) ──
ruby_tar="$CACHE/ruby-$RUBY_VERSION-installed.tar"
if [ ! -f "$ruby_tar" ]; then
  step "Building Ruby $RUBY_VERSION"
  rm -rf /tmp/rb && mkdir -p /tmp/rb && cd /tmp/rb
  wget -q "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-$RUBY_VERSION.tar.gz"
  tar xzf "ruby-$RUBY_VERSION.tar.gz" && cd "ruby-$RUBY_VERSION"
  ./configure -q --prefix=/usr --enable-load-relative --enable-shared --disable-install-doc
  make -s -j"$(nproc)" >/dev/null
  make -s install DESTDIR=/tmp/rb/root >/dev/null
  tar cf "$ruby_tar" -C /tmp/rb/root .
fi
step "Fresh AppDir"
rm -rf "$APPDIR" && mkdir -p "$APPDIR"
tar xf "$ruby_tar" -C "$APPDIR"
export PATH="$U/bin:$PATH"

# ── 2. vimamsa gem + dependencies, compiled against this container's libs ──
step "Building the vimamsa gem from $VMA_REF"
rm -rf /tmp/src && git clone -q /src /tmp/src
cd /tmp/src
if [ "$VMA_REF" = WORKTREE ]; then
  # Development build: HEAD plus uncommitted changes to tracked files and new
  # source files (not the other untracked files lying around in the checkout)
  (cd /src && { git ls-files -m; git ls-files -o --exclude-standard -- lib modules exe tests; } |
     grep -v '_vma_autosave$' | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done) |
    while read -r f; do mkdir -p "$(dirname "$f")"; cp "/src/$f" "$f"; done
  git -c user.name=build -c user.email=build@localhost add -A >/dev/null
else
  git checkout -q "$VMA_REF"
fi
VERSION=$(ruby -Ilib -e 'require "vimamsa/version"; print Vimamsa::VERSION')
gem build -q vimamsa.gemspec
step "Installing gems (compiles the native extensions)"
gem install --no-document "vimamsa-$VERSION.gem"
GEMDIR=$(ruby -e 'print Gem.default_dir')

# ── 3. Typelibs (Ruby-GNOME loads most of the API through them) ──
step "Typelibs"
mkdir -p "$U/lib/girepository-1.0"
cp "$SYSLIB"/girepository-1.0/*.typelib "$U/lib/girepository-1.0/"
# gtk-new: the rebuilt stack's typelibs replace the system's
[ -n "$GP" ] && cp "$GP"/lib/girepository-1.0/*.typelib "$U/lib/girepository-1.0/"

# ── 4. Runtime modules loaded with dlopen ──
step "GStreamer plugins, gdk-pixbuf loaders, GIO modules"
cp -r "$SYSLIB/gstreamer-1.0" "$U/lib/"
mkdir -p "$U/lib/gstreamer1.0/gstreamer-1.0"
cp "$SYSLIB/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner" "$U/lib/gstreamer1.0/gstreamer-1.0/"
pix=$U/lib/gdk-pixbuf-2.0/2.10.0
mkdir -p "$pix"
cp -r "$SYSLIB/gdk-pixbuf-2.0/2.10.0/loaders" "$pix/"
# AppRun fills in the mount point
sed "s|$SYSLIB/gdk-pixbuf-2.0/2.10.0/loaders|@PIXBUF_LOADERS@|g" \
  "$SYSLIB/gdk-pixbuf-2.0/2.10.0/loaders.cache" > "$pix/loaders.cache.in"
mkdir -p "$U/lib/gio/modules"
# dconf: GSettings are saved like in other apps. No gvfs (trash, remote
# locations in the file chooser) or proxy modules.
cp "$SYSLIB/gio/modules/libdconfsettings.so" "$U/lib/gio/modules/"
gio-querymodules "$U/lib/gio/modules"

# ── 5. Shared libraries: everything the above needs, except the host's ──
# Left to the host (as in the AppImage project's excludelist): glibc, the C++
# runtime, GL/Vulkan/DRM drivers, X11/xcb/Wayland client libs, fontconfig/
# freetype/harfbuzz (tied to the host's font setup), and the sound servers.
EXCLUDE='^(ld-linux.*|libc|libm|libmvec|libdl|libpthread|librt|libresolv|libutil|libanl|libnss_.*|libthread_db|libBrokenLocale|libstdc\+\+|libgcc_s|libGL|libGLX|libGLdispatch|libOpenGL|libEGL|libGLESv2|libgbm|libdrm|libvulkan|libX11|libX11-xcb|libxcb|libxcb-dri2|libxcb-dri3|libxcb-glx|libxcb-present|libxcb-sync|libxcb-xfixes|libICE|libSM|libwayland-client|libwayland-cursor|libwayland-egl|libwayland-server|libfontconfig|libfreetype|libharfbuzz|libasound|libjack|libpipewire-0\.3|libpulse|libpulse-simple|libpulsecommon-.*|libz|libexpat|libuuid|libcom_err|libgpg-error|libusb-1\.0)\.so'
if [ -n "$GP" ]; then
  # gtk-new: a 22.04 host's copies are too old for the rebuilt GTK and pango,
  # so these are bundled (HOST_OR_BUNDLED above)
  EXCLUDE=${EXCLUDE//libwayland-client|libwayland-cursor|libwayland-egl|/}
  EXCLUDE=${EXCLUDE//libfontconfig|/}
  EXCLUDE=${EXCLUDE//libharfbuzz|/}
fi
step "Collecting shared libraries"
declare -A seen
queue=()
add() { [ -n "${seen[$1]:-}" ] && return; seen[$1]=1; queue+=("$1"); }
for f in "$U/bin/ruby" "$U"/lib/libruby.so.*.*; do add "$f"; done
while IFS= read -r f; do add "$f"; done < <(find "$GEMDIR" "$U/lib/ruby" "$U/lib/gstreamer-1.0" \
  "$U/lib/gstreamer1.0" "$pix" "$U/lib/gio" -type f \( -name '*.so' -o -name gst-plugin-scanner \))
# Libraries only reached through typelibs (dlopen by soname)
for t in "$U"/lib/girepository-1.0/*.typelib; do
  for so in $(strings "$t" | grep -E '^lib.*\.so' | tr ',' ' '); do
    if [ -n "$GP" ] && [ -e "$GP/lib/$so" ]; then add "$GP/lib/$so"
    elif [ -e "$SYSLIB/$so" ]; then add "$SYSLIB/$so"; fi
  done
done
i=0
while [ $i -lt ${#queue[@]} ]; do
  f=${queue[$i]}; i=$((i + 1))
  name=$(basename "$f")
  # (ldd reports /lib/x86_64-linux-gnu/..., the same dir as $SYSLIB on 24.04)
  if [[ "$f" != "$APPDIR"/* ]] && ! [[ "$name" =~ $EXCLUDE ]]; then
    [ -e "$U/lib/$name" ] || cp -L "$f" "$U/lib/$name"
  fi
  while read -r dep; do
    [[ "$(basename "$dep")" =~ $EXCLUDE ]] && continue
    add "$dep"
  done < <(ldd "$f" 2>/dev/null | awk '/=> \//{print $3}')
done

step "Setting RUNPATH so bundled libraries are found without LD_LIBRARY_PATH"
relpath() { realpath --relative-to="$1" "$U/lib"; }
while IFS= read -r f; do
  file -b "$f" | grep -q '^ELF' || continue
  d=$(dirname "$f")
  patchelf --set-rpath "\$ORIGIN/$(relpath "$d")" "$f"
done < <(find "$U/lib" "$U/bin" -type f \( -name '*.so*' -o -name gst-plugin-scanner -o -name ruby \))

# Every bundled ELF file must now resolve all its libraries (bundled ones
# through RUNPATH, the excluded ones from this system)
missing=$(find "$U/lib" "$U/bin" -type f \( -name '*.so*' -o -name gst-plugin-scanner -o -name ruby \) \
  -exec sh -c 'ldd "$1" 2>/dev/null | grep "not found" | sed "s|^|$1: |"' _ {} \; | sort -u)
if [ -n "$missing" ]; then echo "!! unresolved libraries:"; echo "$missing"; exit 1; fi

if [ -n "$GP" ]; then
  # For AppRun: each library's version (from the real file name, e.g.
  # libwayland-client.so.0.26.0), to compare with the host's
  : > "$U/lib/vimamsa-host-or-bundled.txt"
  for n in $HOST_OR_BUNDLED; do
    [ -e "$U/lib/$n" ] || continue
    src=$(readlink -f "$GP/lib/$n" 2>/dev/null || readlink -f "$SYSLIB/$n")
    echo "$n ${src##*.so.}" >> "$U/lib/vimamsa-host-or-bundled.txt"
  done
  cat "$U/lib/vimamsa-host-or-bundled.txt"
fi

# ── 6. Data files ──
step "Data: GtkSourceView, schemas, icons, MIME database"
mkdir -p "$U/share/glib-2.0/schemas" "$U/share/icons"
if [ -n "$GP" ]; then
  cp -r "$GP/share/gtksourceview-5" "$U/share/"
  # 22.04's schemas (GSettings desktop schemas) plus the rebuilt GTK's
  cp /usr/share/glib-2.0/schemas/*.xml "$GP"/share/glib-2.0/schemas/*.xml "$U/share/glib-2.0/schemas/"
else
  cp -r /usr/share/gtksourceview-5 "$U/share/"
  cp /usr/share/glib-2.0/schemas/*.xml "$U/share/glib-2.0/schemas/"
fi
glib-compile-schemas "$U/share/glib-2.0/schemas"
cp -r /usr/share/icons/Adwaita /usr/share/icons/hicolor "$U/share/icons/"
# MIME database: GIO's content type guessing, which gdk-pixbuf (image format
# detection) and GtkSourceView (language detection) rely on
cp -r /usr/share/mime "$U/share/"

# ── 7. Launchers ──
step "AppRun, desktop entry, icon"
cp /src/scripts/appimage/AppRun "$APPDIR/AppRun" && chmod +x "$APPDIR/AppRun"
# ruby-lsp / rufo on PATH without the bundled ruby (see AppRun)
mkdir -p "$U/lib/vimamsa/bin"
# Without BUNDLE_GEMFILE, ruby-lsp composes a bundle from the project's
# Gemfile (.ruby-lsp/Gemfile) and runs `bundle install`, which tries to write
# the project's gems into the read-only image (Bundler::ReadOnlyFileSystemError)
# and stalls the server's startup. Point it at a fixed bundle of just ruby-lsp,
# locked here from the installed gems: it then starts at once, offline.
mkdir -p "$U/lib/vimamsa/lsp"
printf 'source "https://rubygems.org"\ngem "ruby-lsp"\n' > "$U/lib/vimamsa/lsp/Gemfile"
(cd "$U/lib/vimamsa/lsp" && bundle lock --local)
for t in ruby-lsp rufo; do
  # (the editor has put the user's GEM_HOME etc. back by the time these run)
  gemfile=""
  [ "$t" = ruby-lsp ] && gemfile='export BUNDLE_GEMFILE="$d/../lsp/Gemfile"\n'
  printf "#!/bin/sh\nunset GEM_HOME GEM_PATH RUBYOPT RUBYLIB\nd=\"\$(dirname \"\$(readlink -f \"\$0\")\")\"\n${gemfile}exec \"\$d/../../../bin/%s\" \"\$@\"\n" "$t" > "$U/lib/vimamsa/bin/$t"
  chmod +x "$U/lib/vimamsa/bin/$t"
done
cat > "$APPDIR/vimamsa.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Vimamsa
Comment=Vi/Vim-inspired GUI text editor
Exec=vimamsa %F
Icon=vimamsa
Terminal=false
Categories=Utility;TextEditor;
StartupWMClass=net.samiddhi.vimamsa
EOF
cp /tmp/src/icon.png "$APPDIR/vimamsa.png"
ln -sf vimamsa.png "$APPDIR/.DirIcon"

# ── 8. Smoke test, then pack ──
step "Smoke test: load the editor's libraries from the AppDir"
# Clean environment (no host GI_TYPELIB_PATH etc.); the libraries must come
# from the AppDir through RUNPATH
xvfb-run -a sh -c 'exec env -i HOME=/tmp PATH=/usr/bin:/bin DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" \
  GI_TYPELIB_PATH="$0/usr/lib/girepository-1.0" "$0/usr/bin/ruby" \
  -e "%w[gtk4 gtksourceview5 vte4 gstreamer].each { |g| require g }; Gst.init; puts %q(gems load OK)"' "$APPDIR"
if [ -n "$GP" ]; then
  # gtk-new: the bundled GTK is the rebuilt one, not 22.04's
  xvfb-run -a sh -c 'exec env -i HOME=/tmp PATH=/usr/bin:/bin DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" \
    GI_TYPELIB_PATH="$0/usr/lib/girepository-1.0" "$0/usr/bin/ruby" \
    -e "require %q(gtk4); v = Gtk::Version::STRING; puts %q(GTK ) + v; exit(v == %q($1) ? 0 : 1)"' \
    "$APPDIR" "$(pkg-config --modversion gtk4)"
fi

step "Packing"
# Pinned versions, checked against their SHA-256 (not the moving "continuous"
# builds): appimagetool and the static type-2 runtime it puts in front of the
# image (no libfuse2 needed on the user's machine)
fetch() { # url sha256 dest
  if ! echo "$2  $3" | sha256sum -c --status 2>/dev/null; then
    wget -q -O "$3" "$1"
    echo "$2  $3" | sha256sum -c --quiet || { echo "!! checksum mismatch: $1"; exit 1; }
  fi
}
tool=$CACHE/appimagetool-1.9.1-x86_64.AppImage
runtime=$CACHE/type2-runtime-20251108-x86_64
fetch https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage \
  ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0 "$tool"
fetch https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64 \
  2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d "$runtime"
chmod +x "$tool"
# gtk-new: the GTK version in the name, so the two builds can't be mixed up
suffix=""
[ -n "$GP" ] && suffix="-gtk$(pkg-config --modversion gtk4 | cut -d. -f1,2)"
out="$B/Vimamsa-$VERSION$suffix-x86_64.AppImage"
# Pack to a temporary name and rename: the previous AppImage may be running
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$tool" --no-appstream --runtime-file "$runtime" "$APPDIR" "$out.tmp"
mv -f "$out.tmp" "$out"
ls -lh "$out"
du -sh "$APPDIR"
