# Plan: AppImage with GTK 4.24 on an Ubuntu 22.04 base (optional build)

## Goal

The AppImage is built on Ubuntu 24.04 today (`scripts/appimage/Dockerfile`), so it
carries GTK 4.14 and needs glibc ≥ 2.39. **That build stays the default and is not
changed.** This plan adds a second, optional build next to it:

- **Base: Ubuntu 22.04** → the AppImage needs glibc ≥ **2.35** (Ubuntu 22.04+,
  Debian 12+, Fedora 36+).
- **GTK 4.24.2**, built from source with the libraries it needs into `/opt/gtk`.
- **No GStreamer backend in GTK** (`-Dmedia-gstreamer=disabled`).

glibc is backward compatible, so binaries built on 22.04 run on every newer system.
Libraries 22.04 already has in a new enough version stay from 22.04. They were built
against glib 2.72, but run fine with the newer bundled glib (glib keeps its ABI).

## What gets built, and what stays from 22.04

Minimum versions are from the projects' `meson.build` (checked 2026-11-24); the
versions to build are the latest releases on that date.

| Library | 22.04 has | Needed by | Minimum | Build |
|---|---|---|---|---|
| meson (pip) | 0.61.2 | GTK | ≥ 1.8.0 | latest |
| wayland | 1.20.0 | GTK | ≥ 1.24.0 | 1.26.0 |
| wayland-protocols | 1.25 | GTK | ≥ 1.48 | 1.50 |
| glib | 2.72.4 | GTK | ≥ 2.89.3 | 2.90.1 |
| gobject-introspection | 1.72.0 | GTK; glib 2.90 | ≥ 1.84 | 1.86.0 (needs glib ≥ 2.82) |
| fontconfig | 2.13.1 | pango 1.58 | ≥ 2.17.0 | latest 2.17.x |
| harfbuzz | 2.7.4 | pango 1.58 | ≥ 11.0.0 | 12.3.2 |
| cairo | 1.16.0 | GTK | ≥ 1.18.2 | 1.18.6 |
| pango | 1.50.6 | GTK | ≥ 1.58 | 1.58.2 |
| **GTK** | 4.6 | — | — | **4.24.2** |
| GtkSourceView | 5.4 | — | needs GTK ≥ 4.17, glib ≥ 2.76 | 5.18.0 |
| VTE (gtk4) | 0.68 | — | C++20 (g++ ≥ 10), GTK ≥ 4.14 | 0.80.5 (see below) |

**Stay from 22.04** (new enough): fribidi 1.0.8, gdk-pixbuf 2.42.8, graphene 1.10.8,
libepoxy 1.5.10, libxkbcommon 1.4.0, freetype 2.11.1 (cairo needs ≥ 2.10), pixman
0.40, librsvg 2.52 (already compiled, so no Rust), libxml2, pcre2, libffi, X11/xcb,
libpng/jpeg/tiff, gnutls, ICU, lz4, Python 3.10, and **GStreamer 1.20** (used directly
by the dictation recorder through the Ruby gem, not through GTK).

**Tools:** `g++-12` from the 22.04 repositories for VTE (default is 11).

**VTE 0.80, not 0.84** (found while building, 2026-11-24): VTE 0.82+ is C++23 and
0.84 uses `std::out_ptr`, which g++ 12's libstdc++ doesn't have (its `meson.build`
says g++ ≥ 12.1, but in practice it needs g++ 14). A newer g++ from a PPA would need a
newer `libstdc++` than a 22.04 host has, which then has to be bundled. 0.80.5 needs
C++20 and GTK ≥ 4.14 and is still newer than development's 0.76 (Ubuntu 24.04).

**No Vulkan** (`-Dvulkan=disabled`): GTK's Vulkan renderer needs `glslc`, which
22.04 doesn't have. GTK uses its GL renderer.

**Optional, not the default:** the new build is started explicitly
(`scripts/appimage/build.sh --gtk-new`, see below). The default build, its
Dockerfile, CI workflow and release AppImage stay as they are. Making the new build
the default is a later, separate decision, once it has passed the tests for a while.

## Build order (Dockerfile stage, prefix `/opt/gtk`)

1. `pip install meson ninja`; `apt install g++-12` + the 22.04 `-dev` packages of the
   libraries that stay.
2. wayland (`-Ddocumentation=false`), wayland-protocols.
3. glib **without** introspection → gobject-introspection → glib again **with**
   introspection (glib's typelibs need g-ir-scanner, which needs glib).
4. fontconfig → harfbuzz (`-Dcairo=disabled`, against 22.04's freetype) → cairo →
   pango.
5. GTK 4.24.2: `-Dmedia-gstreamer=disabled`, no demos/examples/tests, introspection
   enabled.
6. GtkSourceView 5.18.0, then VTE 0.80.5 (`-Dgtk3=false -Dgtk4=true -Dvapi=false`,
   `CXX=g++-12`).

Its own cached Docker stage: about 30–60 min the first time, unchanged builds reuse it.

## Changes in the repo

The default build must come out exactly as before. Everything new is either in new
files or behind a setting that is off by default.

**New files**
- **`scripts/appimage/Dockerfile.gtk-new`**: `FROM ubuntu:22.04` plus the `/opt/gtk`
  stage above. Ruby and the gems are built with `PKG_CONFIG_PATH`/`LD_LIBRARY_PATH`
  pointing at `/opt/gtk` first. The existing `Dockerfile` is not touched.

**Changed, with the default unchanged**
- **`scripts/appimage/build.sh`**: a `--gtk-new` option (or `VMA_APPIMAGE_VARIANT=gtk-new`)
  picks `Dockerfile.gtk-new`, its own image name (`vimamsa-appimage-build-gtk-new`), and
  its own output and cache dir, `build/appimage-gtk-new/`. The cache must be separate:
  a Ruby cached from the 24.04 build needs glibc 2.39 and would not run on 22.04.
  Without the option, nothing changes.
- **`scripts/appimage/build_in_container.sh`**: everything new is controlled by
  variables that only `--gtk-new` sets (`VMA_GTK_PREFIX=/opt/gtk`, and the list of
  libraries to take off `EXCLUDE`). When they are unset, the script does what it does
  now:
  - Typelibs, GSettings schemas, `share/gtksourceview-5` and GIO modules come from
    `$VMA_GTK_PREFIX` first, then the system dirs for what stayed (GdkPixbuf,
    Graphene and the other typelibs, the dconf GIO module, the pixbuf loaders).
  - `EXCLUDE` (line 85): `libwayland-client/-cursor/-egl`, `libharfbuzz` and
    `libfontconfig` are taken off the list, so the rebuilt ones are bundled. A 22.04
    host's copies are too old for GTK/pango. freetype stays excluded.
  - Output name `Vimamsa-<version>-gtk4.24-x86_64.AppImage`, so the two can't be
    mixed up.
  - Check with `LD_DEBUG=libs` that no GTK-stack library is loaded from the host.
- **`scripts/appimage/AppRun`**: for the libraries taken off `EXCLUDE`, use whichever
  is newer, the host's or the bundled one. They go in a separate dir (e.g.
  `usr/lib/compat/`) that goes on `LD_LIBRARY_PATH` only when its copy is newer than
  the host's (compare the versioned file names, e.g. `libwayland-client.so.0.26.0`).
  This keeps the host's Mesa working on systems newer than the bundle. The default
  build has no `compat/` dir, so this step does nothing there.
- **Audio module** (`modules/audio/audio.rb:104` uses `Gtk::MediaFile`): without the
  GStreamer backend nothing plays. Detect it and say "audio playback isn't available
  in this build" instead of failing. Dictation is unaffected. This check is harmless in
  the default build, which has the backend.
- **`scripts/appimage/smoke_test.sh`**: an option to run the new AppImage on
  `ubuntu:22.04`. Default stays 24.04 with the default AppImage.

**Not changed:** `scripts/appimage/Dockerfile`, `.github/workflows/appimage.yml`
(CI keeps building and releasing the default AppImage; a manual job for the new build
can come later), the README's download section.

**Docs:** a short "Optional: newer GTK, older glibc" section in `doc/bundling_plan.md`
that points here, with the `build.sh --gtk-new` command.

## Found while building (2026-11-24)

- **Ruby-GNOME works with GTK 4.24 / glib 2.90**: `gem install` takes 4.3.9 (the
  newest matching `~> 4.3.5`); it compiles and loads. Risk 1 below is cleared.
- **Images through GIO's MIME database**: 22.04's gdk-pixbuf (2.42.8) recognizes
  image files with GIO content type guessing. GLib reads `XDG_DATA_DIRS` once, on
  first use, and `restore_host_env` puts the host's back after startup, so a host
  without shared-mime-info couldn't load PNGs. Fix: `restore_host_env`
  (`appimage_env.rb`) guesses one content type before restoring.
- **Crash at exit with GTK 4.24**: Ruby's exit-time GC finalizers dispose text views
  after GTK has shut down (`gtk_text_view_dispose` → `gtk_gesture_is_active`,
  segfault). On every quit, and it lost the test results (buffered output).
  Workaround in `exe/vimamsa`: with GTK newer than 4.14, the last `at_exit` handler
  leaves with `exit!` after the other handlers ran. The default build (4.14) is
  unchanged.

## Risks to check first

1. **Ruby-GNOME with GTK 4.24 / glib 2.90**: the gemspec pins `gtk4 ~> 4.3.5`. The
   gems use `libgirepository-1.0`. Check that gobject-introspection 1.86 still builds
   it, and whether a newer Ruby-GNOME (4.3.8 is out) is needed. This decides whether
   the plan works at all, so try it first: build the stack, `gem install`, start the
   editor.
2. **Behaviour changes from GTK 4.14 to 4.24** (the development version stays 4.14):
   run the full suite against the AppImage in the VM (`tests/test_bundling.rb` + the
   rest).
3. **libstdc++**: avoided by staying with VTE 0.80 (C++20, 22.04's own `libstdc++`).
   A later VTE (C++23) would need a newer g++ and its `libstdc++` bundled, with the
   same newer-of-the-two handling in AppRun.
4. **fontconfig 2.17 on the host's `/etc/fonts`**: it reads the host's config; if its
   cache format differs from the host's, the first start builds a separate cache
   (slow once). Check on 22.04 and 24.04.
5. **Upkeep**: every new GTK raises the minimums again (4.24 already needs glib 2.89+).
   Update the stack deliberately, not on every GTK release.

## Order of work

1. `Dockerfile.gtk-new` stack stage + Ruby-GNOME check (risk 1). Stop here if the
   gems don't work.
2. `build.sh --gtk-new`, the variables in `build_in_container.sh`, the `EXCLUDE`
   change and the AppRun version check.
3. Check that the default build is unchanged: build it, compare the AppDir file list
   and `AppRun` with the previous build, and run `tests/test_bundling.rb`.
4. Audio module message.
5. New AppImage: smoke test on 22.04 and 24.04, full suite in the VM, `LD_DEBUG=libs`
   check.
6. Docs and TODO entry.
