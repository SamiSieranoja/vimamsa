# Plan: registries for definitions that modules and custom.rb can change

TODO: not started. Act next on step 1 of "Implementation order".

## Context

Several definition tables are Ruby constants, so nothing loaded later can change
them. A module can't add a key binding category, a setting to an existing
Settings section, or a context menu item. `custom.rb` can't rename or remove a
built-in one. When a module needs something like this today, it gets a special
case in core code: `all_settings_defs` (`gui_settings.rb`) builds the "Modules"
section, and `key_binding_category` (`key_bindings_report.rb`) makes the
automatic `module:<name>` category.

What a module adds must also go away when it is disabled. Today every module
does that cleanup by hand in `<name>_disable` (color_highlight, tts, ollama,
terminal, calculator, dictation), with `unbindkey` / `unreg_act` calls that have
to match its init code.

## Which tables

Tables that something might reasonably want to change after they're defined:

| Kind | Table | File |
|---|---|---|
| list | `KEY_CATEGORIES` | `key_bindings_report.rb` |
| list | `BASIC_ACTIONS` | `key_bindings_report.rb` |
| list | `SETTINGS_DEFS` (sections and the settings in each) | `gui_settings.rb` |
| list | `CONTEXT_MENU_ITEMS`, `CONTEXT_MENU_ITEMS_SELECTION` | `gui_sourceview.rb` |
| map | `ACTION_NS_CATEGORY`, `KEY_WORD_CATEGORY`, `KEY_MODE_CATEGORY` | `key_bindings_report.rb` |
| map | `KEY_CONDITIONS`, `KEY_MODE_NAMES` | `key_bindings_report.rb` |
| map | `SHEBANG_LANGS` | `buffer.rb` |
| map | `MARKUP_OVERLAY_STYLES` | `gui_settings.rb` |
| map | `ACTION_ALIASES` | `actions.rb` |

Borderline, decide when they come up: `TEXT_OBJECT_BRACKETS`,
`THEME_COLOR_DEFAULTS` / `CYBER_COLOR_DEFAULTS`, `VIM_BINDINGS`.
`GUESS_ENCODING_ORDER` is a user choice and belongs in `cnf`.

These stay constants. They are fixed facts, not definitions: `VOWELS`,
`CONSONANTS`, the LSP kind numbers (`COMPLETION_KINDS`, `FUNCTION_KINDS`,
`CLASS_KINDS`), `LSP_LANG`, `VIM_CONFLICT_WHY`, `DEMO_FILES`, the GUI size
defaults.

## Design

### 1. `Registry`: ordered entries by id

A new `lib/vimamsa/registry.rb` (add it to `rbvma.rb`). One class serves both
lists and maps: entries are kept in insertion order and keyed by id, and each
entry has a value plus the owner that added it.

```ruby
r = vma.registry(:key_categories)

# one entry
r.add("ai", "AI assistant")

# several entries in one call: an Array of [id, value] pairs or a Hash
r.add([["ai", "AI assistant"], ["speech", "Speech"]])
vma.registry(:action_ns_category).add("ollama" => "ai", "tts" => "speech")

# entries whose value is a Hash of fields (settings, context menu)
vma.registry(:settings).add([:ollama, :model], section: "modules", label: "Model", type: :string)
vma.registry(:settings).add([
  [[:ollama, :model], { section: "modules", label: "Model", type: :string }],
  [[:ollama, :url],   { section: "modules", label: "Server URL", type: :string }],
])

r.remove("ai")             # also: r.remove(["ai", "speech"])
r.replace("ai", "AI")      # change the value and keep the position
r["ai"]                    # value, or nil
r.include?("ai")
r.each { |id, value| ... } # in order
r.ids, r.values, r.to_h
```

Rules:

- `add` with an existing id is an error that names both owners, so two modules
  don't overwrite each other without noticing. To change an entry on purpose,
  use `replace`, or `remove` and then `add`.
- A batch `add` checks every entry before adding any of them: either the whole
  batch goes in or nothing does.
- There are no ordering rules (`after:`/`before:`). Entries keep the order they
  were added in, so built-in entries come first and those from modules and
  custom.rb follow. Where position matters, a module reuses an existing entry
  instead (e.g. puts its bindings in the `code` category) rather than adding
  one.
- Values are stored as given; the registry doesn't copy or freeze them.

### 2. Built-ins use the same API

Each table keeps its literal data in the file where it's defined, as the
initial entries:

```ruby
define_registry(:key_categories, [
  ["motion", "Moving the cursor"],
  ["search", "Searching and jumping"],
  ...
])
```

`define_registry` creates the registry with owner `"core"`. Built-in entries
aren't special, so custom.rb can `replace` or `remove` them. Code that read the
constant reads the registry. During the conversion the constant can stay as an
alias (`KEY_CATEGORIES = ...` replaced by a method) only where outside code
might use it; the codebase itself is switched over in the same step.

`SETTINGS_DEFS` becomes two registries: `:settings_sections` (id → label) and
`:settings` (key → fields including `section:`). A module can then add a
setting to an existing section such as Font, not only to "Modules", and the
special case in `all_settings_defs` goes away: the module loader registers each
module's enable switch.

### 3. Owners, so disabling a module undoes it

Every `add` records the current owner, set the same way as
`KeyBindingTree#with_keywords`:

```ruby
with_owner("module:ollama") { ollama_init }  # done by the module loader
remove_owned("module:ollama")                # done by the loader on disable
```

- The loader already wraps module init (startup and Settings) and the three
  places custom.rb runs in `with_keywords`; the same places set the owner
  (`"module:<name>"`, `"custom"`). Outside them the owner is `"core"`.
- `remove_owned` removes that owner's entries from every registry, so modules
  write no cleanup for registry entries.
- Later (step 6) `reg_act` and `bindkey` record the owner too, and
  `remove_owned` also unregisters the actions and unbinds the keys. Then most
  `<name>_disable` functions become unnecessary; a module keeps one only for
  cleanup the registries don't know about (stopping a thread, closing a
  window).
- `r.owner(id)` returns who added an entry, for error messages and debugging.

### 4. Change listeners for consumers that cache

```ruby
vma.registry(:context_menu).on_change { |reg| ... }
```

runs after any `add`, `replace` or `remove` (once per batch call). Needed
where something is built once:

- the context menu creates its `Gio::SimpleAction`s in `init_context_menu`,
  at startup;
- the Settings dialog builds its widgets when it opens, so it only needs to
  rebuild if it's open.

The key bindings page reads the registries each time it's shown and needs no
listener.

### 5. `cnf` stays separate

`cnf` holds the values the user chooses; registries hold what exists to choose
from. A setting's definition (label, type, range, section) goes in the
`:settings` registry, and its value stays in `cnf`.

### 6. Discoverability

- `vma.registries` lists the registry names, so the command line can show
  them (`:vma.registries`), and `vma.registry(:x).to_h` shows the contents.
- An unknown name in `vma.registry(:x)` is an error with a did-you-mean
  suggestion (as for action ids), not a new empty registry, so a typo doesn't
  fail silently. Registries are created only by `define_registry`.
- `custom_example.rb` gets a short example: rename a key binding category,
  add a context menu item.

## Implementation order

1. `Registry`, `define_registry`, `vma.registry`, `with_owner` /
   `remove_owned`, `on_change`, with single and batch `add`/`remove`.
   Unit-style tests in `tests/test_registry.rb`: order, duplicate-id error with
   owners, all-or-nothing batch, owner removal, listener called once per
   batch, unknown-name error.
2. Convert the key bindings page tables (`KEY_CATEGORIES`, `BASIC_ACTIONS`,
   `ACTION_NS_CATEGORY`, `KEY_WORD_CATEGORY`, `KEY_MODE_CATEGORY`,
   `KEY_CONDITIONS`, `KEY_MODE_NAMES`). They are new and used in one file. The
   module loader sets the owner around module init and custom.rb. Test: a
   module-owned category appears on the page and disappears after
   `remove_owned`. `test_every_binding_has_a_category` keeps passing.
3. Context menu (`CONTEXT_MENU_ITEMS`, `CONTEXT_MENU_ITEMS_SELECTION`), with
   an `on_change` listener that creates the missing Gio actions. Test: an item
   added after startup shows up in the menu and runs its action.
4. `SETTINGS_DEFS` → `:settings_sections` + `:settings`; module enable
   switches registered by the loader; `all_settings_defs` reads the
   registries. Test: a module setting in an existing section is shown and
   saved.
5. `SHEBANG_LANGS`, `MARKUP_OVERLAY_STYLES`, `ACTION_ALIASES`.
6. Owner tags on `reg_act` and `bindkey`; `remove_owned` unregisters and
   unbinds them; remove the parts of `<name>_disable` that become
   unnecessary. Test per module: enable, disable, and no actions, bindings or
   registry entries of that module remain.

Run the full suite in the test VM after each step (`./run_tests_vm.rb`).

## DONE

(nothing yet)
