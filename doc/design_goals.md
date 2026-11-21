# Design goals

## Goals
(TODO: no need to number these)
0. Minimize amount keypresses. Minimize movement betweeen keyboard and mouse.
1. **Separate key bindings from actions.** Every command is a named action, and a
   binding only points to one (unlike Vim, where `dw` *is* the command). Any action
   can then be bound in any keymap, rebound in `custom.rb`, and found in the menu
   or in Search for Actions. Composite commands are built from parts defined as data
   (operator × motion), not hardcoded per key combination.
2. **Modularity.** Optional features, and those that need external tools (LSP,
   ack, dictation, terminal, …), are modules that can be turned on and off. The core
   works without them.
3. **A reusable key binding system.** `KeyBindingTree` knows about keys, modes and
   actions, not buffers, so other software could use it.
4. **Vim compatibility for popular features:** motions, operators with counts, text
   objects, visual mode, registers, `.`, search.
5. **Ruby as the extension language.** Configuration is plain Ruby (`custom.rb`).
 -  Don't rely too much on GTK gui. Gui may change, or there may be support for another gui. First version was implemented for QT. There could be a gui abstraction layer to ease the move to another gui framework or console. 
 - At some point goal is to support WYSIWYG style editing (like Word). Open questions are the file format and which component to use for rendering.
 - Allow using easy jump for almost everywhere (selecting files, items from gui lists etc.)

## Non-goals

- Vimscript and Vim plugins.
- Vim's full Ex command language. Only common `:` commands (`:w`, `:wq`, `:s`).
- Vim regex syntax. Searches use Ruby regex.
