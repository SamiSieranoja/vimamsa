# Modules page: move module toggles out of Preferences into Settings ▸ Modules

## Context

Module toggles currently live on the **Modules** tab of Settings ▸ Preferences. They're
built by `all_settings_defs` (`gui_settings.rb`), which scans `modules/*/` and calls
`<name>_info` for each. Each toggle is just a label with a switch. The user doesn't learn
what the module does or what it needs installed, so they can enable TTS or dictation and
get only a runtime error like "TTS: need 'piper' and 'aplay' on PATH".

Goal:
1. A separate **Settings ▸ Modules...** menu item with its own dialog. The Modules tab
   is removed from Preferences.
2. Each module shows **what it does** and **what the user has to do** to make it work
   (apt/pip installs, model downloads, a running service).
3. **Experimental modules** (Embedded Terminal, Scientific Calculator) go in their own
   section, apart from the stable ones.

## Current state (verified)

- `lib/vimamsa/gui_settings.rb`
  - `all_settings_defs` returns `SETTINGS_DEFS` plus a generated `"Modules"` section
    (keys `[:modules, <name>, :enabled]`, `:no_restart` taken from info).
  - `SettingsDialog#activate_no_restart_modules` loads the module and calls
    `<name>_init` / `<name>_disable` when a switch changes with `no_restart: true`.
- `modules/<name>/<name>_info.rb` only returns `{ name:, no_restart: }`. All 6 modules
  are `no_restart: true`.
- Startup loading: `editor.rb:229-243` (stays as it is).
- `gui_menu.rb:46` `Settings.Preferences` → `:show_settings` (`key_actions.rb:33`).
- There is already a top-level **Modules** menu (`Menu#add_module_action`) that holds
  module *actions* such as "Insert Calculator". It is separate from this work but has
  the same name (see open question 1).
- Tests that depend on the Modules section being inside `all_settings_defs`:
  - `tests/test_module_interface.rb:79-97` (3 tests)
  - `tests/test_color_highlight.rb:86-91` (`test_setting_exposed`)
  - `tests/test_tts.rb`, `tests/test_dictation.rb` check `_info` structure (still valid,
    will be extended).

## Design

### 1. Extend the `<name>_info` contract

The new keys are optional, so modules without them still work:

```ruby
def tts_info
  {
    name: "Text to Speech",
    no_restart: true,
    experimental: false,
    description: "Reads the selection or current line aloud using Piper neural TTS.",
    requirements: [
      { text: "Piper TTS engine",       cmd: "pip install piper-tts",        check: proc { which("piper") } },
      { text: "aplay (ALSA utils)",     cmd: "sudo apt install alsa-utils",  check: proc { which("aplay") } },
      { text: "A Piper voice in ~/piper-voices (default en_GB-alan-medium)",
        check: proc { Dir.exist?(File.expand_path(cnf.tts.data_dir! || "~/piper-voices")) } },
    ],
    usage: "Key bindings: … (filled in from the module's add_keys)",
  }
end
```

- `description`: one or two sentences.
- `requirements`: an array of `{ text:, cmd: (optional), check: (optional proc → bool) }`.
  An empty or missing array is displayed as "No extra setup needed".
- `check` lets the dialog mark each requirement ✓ found / ✗ missing. Checks must be
  cheap (`which`, `File.exist?`, at most a fast `require` probe). No network calls.
  Ollama is the exception: it's reported as "not checked" rather than pinging the port
  while the dialog opens.
- `experimental: true` puts the module in the Experimental section.

### 2. Per-module content and concrete setup actions

This section is the text that goes into each `_info.rb` and onto the dialog. It also
lists the **in-app setup actions**: buttons on a module's card that do a setup step for
the user, so they don't have to look it up.

The dialog supports three kinds of action:
- **copy**: copy a shell command to the clipboard, for anything that needs `sudo` or a
  long download. Nothing privileged ever runs from inside the editor.
- **run**: run a command that needs no `sudo` in the external terminal
  (`exec_in_terminal`), so the user sees its progress and output. One example is
  `ollama pull`.
- **config**: write a `cnf.*` value, for example a detected path.

So in `_info`, a requirement or action entry can look like
`{ text:, cmd:, kind: :copy | :run | :config, check: }`.

Ubuntu 23.04+ blocks a system-wide `pip install` (PEP 668). Python dependencies
therefore get a vimamsa-owned venv at `~/.local/share/vimamsa/venv`, and the dialog's **run**
action creates it. This affects dictation and TTS.

Exact package names and commands below are best-effort. Verify them on the clean
test VM (`$VM_NAME`) while implementing (see the last implementation step).

#### Configuration info on the module page

Each module's card also lists its **settings**, meaning the `cnf.*` keys a user can set
in `~/.vimamsa/custom.rb` (or `settings.rb`). For now that information lives only in
the comments at the top of the source files, such as `dictation.rb:24-41` and
`tts.rb:15-17`.

- New `_info` key `config:`, an array of
  `{ key: "dictation.model", default: "large-v3", desc: "faster-whisper model (tiny…large-v3)" }`.
  The module's own code still applies the defaults (`cnf.x! || default`). `default:`
  is there for display only.
- The card has a collapsible **"Settings (custom.rb)"** section (`Gtk::Expander`,
  collapsed by default). It's a small grid with one row per key: `cnf.<key>` in
  monospace, then the current value (`cnf_get`, shown dim when unset, with
  "(default: …)"), then the description.
- Below the grid:
  - **Copy snippet** puts a ready-to-paste block on the clipboard, one
    `# cnf.<key> = <default>  # <desc>` line per setting.
  - **Open custom.rb** reuses the existing `:edit_customrb` action and closes the
    dialog.
- The values are read-only on the page. Editing them in the dialog is a possible
  follow-up. Read-only avoids a second, half-complete settings editor, and custom.rb
  remains the single place where these values are written.
- The header comments in each module file are kept short. They point to `_info` as the
  canonical list, so the two don't drift apart.
- Test: every `cnf.<module>.*` key read in a module's `.rb` (grep for
  `cnf\.<name>\.[a-z_]+`) is listed in its `config:`. This catches undocumented
  settings.

Settings per module, taken from the code:

| Module | Settings (`cnf.` prefix) |
|---|---|
| dictation | `dictation.python` ("python3"), `.worker` (bundled whisper_worker.py), `.model` ("large-v3"), `.language` ("en"), `.device` ("auto"), `.compute_type` ("float16"), `.normalize` (true), `.initial_prompt` (none), `.chunk_secs` (4), `.idle_timeout` (300), `.startup_timeout` (600), `.source` ("autoaudiosrc") |
| ollama | `ollama.model` ("qwen3.5:0.8b"), `.host` ("localhost"), `.port` (11434), `.timeout` (60), `.multi_temperature` (1.2) |
| tts | `tts.voice` ("en_GB-alan-medium"), `.data_dir` ("~/piper-voices"), `.rate` (taken from the voice's .json, else 22050), plus the new `.piper` path |
| color_highlight, calculator, terminal | none apart from the enable switch |
| ack (extracted) | `default_search_extensions` (shared with the search form). Rename it to `ack.extensions`, keeping the old key as a fallback. |
| auto_format (extracted) | `auto_format.formatters`, a hash `filetype → {cmd:, mode: :stdout/:inplace, ext:, ignore_exit_code:}`. The card shows the configured formatters, and the snippet includes the rubocop example from `conf.rb:190`. |
| audio (extracted) | none today |
| lsp (extracted) | `lsp.server.<name> = {name:, command:, type:, languages:}`, `workspace_folders`, `autocomplete.lsp.enabled`, `autocomplete.lsp.debounce`. The snippet is the solargraph/ruby-lsp/clangd block from `custom_example.rb:89-99`. |

#### Stable modules

**color_highlight — Hex Color Highlight** (default: on)
- Does: paints `#RGB` / `#RRGGBB` / `#RRGGBBAA` codes in any file with their own color.
- Requires: nothing. Toggle: `C , ; h c`.

**dictation — Voice Dictation**
- Does: records from the microphone. faster-whisper transcribes the audio and the text
  is inserted at the cursor. A quick draft appears while recording and the final pass
  replaces it.
- Requires and checks:
  - ffmpeg: `sudo apt install ffmpeg` (copy). Check: `which("ffmpeg")`.
  - GStreamer mic source: `sudo apt install gstreamer1.0-plugins-good gstreamer1.0-pulseaudio`
    (copy). Check: `Gst::ElementFactory.find("autoaudiosrc")`.
  - faster-whisper: **run**
    `python3 -m venv ~/.local/share/vimamsa/venv && ~/.local/share/vimamsa/venv/bin/pip install faster-whisper`,
    then **config** `cnf.dictation.python = "~/.local/share/vimamsa/venv/bin/python"`.
    Check: `<python> -c "import faster_whisper"`. Run this check only when the user
    presses "Check", because it takes about 1 s.
- Notes on the card:
  - The first use downloads the model (default `large-v3`, about 3 GB).
  - Without an NVIDIA GPU, use a smaller model. A "CPU mode" **config** button sets
    `cnf.dictation.device = "cpu"`, `compute_type = "int8"` and `model = "small"`.

**ollama — Ollama**
- Does: rewrites or improves the selected text with a local LLM. `V , o i` makes one
  rewrite; `V , o N i` makes N alternatives.
- Requires and checks:
  - Ollama: `curl -fsSL https://ollama.com/install.sh | sh` (copy). Check: `which("ollama")`.
  - The model: **run** `ollama pull qwen3.5:0.8b`, or whatever `cnf.ollama.model` is set to.
  - The server running: a "Test connection" button does a short GET of `/api/tags` on
    `cnf.ollama.host:port`, with a 1 s timeout, only when pressed.

**tts — Text to Speech**
- Does: reads the selection or current line aloud using a Piper neural voice.
- Requires and checks:
  - piper: **run** `python3 -m venv ~/.local/share/vimamsa/venv && ~/.local/share/vimamsa/venv/bin/pip install piper-tts`,
    then **config** to point the module at `~/.local/share/vimamsa/venv/bin/piper`. This needs a new
    `cnf.tts.piper` setting, because today the module looks for `piper` on PATH.
    Check: the binary exists.
  - aplay: `sudo apt install alsa-utils` (copy). Check: `which("aplay")`.
  - A voice: **run**
    `~/.local/share/vimamsa/venv/bin/python -m piper.download_voices en_GB-alan-medium --data-dir ~/piper-voices`.
    Check: `<data_dir>/<voice>.onnx` exists.

#### Experimental modules

**terminal — Embedded Terminal (VTE)**
- Does: embeds an interactive shell widget inside a buffer.
- Requires: the VTE GTK4 introspection data, `sudo apt install gir1.2-vte-3.91` (copy).
  The `vte4` gem is already a runtime dependency in the gemspec.
  Check: `require "vte4"` inside `begin/rescue LoadError`.

**calculator — Scientific Calculator**
- Does: inserts an inline calculator widget at the cursor (Modules ▸ Insert Calculator).
  ↩ inserts the result.
- Requires: nothing.

For the modules extracted in section 7 below, the entries are listed there.

During implementation, read each module's header comment and `_init` to get the exact
bindings, actions and `cnf.*` settings. Copy them into `usage:` instead of guessing.

### 3. Shared module helpers (`gui_settings.rb`, or a new `lib/vimamsa/modules_info.rb`)

Pull the scanning code out of `all_settings_defs`:

- `module_infos` → array of `{ dir:, id: "tts", info: {...}, key: [:modules, :tts, :enabled] }`,
  sorted by name, with defaults filled in (`name` from the directory name,
  `no_restart: false`, `experimental: false`, `requirements: []`).
- `module_set_enabled(id, enabled, was_enabled)`: the load + `_init` / `_disable` logic
  moved out of `SettingsDialog#activate_no_restart_modules`, so the new dialog can use
  it (and the tests can call it directly).
- `all_settings_defs` → returns only `SETTINGS_DEFS`. It can be inlined or kept as an
  alias. Keeping it is less churn for the two tests that use it for non-module keys
  (`test_autocomplete.rb:194`).

If a new file is created, add `require "vimamsa/modules_info"` to `rbvma.rb`.

### 4. New `ModulesDialog` (`lib/vimamsa/gui_modules.rb`, required in `rbvma.rb`)

- `make_modal_window("Modules")` with a vertical box inside a `Gtk::ScrolledWindow`
  (6+ cards won't fit otherwise). Default size about 600×600.
- Two headings: **Modules** and **Experimental modules**. Under the experimental
  heading, a short dim note: "May be unstable or incomplete."
- One card per module (`Gtk::Frame`, using the existing `margin=` monkeypatch):
  - Row 1: bold name + `Gtk::Switch` aligned right (+ "(requires restart)" if
    `!no_restart`).
  - Description label (`wrap = true`, `xalign = 0`).
  - "Requires:" list with one line per requirement: ✓/✗ marker, text, and the command
    in monospace, `selectable = true` so it can be copied. Optionally a small "Copy"
    button that puts `cmd` on the clipboard through the existing clipboard helper.
    With no requirements: "No extra setup needed."
  - `usage` line, dim, if present.
- Buttons: Cancel / Save, as in Preferences. On Save: `cnf_set` each switch, run
  `save_settings_to_file`, then `module_set_enabled` for every switch that changed.
  The modal style and Save behavior match Preferences.
- When a module is switched on and its checks report something missing, it's still
  enabled, and a `message("TTS enabled — missing: piper")` explains what's missing.
  This doesn't block anything.
- `on_submit_escape(@window, escape: …)` as in `SettingsDialog`.

### 5. Wiring

- `key_actions.rb`: `reg_act(:show_modules, proc { show_modules_dialog }, "Show modules")`.
- `gui_menu.rb`: `add_to_menu "Settings.Modules", { :label => "Modules...", :action => :show_modules }`
  directly below Preferences.
- `SettingsDialog`: remove `activate_no_restart_modules` and the `:no_restart` /
  `:prev_value` code that only existed for the module tab.
- Update the comments that point to the old place: `modules/calculator/calculator.rb:3`
  ("Preferences → Modules"), `modules/color_highlight/color_highlight.rb:7`, and any
  others found by `grep -rn "Modules" modules lib README.md`.

### 6. Tests

Update:
- `test_module_interface.rb`: switch the 3 `all_settings_defs` tests to `module_infos`.
  Add an assertion that `all_settings_defs` no longer contains a `"Modules"` section.
- `test_color_highlight.rb#test_setting_exposed`: check `module_infos` instead.

Add (`tests/test_modules_dialog.rb`):
- Every module's info has a non-empty `:description`, and `:requirements` is an Array.
- `calculator` and `terminal` are `experimental: true`; the others are not.
- `ModulesDialog.new` builds without error and produces one switch per module, split
  into the two sections.
- Toggling calculator on in the dialog and pressing Save registers `:insert_calculator`;
  toggling it off unregisters it. This replaces the coverage the old
  `activate_no_restart_modules` path had.
- `:show_modules` is registered and in the Settings menu.

Run the full suite in the test VM (`./run_tests_vm.rb`, VM from `$VM_NAME`), not just the touched files.

### 7. Core features to turn into modules

I surveyed `lib/vimamsa/*` for features that call external programs, pull in an
optional gem/library, or are already behind an on/off flag. Each candidate gets a
verdict below.

**General rules for an extraction:**
- Move the code to `modules/<name>/<name>.rb` and drop its `require` from `rbvma.rb` /
  `editor.rb`.
- Add `<name>_info.rb`.
- Move its `reg_act`s, bindings and menu entries into `<name>_init`, and undo them in
  `<name>_disable`.
- Bindings for all three schemes (vimlike, vim, notepad) move into `_init`. The init
  code checks `cnf.keybindings.scheme` if they differ.
- **Keep current behavior by default.** Features that are on today get
  `cnf.modules.<name>.enabled = true` in `conf.rb`, the same way color_highlight does.
- Old flags (`cnf.audio.enabled`, `cnf.lsp.enabled`) are mapped to the new key once,
  after custom.rb phase 1, so existing user configs keep working.

#### Extract (recommended)

**A. ack — Content Search (ack)**
- Code: `ack.rb` (204 lines, `FileContentSearch` + `Ack`), `:ack_search` in
  `key_actions.rb:124,151` (registered twice, so one copy can go), `C , a` in
  `key_bindings_vimlike.rb:336`, and the commented-out menu entry `gui_menu.rb:89`.
- Why: hard dependency on the external `ack` binary. Today, with ack missing, the search
  just returns nothing. Self-contained, with one entry point.
- Default: on. Stable.
- Does: searches file contents (`C , a`) in the project directory, that is, the nearest
  parent directory containing `.git` / `.vma_project`. Results are grouped by folder
  and you can jump to them.
- Requires:
  - `sudo apt install ack` (copy). The package is `ack` on current Ubuntu; `ack-grep` is
    the old name, and README.md:59 needs fixing.
  - Check: `which("ack")`.
- Tests: `tests/test_ack.rb` loads or enables the module in setup.
- Effort: small. This makes it the pilot extraction that proves out the pattern.

**B. auto_format — Auto Format**
- Code: `Buffer#auto_format` (`buffer_changetext.rb:42-88`), which already has a
  `# TODO: rename ot auto-format. separate module?` comment, plus
  `cnf.auto_format.formatters` (`conf.rb:190-197`), `:auto_indent_buffer`
  (`key_actions.rb:208`) and `C , v`.
- Why: every formatter is an external program, and the feature is self-contained.
- Default: on. Stable.
- Does: reformats the whole buffer with the formatter set for its file type (`C , v`).
- Requires: one entry for each formatter configured in `cnf.auto_format.formatters`,
  generated from the first word of its `cmd`:
  - clang-format (C, C++, JavaScript): `sudo apt install clang-format` (copy).
    Check: `which`.
  - rufo (Ruby): `gem install rufo` (copy, no sudo needed for a user gem dir).
    Check: `which`.
- `Buffer#auto_format` stays as a thin method that calls the module, or `:auto_indent_buffer`
  calls a module function directly. Pick whichever keeps `tests/test_auto_format.rb`
  unchanged.
- Effort: small.

**C. audio — Audio Playback**
- Code: `audio.rb` (GStreamer `Audio` class), loaded by `editor.rb:218-220` behind
  `cnf.audio.enabled`. Used by `⟦audio:path⟧` links in `hyper_plain_text.rb:31` and by
  the `audio` minor mode plus bindings in `key_bindings_vimlike.rb:8,412,430-438` and
  `key_bindings_vim.rb:22,346-350`. The vim file's comment already calls it "the audio
  module".
- Why: it's already opt-in, already described as a module, and needs GStreamer codecs.
- Default: off. Stable.
- Does: plays audio files linked from text as `⟦audio:file.mp3⟧`. Audio mode
  (`C , m a`): `f`/`←` seek, `space`/`s` stop.
- Requires:
  - `sudo apt install gstreamer1.0-plugins-good gstreamer1.0-libav` for mp3 and other
    codecs (copy).
  - Check: `Gst::ElementFactory.find("playbin")`.
- Migration: map `cnf.audio.enabled` to `cnf.modules.audio.enabled`.
- `hyper_plain_text.rb` needs a guard: `defined?(Audio)` / `respond_to?`. A hook would be
  cleaner (see color_highlight's `:view_*` hooks).
- Effort: small to medium, because of the minor-mode bindings.

**D. lsp — Language Server (LSP)**
- Code:
  - `langservp.rb` (564 lines) and `gui_func_panel.rb` (172).
  - Startup in `editor.rb:222-227`.
  - LSP calls spread through `buffer.rb`, `gui_sourceview.rb` and
    `gui_sourceview_autocomplete.rb`.
  - Menu entries `View.FuncPanel` / `Actions.LspRestart`.
  - Setup through `cnf.lsp.server.*` in custom.rb (`custom_example.rb:89-99`).
- Why: it's the biggest optional feature, already off by default, and needs external
  servers. Setup is also the hardest part for users today: they must find and uncomment
  config in custom.rb.
- Default: off. Stable.
- Does: jump to definition, a symbol/function panel and completion candidates, using a
  language server for each language.
- Requires, one entry per known server:
  - Ruby, solargraph: `gem install solargraph` (copy). Check: `which("solargraph")`.
  - Ruby, ruby-lsp, as an alternative: `gem install ruby-lsp`.
  - C/C++, clangd: `sudo apt install clangd` (copy). Check: `which("clangd")`.
    The card also notes that clangd needs `compile_commands.json` or
    `compile_flags.txt` in the project.
- Concrete simplification, **config**: built-in default `cnf.lsp.server` presets. When a
  language has no server configured, `lsp_init` uses the first one found on PATH
  (solargraph, ruby-lsp, clangd). Enabling the module then just works, with no
  custom.rb edit. The card shows which server was picked for each language.
- Risk: the buffer, sourceview and autocomplete code calls into LSP directly. Those call
  sites need nil-safe guards or hooks first. This one is a **refactor**, not a move.
- Migration: map `cnf.lsp.enabled` to `cnf.modules.lsp.enabled`. Keep the LSP tests
  (`test_lsp_*.rb`) enabling it explicitly.
- Effort: large. Do it last, as its own commit series.

#### Keep in core (not worth a module)

- **Encryption** (`encrypt.rb`): no external deps (stdlib `openssl`). It's built into the
  file open/save path (`editor.rb:648,717`, `buffer.rb:2008`). If it were disabled,
  encrypted files would open as unreadable data and might be saved over. It has to stay
  in core.
- **Diff / git diff** (`diff_buffer.rb`): needs only `diff`/`git`, which are almost
  always installed and already checked with `if_cmd_exists`. Keep it. The card text
  could still list it under core features, which is optional.
- **Grep lines** (`search_replace.rb`, `Grep`): pure Ruby, core navigation. This is a
  different feature from ack.
- **Run line in external terminal** (`terminal.rb#exec_in_terminal`): small. Its only
  problem is the hardcoded `gnome-terminal`. Leave it in core and add a
  `cnf.terminal.command` setting (out of scope here; noted as a follow-up). It must not
  be mixed up with the embedded VTE `terminal` module.
- **Image display** (`gui_image.rb`), **xdg-open**, **desktop_install**: no optional
  deps, or deps that are always present.
- `xclip` (`buffer_changetext.rb:104`): it belongs to a workaround that's commented out
  and never called. Nothing to do.

#### Resulting module list

- **Stable:** ack (on), auto_format (on), color_highlight (on), audio, dictation, lsp,
  ollama, tts.
- **Experimental:** terminal, calculator.

## Implementation order

1. `module_infos` + `module_set_enabled`, and remove the Modules tab from Preferences.
   Update the existing tests. Suite green.
2. Extend the 6 existing `_info.rb` files with description / requirements /
   experimental / usage / config.
3. `ModulesDialog`, menu item, action, and copy/run/config setup buttons and checks.
4. Extract **ack** (pilot), then **auto_format**, then **audio**: one commit each, full
   suite after each.
5. Shared `~/.local/share/vimamsa/venv` setup and the `cnf.tts.piper` setting.
6. Fix README.md "optional features" so it points to Settings ▸ Modules (and `ack`, not
   `ack-grep`).
7. On a fresh snapshot of the test VM, follow every card's steps literally. Fix any command
   that's wrong.
8. **LSP** extraction plus presets, as a separate follow-up series.

## Open questions

1. **Naming clash**: the top-level **Modules** menu (module actions like "Insert
   Calculator") and the new Settings ▸ Modules page. Keep both as they are (proposed),
   or rename the top-level menu to something like "Tools"?
2. Should experimental modules be hidden or disabled unless the existing
   `cnf.experimental` ("Enable experimental features") is on? Proposed: no. They're
   always visible in their own section, and `cnf.experimental` stays as it is.
3. Apply switches immediately (no Save button) instead of Save/Cancel? Proposed:
   Save/Cancel, to match Preferences.
4. Should the **run** setup actions (venv + pip install, `ollama pull`, voice download)
   be offered at all, or should every action be copy-only? Proposed: offer them. They
   need no sudo and run visibly in a terminal.
5. Should LSP be extracted now, or is it enough to add server auto-detection presets
   and leave it in core? Proposed: presets first (that's what helps users most),
   extraction later.
