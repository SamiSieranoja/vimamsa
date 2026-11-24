# Plan: code review mode for dictation

## Context

Dictation (`modules/dictation/dictation.rb`) currently inserts what you say at the
cursor. For reviewing code, it's more useful to point at a piece of code and talk
about it. Code review mode works like this:

1. In dictation mode, turn on review mode.
2. Select some code with the mouse or with visual mode (`v` …).
3. Talk while the selection is up.
4. End the selection (`esc`, or click so the selection goes away). The recording is
   transcribed and added as a comment above the selected code:

   ```ruby
       # COMMENT: this loop runs twice for the last element, check the bound
       foo.each_with_index do |x, i|
   ```

The text is not inserted while you talk, because the selection is still up and the
code shouldn't move under it. Live preliminary text goes to the status area instead.

## What exists to build on

- **Dictation mode:** `vma.kbd.add_minor_mode("dictation", :dictation, :command)`. It
  inherits command mode, so `v` (`mode.visual`) works in it. `set_mode(:visual)`
  pushes `:visual` on the mode stack and `end_visual_mode` → `to_previous_mode` pops
  back to `:dictation`.
- **Mouse selections:** `gui_sourceview.rb` (~257–395) calls `buf.start_selection` +
  `vma.kbd.set_mode(:visual)` on drag, and `end_visual_mode` on a click that clears
  it. So mouse and keyboard selections go through the same visual mode path.
- **Mode events:** `vma.kbd.on(:mode_changed) { |label| … }` fires on every mode
  change (`__set_mode`). Listeners are a list, so the module can add its own.
  `:action_handled` fires after each key action.
- **Selection range:** `Buffer#get_visual_mode_range` (`@selection_start`..`@pos`).
  `end_selection` doesn't clear `@selection_start`, but `@pos` can move as visual
  mode ends, so the range has to be saved *while* the selection is still up.
- **Comment string:** `Buffer#get_com_str` (rules in `cnf.comment_chars`, then the
  language's `line-comment-start`, then `//`). `comment_linerange` shows how to keep
  the indentation.
- **Recording/transcription:** `VmaDictationRecorder`, `VmaWhisperWorker` (the mutex
  queues requests), and `VmaDictationSession` (recording, preliminary loop, final
  pass, status indicator).

## Design

### Turning it on

- `dictation c` → `dictation.review_toggle`: switches review mode on/off inside
  dictation mode. (`c` is only shadowed in dictation mode, which isn't for editing.)
- `C , ; r` → `dictation.review_enter`: goes into dictation mode with review mode
  already on.
- Leaving dictation mode (`esc`, `, k`, `ctrl!`) also turns review mode off.
- Menu: "Start Dictation Code Review" under Modules.
- Status indicator: `📝 REVIEW` while idle in review mode, `📝 REVIEW · LISTENING`
  while a selection is being recorded, and the usual TRANSCRIBING/LOADING phases.

When review mode turns on, any inline dictation that's running stops (with
`add_newline: false`). The microphone is only on while a selection is up.

### Selection lifecycle

A `:mode_changed` listener, registered in `dictation_init` and made inactive in
`dictation_disable` (the kbd has no `off`, so it checks a flag):

| Transition | Condition | Action |
|---|---|---|
| → `:visual` | review on, mode below it on the stack is `:dictation` | start a review recording |
| `:visual` → `:dictation` | a review recording is running | stop it, transcribe, add the comment |

To save the range: add a `:visual_mode_ending` hook call at the top of
`Buffer#end_visual_mode`, before `end_selection`. The range is then saved exactly
once, at the right moment, and the same way for keyboard `esc` and mouse
click-to-clear (both end through `end_visual_mode`). Saving it on every
`:action_handled` would miss mouse drags.

Operators that end visual mode by changing the text (`d`, `c`, `x`, drag-and-drop
move, `>`…) change `buf.edit_version`. If the version at the end isn't the same as at
the start, there's nothing sensible to attach the comment to: throw the recording
away and say "Dictation review: selection was edited — comment discarded". Yank
(`y`) doesn't edit, so it still adds the comment.

### Session refactor

`VmaDictationSession` currently owns *where* text goes (`@dict_start`/`@dict_len`
span, `_append_prelim`, `_finalize_replace`). Split that out into a sink object:

- `InlineSink` — today's behaviour (span inserts + final replace + newline/restart).
- `ReviewSink` — preliminary text goes to the status/minibuffer (`message("📝 …")`,
  last ~80 chars). When the final text arrives it calls `insert_review_comment`.

`VmaDictationSession.new(sink:)`. Inline dictation keeps using the
`dictation_session` singleton. **Each review comment gets its own session
instance**, so the user can start the next selection while the previous one is
still being transcribed (the worker mutex runs the final passes one after another).
Keep a list of active review sessions so `dictation_disable` can stop them all.

The final-pass options are the same (beam 5, VAD, the last prompt). Tell the model
it's code review by adding the selected code's identifiers to the prompt, e.g. the
first ~200 chars of the selection after the user's prompt. This helps whisper spell
names like `get_visual_mode_range` correctly. Setting:
`cnf.dictation.review_code_prompt` (default true).

### Writing the comment

`insert_review_comment(buf, range, text)` (main thread):

1. Line = `buf.get_line_start(range.begin)`; indentation = the leading whitespace of
   that line.
2. `com = buf.get_com_str`, `prefix = cnf.dictation.review_prefix! || "COMMENT:"`.
3. Wrap the text to `cnf.dictation.review_wrap! || 80` columns, counting the indent +
   `com + " " + prefix`. Following lines use `com + " " + " " * prefix.size` so they
   line up under the first one.
4. Insert `indent + com + " " + prefix + " " + line + "\n"` lines at the line start,
   all in one undo group (`new_undo_group` before and after), then `handle_deltas`.
5. Put the cursor back where it was (moved down by the inserted length if it was
   after the insert point).

Languages without a line comment (`get_com_str` falls back to `//` for e.g. HTML,
CSS, markdown): add a block form setting, `cnf.dictation.review_block_comment` per
language (`{ "html" => ["<!--", "-->"], "css" => ["/*", "*/"] }`), used if the
language has no `line-comment-start`. Out of scope for the first version except for
this fallback.

Edge cases:
- Empty transcript → no comment, "Dictation review: no speech recognized".
- Selection shorter than ~0.7 s of audio (an accidental click-drag) → throw it away
  quietly. The recorder's WAV size tells you the length.
- Buffer closed before the final text arrives → existing `_target_gone?` path.
- The buffer is edited elsewhere while transcribing → the saved line start is no
  longer right. Store the target as a line *mark* (or move it by the deltas made
  since, using `buf.deltas`) rather than a raw pos. First version: re-find the line
  by its saved text near the old line number. If it can't be found, put the comment
  at the old position and add a warning to the message.
- Mode stack: if visual mode was entered from something other than `:dictation`
  (e.g. review on, then the user left the mode with `ctrl!`), the condition above
  doesn't match and nothing gets recorded.

## Files

- `modules/dictation/dictation.rb` — sinks, review session handling, the
  `insert_review_comment` helper, the actions/bindings/menu item, the `:mode_changed`
  listener, and disabling it all in `dictation_disable`. Update the header comment.
- `lib/vimamsa/buffer.rb` — call the visual-ending hook in `end_visual_mode` (e.g.
  `hook.call(:visual_mode_ending, self)` or a kbd event), passing the range.
- `lib/vimamsa/conf.rb` — no defaults needed (`!` accessors with fallbacks), but
  document `review_prefix`, `review_wrap`, `review_code_prompt`.
- `help/` key bindings page shows the new bindings automatically, nothing to do.
- `doc/TODO.md` — open item, then a DONE entry.

## Tests (`tests/test_dictation.rb`, run in the VM)

No microphone: test the parts without the recorder/worker, the same way
`test_span_replace` does.

- `insert_review_comment`: Ruby buffer → `# COMMENT: …` above the right line with the
  indentation kept; a `.c` file → `// COMMENT: …`; long text wraps and lines up;
  one undo removes the whole comment.
- Lifecycle with a fake session (inject the session class / stub
  `VmaDictationSession#start`/`stop`): `dictation c` turns review on; `v` starts a
  "recording"; `l l esc` stops it with the right range; feeding a fake final result
  adds the comment. `v d` (edit) → no comment.
- Mouse path: `buf.start_selection; vma.kbd.set_mode(:visual)` then
  `buf.end_visual_mode` behaves the same as the keyboard path.
- Review mode off → `v … esc` in dictation mode records nothing.
- `dictation_disable` removes the listener and the bindings (extend
  `test_disable_unregisters`).

## Open questions

- Bindings: `dictation c` + `C , ; r` (proposed), or something else?
- Should the comment include the reviewer's name/date (`# COMMENT(2026-11-24): …`)?
- Comment above the selection (proposed) or at the end of the selection's last line?
- Do we also want a "collect review comments" view that lists all `COMMENT:` lines in
  the project (grep), so you can go through them later?
