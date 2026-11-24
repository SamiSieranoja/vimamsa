# Plan: Vimamsa as a single downloadable app

## Goal

A user downloads one file and runs it. They don't need to install Ruby, compile gems
or install `-dev` packages. Today, installing means: a system Ruby 3.x, about 15 GTK
`-dev` packages, `gem build` + `gem install`, which compiles the vmaext C extension and
all the Ruby-GNOME native extensions (`install.sh`, `Dockerfile`, `vm_guest_run.sh`).
That takes several minutes and fails easily on unusual systems.

This document replaces earlier informal AppImage notes with a checked, concrete plan.

## What has to be bundled (verified 2026-11-19)

| Layer | Contents | Notes |
|---|---|---|
| Ruby runtime | Ruby 3.x interpreter + stdlib (dev: 3.4.9) | must be relocatable |
| Pure-Ruby gems | ripl, ripl-multi_line, differ, parallel, listen, language_server-protocol, rufo, ruby-lsp (+ prism, rbs, sorbet-runtime…) | `ruby-lsp` and `rufo` are runtime deps in the gemspec. Both stay in the bundle (see code change 5). |
| Native gems | glib2, gobject-introspection, gio2, cairo, cairo-gobject, pango, gdk_pixbuf2, gdk4, gtk4, gtksourceview5, gstreamer, vte4, ffi, rb-inotify (via listen), StrIdx | compiled against the build machine's libs |
| Own C extension | `ext/vmaext` (`vmaext.so`) | built by `extconf.rb` |
| **GI typelibs** | `Gtk-4.0`, `Gdk-4.0`, `Gsk-4.0`, `GtkSource-5`, `Gst-1.0`, `GstBase-1.0`, `Vte-3.91`, `Pango-1.0`, `PangoCairo`, `GLib/GObject/Gio-2.0`, `GdkPixbuf-2.0`, `Graphene-1.0`, `HarfBuzz-0.0`, `cairo-1.0`, `freetype2-2.0`, `GModule-2.0` … | **The main gotcha.** Ruby-GNOME loads most of the API at runtime through GObject Introspection (`/usr/lib/x86_64-linux-gnu/girepository-1.0/*.typelib`). The libraries the typelibs point to are `dlopen`ed, so `ldd`-based tools don't see them. |
| Shared libs | GTK4, GtkSourceView 5, VTE (gtk4), GStreamer core + base/good plugins, pango, cairo, harfbuzz, glib, libgirepository, graphene, gdk-pixbuf + loaders | leave out glibc, libGL/GPU drivers, fontconfig config (the standard AppImage excludelist) |
| Runtime data | `share/gtksourceview-5/` (language-specs incl. `def.lang`, `markdown.lang`; styles), GSettings schemas (compiled), gdk-pixbuf `loaders.cache`, Adwaita icon theme (symbolic icons; `gui.rb:619` forces the Adwaita theme), GStreamer `gst-plugin-scanner` | |
| App files | `lib/`, `exe/`, `ext/`, `lang/`, `styles/`, `fonts/`, `modules/`, `icon.png`, `custom_example.rb`, `demo.txt`, README.md | `ppath()` (`util.rb:357`) resolves `lib/vimamsa/../../<x>`, so the repo layout must stay intact |

**Not bundled; stays a host requirement or a module requirement:** ack, clang-format,
git, diff, gnome-terminal (`terminal.rb:22`), xdg-open, ollama, piper/aplay, and the
dictation Python worker (faster-whisper + CUDA is far too large). That matches
`doc/modules_settings_plan.md`: the modules page tells the user what to install.

## Options

### A. AppImage (recommended for "one downloadable file")

One executable file (`Vimamsa-x86_64.AppImage`): download, `chmod +x`, run. No sandbox,
so the many external tools the editor runs (ack, git, clang-format, gnome-terminal,
`bash -c`) work exactly as they do today. That decides it for a text editor.

Build steps (a script, `scripts/build_appimage.sh`, run inside a container):
1. **Build host**: Ubuntu 22.04 (glibc 2.35, GTK 4.6, GtkSourceView 5.4, VTE 0.68)
   gives the widest compatibility, but it's far behind the development GTK. Ubuntu
   24.04 (GTK 4.14) matches development. See "GTK version differences" below for
   the trade-off. Decide after running the test suite on 22.04.
2. **Ruby**: build from source with `--prefix=/usr --enable-load-relative
   --enable-shared`, `make install DESTDIR=AppDir`. `load-relative` makes the
   interpreter find its stdlib relative to the binary. (traveling-ruby isn't
   reliably maintained; ruby-build + load-relative is simpler to control.)
3. **Gems**: `AppDir/usr/bin/ruby -S gem install --no-document --install-dir AppDir/usr/lib/ruby/gems/3.x.0 vimamsa-*.gem`
   (or `bundle install --deployment` from a Gemfile.lock to pin versions). This
   compiles the native gems and vmaext against the build host's libs.
4. **Libraries**: `linuxdeploy --appdir AppDir --plugin gtk --plugin gstreamer`
   deploys the dependencies of every `.so` under AppDir (point it at the gem
   extension `.so`s with `--library` / `--deploy-deps-only`). GTK4 support in
   linuxdeploy-plugin-gtk is newer than its GTK3 support and may need patching.
   Then **explicitly** add the libs that are only reached through typelibs:
   libgtk-4, libgtksourceview-5, libvte-2.91-gtk4, libgstreamer-1.0, libgraphene,
   libgirepository-1.0, and check with `GI_TYPELIB_PATH` + `LD_DEBUG=libs` that
   nothing is loaded from the host.
5. **Typelibs and data**: copy the typelibs listed above to
   `AppDir/usr/lib/girepository-1.0/`, copy `share/gtksourceview-5`, the Adwaita
   icons and the schemas, and run `glib-compile-schemas`.
6. **AppRun**: a shell script that exports
   `GI_TYPELIB_PATH=$APPDIR/usr/lib/girepository-1.0`,
   `XDG_DATA_DIRS=$APPDIR/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}`,
   `GSETTINGS_SCHEMA_DIR`, `GDK_PIXBUF_MODULE_FILE`, `GST_PLUGIN_SYSTEM_PATH`,
   `GST_PLUGIN_SCANNER`, `GEM_HOME`/`GEM_PATH` (bundled only; unset the user's
   `GEM_HOME` and `RUBYOPT`), and `LD_LIBRARY_PATH` if linuxdeploy didn't set an
   rpath, then runs `exec "$APPDIR/usr/bin/ruby" "$APPDIR/usr/share/vimamsa/exe/vimamsa" "$@"`.
7. **Pack**: `appimagetool` with the **new static type-2 runtime**. The old runtime
   needs `libfuse2`, which Ubuntu 24.04 no longer installs by default; with the old
   runtime users would need `sudo apt install libfuse2t64` or
   `--appimage-extract-and-run`. Embed update info (zsync) for AppImageUpdate.
8. **CI**: a GitHub Actions job in a container of the build host (proposed `ubuntu:24.04`) builds it on a tag and
   attaches it to the GitHub release.

Expected size: Ruby + gems about 60–80 MB, GTK4 + deps about 60 MB, GStreamer
base/good about 30–60 MB. Roughly **150–250 MB uncompressed and 60–100 MB as an
AppImage** (squashfs/zstd). Trimming GStreamer to the plugins audio playback and
dictation capture need (`playbin`, `autoaudiosrc`, decodebin, mp3/ogg/wav) keeps it at
the low end.

#### The typelib problem is build-time only

The hardest part of the AppImage (step 4: finding every library and data file that
Ruby-GNOME loads at runtime through GObject Introspection) is a problem for **whoever
builds the AppImage**, not for users. `ldd`-based tools can't see those libraries, so
the build script has to list them by hand. If one is missed, the AppImage still works
on the build machine and the developer's desktop, because the library is there in
`/usr/lib`. It then fails on a user's machine that doesn't have it, with an error such
as `Typelib file for namespace 'GtkSource' not found`. That's why the clean-machine
test below is required. Once the list is complete, users see none of this.

#### What users of the AppImage have to do

Required:
1. Download `Vimamsa-x86_64.AppImage`.
2. Make it executable: `chmod +x Vimamsa-x86_64.AppImage`, or Properties ▸
   "Allow executing file as program" in the file manager.
3. Run it, by double-click or `./Vimamsa-x86_64.AppImage [file]`.

No Ruby, no gems, no `apt install`, no compiling. On first start the editor installs
its own launcher and icon into `~/.local/share` (`desktop_install.rb`), pointing at
the AppImage (code change 3), so after that it appears in the app menu. If the user
moves the file, the next start updates the launcher.

Only in special cases:
- **libfuse2**: not needed with the static type-2 runtime (step 7). If an older
  runtime were used, Ubuntu 22.04+ users would need `sudo apt install libfuse2` /
  `libfuse2t64`, or would have to run it with `--appimage-extract-and-run`. Using the
  static runtime avoids this, and it's a build decision, not a user action.
- **System requirements**: x86_64 Linux with glibc at least the build host's: with
  the proposed Ubuntu 24.04 build host, glibc ≥ 2.39 (Ubuntu 24.04, Debian 13, Fedora 40
  or newer; 22.04 would allow glibc ≥ 2.35) and a Wayland or X11 desktop. Older distros or arm64 need a
  separate build. The GPU driver and fonts come from the host, as with any
  AppImage.
- **Restricted `/tmp` or home on `noexec`** (some corporate setups): AppImages can't
  run from a `noexec` mount, so the user moves the file to e.g. `~/Applications`.

Optional, only for the features that use external programs (same as today, and the
modules page in `doc/modules_settings_plan.md` lists them with copyable commands):

| Feature | User action |
|---|---|
| Content search (ack) | `sudo apt install ack` |
| Auto-format C/C++/JS | `sudo apt install clang-format` (Ruby works out of the box: rufo is bundled) |
| Git diff | `git` (usually already installed) |
| Run line in terminal | `gnome-terminal` (until `cnf.terminal.command` exists) |
| LSP | Ruby: works out of the box with the bundled `ruby-lsp`. C/C++: `sudo apt install clangd` |
| Ollama, TTS, dictation modules | see each module's card (Ollama install + model; piper + voice; faster-whisper venv + ffmpeg) |

Everything else works without further steps: editing, highlighting, the file
panel, image display, audio playback (bundled GStreamer plugins) and the embedded
terminal (bundled VTE).

Updates: download the new AppImage, or use AppImageUpdate / a tool like Gear Lever,
which read the embedded zsync update info. An in-editor "new version available"
notice could come later.

### B. Flatpak (good second step, for Flathub)

- **Runtime**: `org.gnome.Platform` (current release) already contains GTK4,
  GtkSourceView 5, GStreamer and the typelibs. Check whether VTE (gtk4) is in the
  runtime; if not, add it as a manifest module.
- **Ruby** isn't in the GNOME SDK, so build it as a module. Gems become generated
  `sources` (flatpak-builder-tools has a RubyGems generator), since Flathub builds
  run offline.
- Can also be shipped as one file (`flatpak build-bundle` → `vimamsa.flatpak`), but
  the user needs Flatpak installed.
- **The problem for an editor is the sandbox.**
  - It needs `--filesystem=host` to edit arbitrary files.
  - Every external command (ack, git, clang-format, gnome-terminal, `bash -c` in
    auto_format, `command_to_buf`, LSP servers like clangd/solargraph, ollama,
    piper) would run *inside* the sandbox, where those tools don't exist.
  - The fix is a `host_cmd` wrapper that prefixes `flatpak-spawn --host` when
    `/.flatpak-info` exists, plus `--talk-name=org.freedesktop.Flatpak`. Flathub
    reviewers accept that for IDEs, but every `system` / `IO.popen` / backtick call
    site has to go through the wrapper.
- Upside: desktop integration and updates come free, and the size is small
  (shared runtime).

### C. Not recommended

- **Tebako / ruby-packer** (Ruby + gems in one executable): GTK4, the typelibs and
  GStreamer still have to be on the host, so the user still runs `apt install`. That
  only half solves the problem.
- **Snap**: similar sandbox problems to Flatpak (classic confinement needs a manual
  review), and Ubuntu-centric.
- **Docker**: not a desktop app.

## Optional: newer GTK, older glibc

`scripts/appimage/build.sh --gtk-new` builds a second, optional AppImage on Ubuntu
22.04 with GTK 4.22 built from source (`Dockerfile.gtk-new`, `build_gtk_stack.sh`):
`build/appimage-gtk-new/Vimamsa-<version>-gtk4.22-x86_64.AppImage`, needs glibc
≥ 2.35. The default build above is unchanged. Details, versions and what was found
while building: `doc/appimage_old_base_plan.md`.

## GTK version differences

The AppImage carries its own GTK, so users always run the **build host's** GTK version,
whatever their distro has. Development currently runs on **GTK 4.14.5 /
GtkSourceView 5.12** (Ubuntu 24.04). Ubuntu 22.04 would bundle **GTK 4.6 /
GtkSourceView 5.4**: two years and eight minor versions older. Problems, from most to
least likely:

1. **Behavior differs from what was developed and tested.**
   - API: a scan (2026-11-19) found none of the 4.10+ classes (`Gtk::FileDialog`,
     `AlertDialog`, `ColorDialog`, `UriLauncher`, …). The code uses the older
     `Gtk::FileChooserDialog` (`gui.rb`, `buffer.rb`, `gui_settings.rb`), so it
     should *load* on 4.6.
   - But many bugs were fixed between 4.6 and 4.14: popovers, clipboard (the editor
     already has a workaround for ruby-gnome#1609), TextView child anchors (used by
     the calculator, terminal and images), and focus/key handling. The editor
     depends heavily on key-event details.
   - The only reliable check is to **run the full test suite against the bundled
     libraries**, not the host's. That means running `exe/run_tests.rb` with the
     AppDir's Ruby and `GI_TYPELIB_PATH`/`LD_LIBRARY_PATH`, or inside the AppImage,
     on a clean VM.
2. **Visual and rendering differences.**
   - Fractional scaling (`wp_fractional_scale`) arrived in GTK 4.12. With 4.6,
     users on 125%/150% Wayland scaling get **blurry text**. For a text editor
     that's the most user-visible risk.
   - The renderers changed too (new GL/Vulkan renderers in 4.14), and so did font
     rendering (hinting and subpixel positioning in 4.16).
   - The built-in Adwaita theme (`gui.rb:619` forces it) looks different in each
     version.
   - CSS: `gui_theme.rb` and others load custom CSS. GTK 4.16 deprecated
     `@define-color` / named colors in favor of CSS variables. CSS written and
     tested on one version may render differently or warn on another. Keep the CSS
     to features that 4.6 supports and that 4.16+ hasn't deprecated, or check the
     version.
3. **GtkSourceView 5.4 vs 5.12.**
   - The markdown/markup styles (`def:heading`, `def:inline-code`, …, see the
     markdown item in `doc/TODO.md`) may differ or be missing in 5.4's `def.lang`
     / `markdown.lang`. Check before writing the overlay fix against 5.12.
   - The style schemes in `styles/` and the generated overlay use features of the
     `.xml` format. Check them on 5.4.
   - `XDG_DATA_DIRS` ends with the host's `/usr/share`. If a language-spec is
     missing from the bundle, the bundled (older) GtkSourceView can pick up the
     host's (newer) `.lang` file, which may use features it doesn't support. Bundle
     the complete `share/gtksourceview-5` so the bundled copies win.
4. **Mixing the bundled GTK with modules from the host.**
   - GTK loads plug-in modules from the host: input methods (IBus/Fcitx), GIO
     modules (gvfs for trash and remote locations in the file chooser), the dconf
     settings backend, and print backends. Modules built for the host's newer GTK
     can fail to load or **crash** the bundled older GTK.
   - The usual AppImage answer is to isolate them (`GTK_PATH`/`GIO_MODULE_DIR`
     pointing into the AppDir). But then users of IBus/Fcitx (CJK input) lose their
     input method, and get only GTK's built-in compose/dead-key handling. The editor
     relies on input-method commits for AltGr/dead keys (`gui_sourceview.rb`), so
     test this with a non-US keyboard layout.
   - Decide: bundle the gvfs/ibus GTK4 modules from the build host (matching
     version), or accept the limitation and document it.
5. **Typelib vs library mismatch.** If a typelib is missing from the bundle,
   GObject Introspection falls back to the host's
   `/usr/lib/*/girepository-1.0` typelib. That one describes a *different version*
   of the library than the bundled `.so`, which can cause wrong calls or crashes
   instead of a clean error. It's the same as the build-time problem above:
   bundle the complete set, and in the test run check that no typelib is loaded
   from the host (`GI_DEBUG`, `strace -e openat`).
6. **Host graphics stack.** libGL/Mesa/Vulkan come from the host (excludelist). A
   newer host Mesa may need a newer `libstdc++`/`libdrm` than the bundled ones, the
   classic AppImage "`GLIBCXX_3.4.xx` not found" error. Don't bundle `libstdc++` (or
   bundle it with a version check). As a fallback, AppRun can set
   `GSK_RENDERER=cairo` when GL initialization fails.
7. **Ruby-GNOME gems vs GTK version.** The gems (4.3.x) are compiled against the
   build host's headers, so they match the bundled GTK. That's fine as long as gems,
   typelibs and libraries all come from the same build host. Never reuse gems
   compiled on the development machine.
8. **Future: deprecations.** `Gtk::FileChooserDialog` and friends are deprecated
   since 4.10 and print warnings on newer GTK. They keep working in GTK 4, but are
   gone in GTK 5. Not urgent, but don't start new code on deprecated APIs.

**Recommendation.** The build host trades compatibility against matching the tested
version:

| Build host | GTK / GSV | Runs on (glibc) | Risk |
|---|---|---|---|
| Ubuntu 22.04 | 4.6 / 5.4 | 22.04+, Debian 12, Fedora 36+ | biggest gap to development; no fractional scaling |
| Debian 12 | 4.8 / 5.6 | Debian 12+, Ubuntu 22.10+, Fedora 37+ | still no fractional scaling |
| Ubuntu 24.04 | 4.14 / 5.12 | 24.04+, Debian 13, Fedora 40+ | matches development; narrower range |

**Decided (2026-11-19): build on Ubuntu 24.04**, so the bundle runs exactly the GTK
the editor is developed and tested with, and fractional scaling works. Ubuntu 22.04
users (still supported until 2027) use `gem install` or the later Flatpak, which always
ships a current GNOME runtime and avoids the whole GTK-version question. Revisit if
22.04-era users ask for the AppImage. Add a CI job that runs the test suite against the
bundled libraries.

## Running on non-Ubuntu distros

An AppImage isn't tied to Ubuntu. Everything that differs between distros (Ruby, gems,
GTK, GtkSourceView, VTE, GStreamer, typelibs, data files) is inside the file, so all
distros run the same editor code on the same libraries. What still comes from the host:

| From the host | Requirement / note |
|---|---|
| **glibc** | at least the build host's: **≥ 2.39** with Ubuntu 24.04. This decides which distros work (table below). |
| CPU | x86_64 (an arm64 build would be separate) |
| Kernel | any modern one. The static type-2 runtime needs no `libfuse2`. FUSE itself is in every desktop kernel. |
| Graphics | host Mesa / NVIDIA driver (`libGL`, `libEGL`, Vulkan). Works on any distro; see "Host graphics stack" above. |
| Fonts | host fontconfig and fonts. The default `cnf.font.family = "Monospace"` (`conf.rb:170`) resolves to each distro's monospace font (DejaVu Sans Mono, Noto Sans Mono, …), so it can look slightly different. The bundled Oxanium font is unaffected. |
| Audio | GStreamer's bundled `pulsesink`/`pulsesrc` talk to PipeWire (pipewire-pulse) or PulseAudio, which every current desktop distro provides |
| Desktop integration | `.desktop` file + icon in `~/.local/share` follow the freedesktop spec, so they work in GNOME, KDE, Xfce and others. `desktop_install.rb` already skips `gtk-update-icon-cache` / `update-desktop-database` when they're missing (`which` guards at lines 73, 77). |
| Wayland / X11 | GTK4 runs on all common compositors (GNOME, KDE, Sway, Hyprland) and on X11 |

### Which distros it runs on (glibc ≥ 2.39)

| Distro | glibc | Runs? |
|---|---|---|
| Ubuntu 24.04+, Linux Mint 22+, Pop!_OS 24.04, elementary OS 8, KDE neon (24.04 base) | 2.39+ | ✅ |
| Fedora 40+ | 2.39+ | ✅ |
| Debian 13 (trixie) | 2.41 | ✅ |
| Arch, Manjaro, EndeavourOS, openSUSE Tumbleweed, Gentoo, Void (glibc) | rolling | ✅ |
| openSUSE Leap 16 | 2.40 | ✅ |
| RHEL / Alma / Rocky 10 | 2.39 | ✅ |
| Fedora Silverblue / Kinoite, Bazzite (immutable) | 2.39+ | ✅ (AppImages suit immutable systems well; optional tools go through toolbox / distrobox) |
| WSL2 + WSLg with Ubuntu 24.04 | 2.39 | ✅ (not tested) |
| Ubuntu 22.04, Linux Mint 21, Zorin OS 17 | 2.35 | ❌ use `gem install` / Flatpak |
| Debian 12 (bookworm), ChromeOS Crostini (Debian 12) | 2.36 | ❌ |
| openSUSE Leap 15.6 | 2.38 | ❌ |
| RHEL / Alma / Rocky 9 | 2.34 | ❌ |
| NixOS | (no FHS) | ⚠️ needs `appimage-run` (or `programs.appimage.enable = true; binfmt = true;`) |
| Alpine, Void-musl, Chimera (musl libc) | — | ❌ glibc-only; would need the Flatpak |

On a too-old glibc the AppImage fails right at start with
`/lib/x86_64-linux-gnu/libc.so.6: version 'GLIBC_2.39' not found`. AppRun can't catch
this, because the bundled Ruby itself doesn't load. Mention it in the download
instructions (README: "requires glibc 2.39+: Ubuntu 24.04, Fedora 40, Debian 13 or
newer").

### Distro-specific issues inside the editor

These aren't about the AppImage itself; they're about the external tools it calls.
They need fixing for non-Ubuntu users regardless of how the editor is packaged:

1. **Hardcoded `gnome-terminal`** (`terminal.rb:22`): KDE (Konsole), Xfce
   (xfce4-terminal) and most non-GNOME setups don't have it, so "Execute line in
   terminal" fails silently there. Fix: a `cnf.terminal.command` setting, with
   auto-detection in order: `$TERMINAL`, `x-terminal-emulator` (Debian alternatives),
   `gnome-terminal`, `konsole`, `xfce4-terminal`, `kitty`, `alacritty`, `foot`,
   `wezterm`, `xterm`, each with its own "run this command" arguments. This is
   already noted in `doc/modules_settings_plan.md` ("Keep in core").
2. **Install commands on the modules page are `apt`-only.** Read `ID` / `ID_LIKE`
   from `/etc/os-release` and show the matching command. Package names also differ:

   | Tool | Debian/Ubuntu | Fedora | Arch | openSUSE |
   |---|---|---|---|---|
   | ack | `ack` | `ack` | `ack` | `ack` |
   | clang-format | `clang-format` | `clang-tools-extra` | `clang` | `clang-tools` |
   | clangd | `clangd` | `clang-tools-extra` | `clang` | `clang-tools` |
   | ffmpeg | `ffmpeg` | `ffmpeg-free` (or RPM Fusion `ffmpeg`) | `ffmpeg` | `ffmpeg` (Packman for full codecs) |
   | aplay | `alsa-utils` | `alsa-utils` | `alsa-utils` | `alsa-utils` |

   Verify these names when implementing. Fall back to the generic text
   ("install clang-format with your package manager") for unknown distros.
   Immutable distros need `toolbox`/`distrobox` or `rpm-ostree install`; show a hint
   when `/run/ostree-booted` exists.
3. **pip in a venv** (dictation, TTS) works the same on all distros. `python3 -m venv`
   needs `python3-venv` on Debian/Ubuntu only; other distros include it.

### Testing on other distros

- **CI smoke test matrix** in containers: `fedora:40`, `debian:trixie`, `archlinux`,
  `opensuse/tumbleweed`, `ubuntu:24.04`. Install only `xvfb` (and Mesa for software
  GL), then run `xvfb-run ./Vimamsa-x86_64.AppImage --appimage-extract-and-run --test <smoke test>`.
  Containers have no FUSE, hence `--appimage-extract-and-run`. Also add a
  `debian:bookworm` job that is *expected* to fail with the glibc error, so the
  minimum stays documented and tested.
- **By hand, once per release** on a real desktop: Fedora (GNOME, SELinux on), KDE
  (Kubuntu or Fedora KDE) for non-GNOME desktop integration, input methods and
  terminal detection, and Arch. A live USB or another VirtualBox VM next to the test VM
  is enough.

## Alternative: a newer GTK (Ubuntu 26.04's) in the bundle

Checked 2026-11-19 in an `ubuntu:26.04` container on the development machine (Ubuntu
24.04.5, glibc 2.39, GTK 4.14.5):

| | Ubuntu 24.04 (dev machine) | Ubuntu 26.04 |
|---|---|---|
| glibc | 2.39 | **2.43** |
| GTK | 4.14.5 | 4.22.4 |
| GtkSourceView | 5.12 | 5.18.0 |
| VTE (gtk4) | 0.76.0 | 0.84.0 |
| GLib | 2.80 | 2.88.0 |
| GStreamer | 1.24 | 1.28.2 |
| libgirepository-1.0 | yes | still shipped (1.86); 2.0 is in GLib 2.88 |

Both of the following can be done on the development machine with Docker (it's
installed), but they're very different.

**A. Build inside an `ubuntu:26.04` container.** Technically trivial: the same
build script with a different base image. But the AppImage then needs **glibc ≥ 2.43**.
It would *not* run on Ubuntu 24.04, the current LTS (including the development
machine itself), Debian 13 (2.41) or Fedora 43 (2.42). Only Ubuntu 26.04+, Fedora 44+
and the rolling distros could run it. **Not recommended** until 26.04-era distros are
the norm (about 2028).

**B. Build GTK 4.22 from source on top of the 24.04 base** (in a 24.04 container):
glibc stays 2.39 and compatibility stays the same, but the bundle gets the newer GTK
stack.
- Build into a prefix (e.g. `/opt/vma-gtk`) with meson, roughly in dependency order:
  - GLib 2.88 (+ girepository)
  - gobject-introspection 1.86
  - wayland-protocols
  - harfbuzz / pango / graphene / libepoxy as GTK 4.22 requires (check the minimum
    versions in its `meson.build`; 24.04's may be too old)
  - GTK 4.22
  - GtkSourceView 5.18
  - VTE 0.84 (C++20, gnutls, pcre2)

  GStreamer can stay at 24.04's 1.24.
- Then compile Ruby and the Ruby-GNOME gems against that prefix
  (`PKG_CONFIG_PATH=/opt/vma-gtk/lib/pkgconfig`), and point linuxdeploy at it.
- Use an existing build recipe rather than writing one: gnome-build-meta /
  BuildStream, or a jhbuild moduleset.
- Effort: **about 2–4 extra days**, plus ongoing upkeep (rebuild for security
  fixes, follow GTK's dependency bumps).
- Disk: about 10–15 GB for the build container. Check free space on the build
  machine first.
- Risks:
  - The bundled GLib (2.88) is newer than the host's on 24.04. Host GIO/GTK
    modules (gvfs, dconf, IBus) are built against the older GLib/GTK. The bundle
    isolates them anyway (see "GTK version differences" point 4), but it's one more
    thing to test.
  - Ruby-GNOME 4.3.x must work with GLib 2.88. GLib 2.80+ moved GIRepository
    into GLib (`girepository-2.0`). Check which one the gem links, and use a recent
    Ruby-GNOME release.

**Either way the test-coverage argument from "GTK version differences" applies in
reverse**: the editor is developed and tested on GTK 4.14, so a 4.22 bundle runs a GTK
nobody has tested it on. It's newer and has fewer bugs, but there are real behavior
changes:
- CSS: named colors are deprecated since 4.16
- new renderers and font rendering
- `FileChooserDialog` deprecation warnings
- GtkSourceView style changes

So the full test suite would have to run against the bundled 4.22 libraries in CI, and
ideally the development machine would move to the same GTK.

**Worth it?** GTK 4.14 already has fractional scaling, so 4.22 mainly brings
rendering and font polish, bug fixes, and GtkSourceView 5.18.

**Decided (2026-11-19): stay with the plain Ubuntu 24.04 build (system GTK 4.14) for
now.** Neither A nor B is planned. Reconsider only if a specific GTK bug or feature
needs a newer GTK; then use option B in a container, not option A. Look at it again
when the development machine moves to Ubuntu 26.04.

## Code changes needed regardless of format

1. **`exe/vimamsa` puts paths relative to the *current directory* on `$LOAD_PATH`:**
   `$LOAD_PATH.unshift(File.expand_path("lib"))` and the same for `"ext"` (lines 44-45).
   `scriptdir` is computed at line 9 and never used. From an AppImage, or when
   started from another directory, it would pick up a random `./lib` from wherever
   the user is. Use `File.join(scriptdir, "lib")`. This also affects running from
   source.
2. `lib/vimamsa.rb` adds `ext/stridx` to the load path, but that directory no longer
   exists. StrIdx now comes from the gem. Remove the dead line.
3. **`desktop_install.rb`** writes `Exec=vimamsa %F` (line 64), which only works when
   the gem's binstub is on PATH. When `ENV["APPIMAGE"]` is set, write
   `Exec="<$APPIMAGE>" %F` and refresh it if the AppImage has moved. (The
   install-only-when-changed logic is already there.) Flatpak installs its own
   desktop file, so skip this there.
4. **Read-only app directory**: an AppImage is mounted read-only. Checked: nothing
   writes through `ppath()` (generated styles go to `~/.config/vimamsa/styles`), so
   this is OK today. Add a test or a review rule to keep it that way. This ties in
   with the XDG item in `doc/TODO.md`.
5. **Runtime deps: keep `ruby-lsp` in the bundle for now** (decided 2026-11-19).
   It pulls in prism, rbs and sorbet-runtime (tens of MB), which is accepted. For it
   to be usable from the bundle:
   - AppRun puts `$APPDIR/usr/bin` on `PATH` and a `ruby-lsp` binstub there that
     uses the bundled Ruby, so a `cnf.lsp.server` command of `ruby-lsp` (not
     `bundle exec ruby-lsp` as in `custom_example.rb:94`) finds it. A built-in
     default server preset could point at it directly (see the LSP presets in
     `doc/modules_settings_plan.md`).
   - Caveat: in a project with a Gemfile, ruby-lsp builds a "composed bundle" using
     the *bundled* Ruby. If the project needs a different Ruby version, this can
     fail, and then the user's own `ruby-lsp` (configured in `cnf.lsp.server`)
     should be used instead. Mention this on the LSP module card.
   - Revisit trimming it if the AppImage size becomes a problem.
   Keep `rufo` too (small; makes Ruby auto-format work out of the box).
6. **Version check at startup**: the bundled GTK is the build host's version. Guard
   any newer GTK/GtkSourceView API use with `Gtk.check_version` (or keep the build
   host's GTK as the CI baseline so it's caught).
7. **Ruby version**: development is on 3.4. The gemspec doesn't say a version, so
   add `required_ruby_version`. CLAUDE.md says 3.0+, but the Dockerfile uses 3.1.

## Testing the bundle

- Smoke test in CI: `xvfb-run ./Vimamsa-x86_64.AppImage --version` (add the flag if
  it's missing), then start it, open a file and quit, using a `--test` run of one
  small built-in test file. Ship `tests/` inside the AppDir, or point `--test` at
  the checkout.
- Run it on a **clean** machine with no Ruby or GTK dev packages:
  - the test VM (`$VM_NAME`), restored to a snapshot taken before provisioning
  - Fedora / Debian 12 / Ubuntu 24.04 live images
- Check with `LD_DEBUG=libs` / `GI_DEBUG` that nothing loads from host `/usr/lib`
  except the excludelist.
- Check by hand: syntax highlighting (language-specs found), the file chooser
  (schemas), icons, audio playback (GStreamer plugins), the embedded terminal (VTE),
  single-instance forwarding (the `listen` gem / inotify), and the desktop launcher
  pointing at the AppImage.

## Effort estimate

| Step | Effort |
|---|---|
| Code changes 1–3, 5, 7 | small (about half a day) |
| Ruby + gems in an AppDir, typelibs and data, AppRun, working locally | 2–4 days. Most of it is finding all the typelib-reached libs and data paths. |
| CI job + release upload + clean-machine testing | 1–2 days |
| Flatpak (manifest, gem sources, `host_cmd` wrapper over all external commands) | 3–5 days more, plus Flathub review |

## Recommended order

1. Code changes 1–3, 5, 7 (useful on their own).
2. Choose the build host (see "GTK version differences"; proposed Ubuntu 24.04).
   If 22.04 is still wanted, run the test suite there first.
3. Write `scripts/build_appimage.sh` in a build-host container and get a working AppImage
   locally. Test it on the clean VM.
4. CI build on tags plus a GitHub release asset. Update README.md's install section
   ("Download the AppImage", with `gem install` as the alternative).
5. Later: Flatpak/Flathub, with the `host_cmd` wrapper.

## DONE

- **Code changes 1, 2, 3, 7** (2026-11-19, `24a1a88`): `exe/vimamsa` and
  `exe/run_tests.rb` load `lib/`/`ext/` next to the script; dead `ext/stridx` load
  path removed; the desktop launcher runs `$APPIMAGE` when set (quoted per the
  Desktop Entry spec); gemspec `required_ruby_version >= 3.1` (3.1 untested; the VM
  runs 3.2). Raised to `>= 3.2` on 2026-11-21 (`scan_indexes` uses
  `MatchData#byteoffset`). Tests: `tests/test_bundling.rb`. Code change 5 (the `ruby-lsp` binstub
  on PATH) belongs to AppRun, so it comes with `scripts/build_appimage.sh`.
- **AppImage build script** (2026-11-19, `bc43676`): `scripts/appimage/build.sh`
  (host, Docker) runs `scripts/appimage/build_in_container.sh` in the Ubuntu 24.04
  image from `scripts/appimage/Dockerfile`. Output:
  `build/appimage/Vimamsa-<version>-x86_64.AppImage`, **92 MB** (249 MB unpacked).
  Builds the committed `HEAD` (`VMA_REF` to change); Ruby and appimagetool are cached
  in `build/appimage/cache`, so a rebuild takes about 3 minutes.
  - Ruby 3.4.9 built with `--enable-load-relative`; gems installed with it.
  - Libraries: no linuxdeploy. The script seeds the list with `ruby`, every gem/stdlib
    `.so`, the GStreamer plugins, the gdk-pixbuf loaders, the dconf GIO module and the
    `.so` named in each typelib (read with `strings`), then follows `ldd` and copies
    everything except an excludelist (glibc, libstdc++, GL/DRM/Vulkan, X11/core
    xcb/Wayland client, fontconfig/freetype/harfbuzz, sound servers, zlib, expat).
    `patchelf` sets an `$ORIGIN` RUNPATH on every bundled ELF file, so **AppRun sets no
    `LD_LIBRARY_PATH`** and programs the editor starts don't load bundled libs. The
    build fails if any bundled file has an unresolved library.
  - All 56 typelibs of the build host are copied (2.9 MB).
  - `ruby-lsp` / `rufo` are reached through wrappers in `usr/lib/vimamsa/bin` on
    `PATH` (code change 5), not by putting the bundled `ruby` first on `PATH`.
  - Packed with appimagetool continuous (static type-2 runtime: no libfuse2 needed).
  - Tests:
    - Clean `ubuntu:24.04` container (no GTK, no Ruby, no typelibs; only the host
      libs a desktop has): `test_basic_editing.rb` 14/14 from the AppImage. Loaded
      from outside the image (`LD_DEBUG=libs`): only the excludelist and what the
      host's Mesa/harfbuzz pull in.
    - Test VM (`$VM_NAME`), real GNOME Wayland desktop, the AppImage itself (FUSE-mounted):
      full suite 390 passed, 1 failed (the known `TestDictation` failure), 6 skipped.
      The launcher becomes `Exec="<path to>/Vimamsa-x86_64.AppImage" %F`.

- **Started programs get the user's environment** (2026-11-19, `bc43676`): AppRun
  lists every variable it changes in `VMA_APPIMAGE_ENV` and keeps the old values in
  `VMA_HOST_<name>`. After startup, `restore_host_env` (`lib/vimamsa/appimage_env.rb`,
  called at the end of `Editor#start`) puts them back. GLib/GIO/GI keep what they read
  at startup. Before restoring, it initializes the parts that read their variables
  lazily: gdk-pixbuf loaders, the GSettings schema source, GIO modules, and GStreamer
  (loaded and `Gst.init`ed even when audio is off, so a module enabled later still
  finds the bundled plugins). The `ruby-lsp`/`rufo` wrappers unset `GEM_HOME` etc.
  themselves. `VMA_REF=WORKTREE` builds include uncommitted changes. VM, from the
  AppImage: 392 passed, 1 failed (`TestDictation`); `test_appimage_children_get_host_environment`
  checks that no variable except PATH/APPDIR/APPIMAGE points into the image and
  that VTE, `playbin`, pixbuf loading and `ruby-lsp` still work afterwards.

- **CI build and release** (2026-11-19, `1192898`): `.github/workflows/appimage.yml`. On
  a `vX.Y.Z` tag (must match `version.rb`) it builds with `scripts/appimage/build.sh`,
  runs `scripts/appimage/smoke_test.sh` (clean `ubuntu:24.04`: no GTK/Ruby, only the
  libraries a desktop has), signs a build provenance attestation and attaches
  `Vimamsa-x86_64.AppImage` + `.sha256` to the release. A fixed file name, so
  README links to `releases/latest/download/Vimamsa-x86_64.AppImage`. Run by hand,
  it only builds and tests (workflow artifact). appimagetool 1.9.1 and the type-2
  runtime 20251108 are pinned by SHA-256. The smoke test found that the MIME
  database must be bundled (gdk-pixbuf couldn't detect PNG without
  shared-mime-info). Not yet run on GitHub: the first tag push is its first run.

## Follow-ups found while building

- **GTK modules from the host**: `libgtk-4` still looks in the host's
  `/usr/lib/x86_64-linux-gnu/gtk-4.0/4.0.0` (print backends, media, IM modules). Fine
  on 24.04-era hosts; check on a newer distro.
- **GStreamer size**: all of plugins-base/good are bundled (12 MB plus their deps).
  Trimming to what playback/dictation need is possible later.
- **Gems are not pinned**: `gem install` resolves the newest matching versions
  (Ruby-GNOME 4.3.9 here). Use a lockfile for reproducible releases.
- Not tested yet: another distro (Fedora/Arch), X11 session, non-US keyboard/IME,
  HiDPI scaling.

