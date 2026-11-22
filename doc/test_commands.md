# Test commands

How to run the different kinds of tests, with a focus on the ones that a
plain `./run_tests_vm.rb` (no parameters) does **not** run.

## The default run

```sh
./run_tests_vm.rb
```

This syncs the working tree into the test VM (`$VM_NAME`) and runs
`ruby exe/run_tests.rb` without arguments on the VM's real desktop. That
runs every `tests/test_*.rb` file **except** the excluded ones listed below.
Some tests in the included files still skip themselves when an opt-in variable
or a tool is missing (see "Tests that skip in the default run").

Any arguments to `run_tests_vm.rb` go unchanged to `exe/run_tests.rb` inside
the guest, so every command below that uses `exe/run_tests.rb` also works
as `./run_tests_vm.rb <args>`. Run tests in the VM rather than locally where
you can.

### Argument forms (`exe/run_tests.rb`)

| Argument | Meaning |
|---|---|
| *(none)* | every `tests/test_*.rb` except the excluded files |
| `tests/test_foo.rb` | one file, by path |
| `foo` or `test_foo` | shorthand for `tests/test_foo.rb` |
| `foo,bar` | several files |
| `TestFoo` | only classes with that name (an argument starting with a capital letter) |
| `duration=N` | run time in seconds for `test_random_edit` |
| `ref=REF`, `runs=N` | comparison commit and run count for `test_perf_startup` |
| `--headless` | invisible display (see below) |

Naming a file explicitly bypasses the exclusion list, which is how the
excluded tests are run. An argument that is not recognized (for example a
mistyped file name) stops the run with exit code 2 instead of being ignored.
`ruby exe/run_tests.rb --help` lists all of this.

## Files excluded from the default run

These are listed in `excluded` in `exe/run_tests.rb` and run only when you
name them.

### Random edit stress test — `test_random_edit`

```sh
./run_tests_vm.rb test_random_edit                # 300 s (DURATION default)
./run_tests_vm.rb test_random_edit duration=60    # shorter run
```

This runs random safe editor actions (moves, deletes, undo/redo, paste, mode
switches, random inserts) for the given time. It fails if any action raises an
exception. It is excluded because of how long it runs.

### Alternative key-binding schemes — `test_vim_bindings`, `test_notepad_bindings`

```sh
./run_tests_vm.rb vim_bindings
./run_tests_vm.rb notepad_bindings
```

Each one loads a different binding scheme (`key_bindings_vim.rb` /
`key_bindings_notepad.rb`), and that permanently rebinds keys in the shared
test process. **Run each one by itself.** Don't combine them with each other
or with other files (`vim_bindings,undo`), or the files that run after them
will see the wrong bindings.

`test_vim_bindings` contains oracle tests. Each key sequence is replayed in a
real `nvim` or `vim` on the same text, and the two resulting buffers must
match. That needs `nvim` or `vim` on `PATH` (the VM provisioning installs
`vim`).

### Startup time regression — `test_perf_startup`

```sh
./run_tests_vm.rb perf_startup                    # vs the previous commit
./run_tests_vm.rb perf_startup ref=HEAD~10 runs=7 # vs another commit
```

This starts the editor several times at the current version and at `ref`
(default 5 runs each) and compares the fastest startups. It fails if the
current version is more than 25 % **and** more than 0.3 s slower. Without
`ref=` it compares against the previous commit, or against the current one
when `lib/`, `exe/` or `ext/` have uncommitted changes. It takes about a
minute, needs a display and a git checkout, and is excluded because of how
long it runs.

You can run the same check without the test runner:

```sh
ruby scripts/perf_compare.rb [--ref REF] [--runs N]
```

## Tests that skip in the default run

These files are part of the default run, but some of their tests skip unless
an environment variable is set or a tool is present. Skipped tests show up as
`SKIP:` lines under `Results:`.

### Keyboard E2E tests — `test_e2e_cmdline`, `test_e2e_replace_char`

These type real key events through a uinput virtual keyboard
(`tests/support/virtual_keyboard.rb`), so the editor window has to have focus
on a real Wayland seat. Wayland doesn't let a window launched through
`guestcontrol` take focus, so in the default VM run they wait 3 s and then skip
with "editor window is not focused".

To run them, use the semi-interactive wrapper:

```sh
./run_e2e_vm.sh                 # tests/test_e2e_cmdline.rb
./run_e2e_vm.sh e2e_replace_char
./run_e2e_vm.sh e2e_cmdline,e2e_replace_char
```

It sets `VMA_E2E_INTERACTIVE=1` and calls `run_tests_vm.rb`. When the prompt
`[E2E] Click the vimamsa window…` appears, click the editor window on the VM
desktop once, within 90 s. Every test after that finds the window already
focused.

Other requirements: writable `/dev/uinput` (the guest script sets it up on
every run), `xmodmap`, and the GTK Wayland backend. `test_e2e_replace_char`
also needs a keyboard layout with an `ä` key and skips without one. With
`--headless`, all of these tests always skip.

### Dictation E2E — `test_e2e_dictation`

```sh
VMA_E2E_DICTATION=1 ruby exe/run_tests.rb e2e_dictation
```

This one is opt-in. `run_tests_vm.rb` does **not** pass `VMA_E2E_DICTATION`
to the guest, so for now it runs only locally. The test uses a virtual
microphone (`tests/support/virtual_mic.rb`): it synthesizes a phrase with
`espeak-ng`/`espeak`, feeds it through the real GStreamer recorder and the
Whisper worker, and checks that the text arrives in the buffer. It needs
espeak and a Python that can `import faster_whisper`. The first run also
downloads the tiny Whisper model (~75 MB).

### Generated-doc check — `test_vim_conflicts`

```sh
VMA_UPDATE_DOC=1 ./run_tests_vm.rb vim_conflicts
# locally:
VMA_UPDATE_DOC=1 ruby exe/run_tests.rb --headless vim_conflicts
```

The default run only checks that `doc/vimlike_vim_conflicts.md` matches the
current bindings, and fails if the file is out of date. `VMA_UPDATE_DOC=1`
regenerates the file instead. In the VM, `run_tests_vm.rb` copies the
regenerated file back into the working tree (see `GENERATED_DOCS`). Commit
the result.

### Tool-dependent tests

These skip when a tool is missing:

| Test | Needs | In the VM |
|---|---|---|
| `test_lsp_clangd` | `clangd` or `clangd-N` on `PATH` | **not installed**: skips |
| `test_ack` | `ack` / `ack-grep` | installed |
| `test_text_objects`, `test_vim_operators` (real-vim comparison) | `vim` | installed |
| `test_file_format`, `test_diff_buffer_name` | `git`, `diff` | installed |

To run the clangd tests in the VM, install it once in the guest
(`sudo apt-get install clangd`), then run `./run_tests_vm.rb lsp_clangd`.

## Headless runs (local)

```sh
ruby exe/run_tests.rb --headless              # full default set
ruby exe/run_tests.rb --headless undo         # one file
```

The editor runs on an invisible display, so the run doesn't interfere with
your desktop. It uses `xvfb-run` if it's installed (a private X server per
run) and otherwise GTK's Broadway backend on display `:9`. Expect more skips
than in the VM:

- all keyboard E2E tests (no real seat)
- window-maximize tests in `test_window_layout` (no window manager)
- under Broadway only: `test_bracket_match` and `test_keylog_panel`, because
  nothing is drawn or laid out while no browser is connected. Install `xvfb`
  to avoid this.

Three `test_autocomplete` tests (tab/enter completion) are skipped on every
run, the VM included, because they were unreliable under headless GTK.

Tests never read or write your real `~/.config/vimamsa`. They use
`~/.config/vimamsa-test`, which you can override with `VMA_USER_DIR`.

## AppImage smoke test

This isn't part of any `run_tests` invocation. It builds the AppImage and runs
a few test files with it in a clean Ubuntu 24.04 Docker container, which has no
GTK and no Ruby:

```sh
scripts/appimage/build.sh                       # HEAD; VMA_REF=WORKTREE for uncommitted changes
scripts/appimage/smoke_test.sh build/appimage/Vimamsa-<version>-x86_64.AppImage
SMOKE_TESTS="tests/test_undo.rb" scripts/appimage/smoke_test.sh <AppImage>
```

By default it runs `test_basic_editing` and `test_bundling`. The test
`test_bundling#test_appimage_children_get_host_environment` runs only from
inside the AppImage, when `APPDIR` is set, and skips everywhere else.

## VM runner options

| Variable | Effect |
|---|---|
| `VM_NAME`, `VM_USER`, `VM_PASS` | required: VM name, guest user, guest password |
| `VM_DISPLAY` | guest X display (default `:0`) |
| `FORCE_PROVISION=1` | rerun the apt/gem provisioning in the guest |
| `VMA_UPDATE_DOC=1` | copy regenerated docs back from the guest |
| `VMA_E2E_INTERACTIVE=1` | interactive focus wait for E2E tests (set by `run_e2e_vm.sh`) |

## Summary: what the default `./run_tests_vm.rb` leaves out

| What | Command |
|---|---|
| Random edit stress | `./run_tests_vm.rb test_random_edit duration=60` |
| Vim scheme (+ vim oracle) | `./run_tests_vm.rb vim_bindings` |
| Notepad scheme | `./run_tests_vm.rb notepad_bindings` |
| Startup time regression | `./run_tests_vm.rb perf_startup` |
| Keyboard E2E | `./run_e2e_vm.sh` (click the window once) |
| Dictation E2E | `VMA_E2E_DICTATION=1 ruby exe/run_tests.rb e2e_dictation` (local) |
| Regenerate the vim-conflicts doc | `VMA_UPDATE_DOC=1 ./run_tests_vm.rb vim_conflicts` |
| clangd LSP | install `clangd` in the guest, then `./run_tests_vm.rb lsp_clangd` |
| AppImage | `scripts/appimage/build.sh` + `scripts/appimage/smoke_test.sh` |
