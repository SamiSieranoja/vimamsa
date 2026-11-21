# Plan: faster startup

TODO: not started. Act next on step 1 of "Implementation order".

## Context

Investigated 2026-11-21. Measured on the development machine, not the test VM: the VM
was at its login screen. The editor reached its first idle after about 2.6–3.0 s:
about 1.9 s loading code and about 0.9 s building the window and running `Editor#start`.
"Saves" below is the fastest of 5 runs, compared with the same version without the
change (`scripts/lib/perf_startup.rb`).

Tools:
- `ruby -r ./scripts/profile_startup.rb exe/vimamsa [file]` prints, at exit, the slow
  requires and the slow calls of vimamsa's own methods, as trees with start offsets
  and inclusive times. Method tracing starts once the code is loaded, so method times
  are a bit too high.
- `./run_tests_vm.rb perf_startup [ref=REF] [runs=N]` compares startup time with
  another commit. Use it to confirm each step.

## Where the time goes

| Part | Time |
|---|---|
| `require "colors"` (the red-colors gem, required by cairo) | 0.6–0.8 s |
| The GTK typelibs (gdk4, gio2, pango, gsk4, gtk4, gtksourceview5) | ≈0.9 s |
| Other Ruby requires (listen, openssl, vimamsa's own files) | ≈0.3 s |
| `@window.show` (first realize, renderer setup) | ≈0.2 s |
| Key bindings (`bind_vim_bindings`: `bind_template`, `vim_keys_taken?`) | 0.13–0.2 s |
| Opening the file (`gui_set_file_lang` 72 ms) | ≈0.11 s |
| GC: 27 runs (7 major), mostly marking the GObject wrappers | ≈0.3 s in total |

### What red-colors is

A color library from the Red Data Tools project. It has color models (RGB, HSL, HUSL,
XYZ, xyY, xterm256) with conversions, CSS/X11 color names, and the matplotlib and
seaborn colormaps (viridis, plasma, ...). When it is loaded,
`colors/colormap_data.rb` builds every colormap and a reversed copy of each:
thousands of `Colors::RGB` objects, many from Rationals. That is the slow part.

cairo loads it in `cairo/color.rb` only for `Cairo::Color.parse`, to turn a color
*name* into RGB. Hex strings and arrays don't need it. Vimamsa uses no colormaps.

## Changes

### Worth doing

1. **Load red-colors only when it is used.** A shim `colors.rb` (e.g.
   `lib/vimamsa/lazy/colors.rb`) does
   `Object.autoload(:Colors, File.join(Gem::Specification.find_by_name("red-colors").full_gem_path, "lib/colors.rb"))`.
   Put its dir first on `$LOAD_PATH` only around `require "gtk4"` in `rbvma.rb`, so
   cairo's `require "colors"` gets the shim. If the gem spec can't be found (e.g. the
   AppImage), skip the shim and load normally. Checked: `Cairo::Color.parse("red")`
   and `"#ff0000"` still work. **Saves ≈0.5 s** (3.00 → 2.49 s).
2. **GC off during startup.** `GC.disable` at the top of `exe/vimamsa`, and
   `GC.enable` in the first idle after `Editor#start`. Peak memory is about 80 MB
   higher until then. **Saves ≈0.24 s.** A larger initial heap
   (`RUBY_GC_HEAP_*_INIT_SLOTS`) saved ≈0.1 s, but it must be set before Ruby
   starts.
3. **Load openssl only when it is needed.** `buffer.rb:5` requires `openssl` but
   doesn't use it. `encrypt.rb` needs it only when a file is actually encrypted or
   decrypted: require it inside those methods. Saves ≈0.05 s.
4. **Remove `sleep(0.03)` in `Editor#start`** (`editor.rb:191`). Saves 0.03 s.
5. **Start the `listen` file listener after the window is up** (an idle after
   startup), or replace it with a GLib file monitor (`Gio::File#monitor_directory`).
   Requiring it loads rb-inotify and ffi. Saves ≈0.08–0.15 s.
6. **Reuse one `GtkSource::LanguageManager`.** `gui_set_file_lang` (`gui.rb:142`)
   creates a new one on every call, which rescans the language files (72 ms). This
   saves time for each extra file opened at startup and for every later file open.
7. **Generate the style scheme once.** `load_vimamsa_scheme` and
   `gui_apply_color_mode` run for each buffer and again in `gui_refresh_colors`:
   three times at startup. Saves ≈0.04 s.

### Possible, smaller or with trade-offs

- Optimize binding the key templates (`bind_template`, `vim_keys_taken?`): 0.1–0.2 s.
- Cache compiled Ruby code (as bootsnap does): compiling vimamsa's files takes ≈0.09 s
  and loading them from binary ≈0.015 s, so at most ≈0.1 s. It adds complexity.
- `GSK_RENDERER=cairo` starts ≈0.18 s faster, but drawing is likely slower. Don't
  make it the default.

### Not worth it

- YJIT (`--yjit`): ≈0.35 s slower.
- `GSK_RENDERER=gl` / `vulkan`: 0.1–0.4 s slower than the default (ngl).
- The rest (the GTK typelibs and the first draw) can't be avoided from Ruby.

## Implementation order

1. Items 1–4. Confirm the gain with `./run_tests_vm.rb perf_startup ref=HEAD`, and
   run the full suite in the VM.
2. Items 5–7.
3. Optionally, the key template binding.

## DONE

(nothing yet)
