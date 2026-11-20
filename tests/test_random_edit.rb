# Random edit stress test — NOT part of the normal test suite.
# Run explicitly: vimamsa --test tests/test_random_edit.rb
#
# Executes editor actions at random for 30 seconds and fails if any
# action raises an unhandled exception (i.e. the editor crashes).

class TestRandomEdit < VmaTest

  DURATION = 300  # seconds — override with duration=N on the command line

  # Safe actions: no file dialogs, no eval, no close/save operations.
  SAFE_ACTIONS = [
    "move.char.next",
    "move.char.prev",
    "move.line.next",
    "move.line.prev",
    "move.buf.start",
    "move.buf.end",
    "move.line.end",
    "move.line.start",
    "move.word.end",
    "move.word.prev",
    "move.word.next",
    :delete_char_forward,
    :insert_backspace,
    :delete_to_word_end,
    :delete_to_next_word_start,
    :delete_to_line_start,
    "undo.last",
    "undo.redo",
    :copy_cur_line,
    :paste_after_cursor,
    :paste_before_cursor,
    :insert_new_line,
    "move.page.next",
    "move.page.prev",
    :center_on_current_line,
    :gui_refresh_cursor,
  ].freeze

  RANDOM_TEXTS = [
    "hello world",
    "foo bar baz",
    "test 123",
    "abc def ghi",
    "  indented  ",
    "line\nbreak",
    "x",
    "longer text with spaces and stuff",
  ].freeze

  MODES = [:insert, :command, :visual].freeze

  def test_random_editing_stress
    duration   = $vma_test_duration || DURATION
    start_time = Time.now
    iteration  = 0
    errors     = []

    # Seed the buffer with some content to work with
    act 'buf.insert_txt("alpha\nbeta\ngamma\ndelta\nepsilon\nzeta\neta\n")'

    while Time.now - start_time < duration
      iteration += 1

      begin
        case rand(12)
        when 0..5  then act_fast(SAFE_ACTIONS.sample)
        when 6..7  then act_fast("buf.insert_txt(#{RANDOM_TEXTS.sample.inspect})")
        when 8     then act_fast("vma.kbd.set_mode(:insert)")
        when 9     then act_fast("vma.kbd.set_mode(:command)")
        when 10    then act_fast("buf.start_selection; vma.kbd.set_mode(:visual)")
        when 11    then act_fast("move.random")
        end
      rescue => e
        errors << "iter #{iteration}: #{e.class}: #{e.message}"
      end

      if (iteration % 20).zero?
        drain_idle
        # Flush pending deltas to GTK before comparing — handle_deltas is not
        # called by act_fast or drain_idle, so the GTK buffer lags otherwise.
        vma.buf.view.handle_deltas

        # Verify GTK and Ruby buffers are in sync
        gtk_text  = vma.buf.view.buffer.text
        ruby_text = vma.buf.to_s
        unless gtk_text == ruby_text
          errors << "iter #{iteration}: GTK/Ruby buffer mismatch " \
                    "(gtk #{gtk_text.bytesize}B != ruby #{ruby_text.bytesize}B)"
        end
      end
    end

    # Restore a clean state
    act("vma.kbd.set_mode(:command)") rescue nil
    drain_idle

    elapsed = (Time.now - start_time).round(1)
    puts "  Random edit stress: #{iteration} actions in #{elapsed}s"

    unless errors.empty?
      sample = errors.first(5).join("\n    ")
      raise VmaTestFailure,
        "#{errors.size} error(s) during random editing:\n    #{sample}"
    end
  end

end
