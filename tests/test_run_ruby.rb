# buf.run.ruby (run_ruby.rb): the file run with Ruby in a separate process,
# its output (stdout and stderr in order) in a buffer
require "tmpdir"

class TestRunRuby < VmaTest
  def outputs
    vma.buffers.list.select { |b| b.instance_variable_get(:@ruby_output_of) }
  end

  # Runs b and returns the output buffer
  def run_and_wait(b)
    before = outputs.map(&:id)
    act "buf.run.ruby"
    t = Time.now
    o = nil
    until (o = outputs.find { |x| !before.include?(x.id) }) || Time.now - t > 20
      drain_idle
      sleep 0.02
    end
    assert o, "no output buffer"
    o
  end

  def test_runs_file_and_shows_output
    Dir.mktmpdir("vma-run") { |d|
      f = File.join(d, "hello.rb")
      File.write(f, "puts 1 + 1\n$stderr.puts 'to stderr'\nputs File.basename(__FILE__)\n")
      b = open_new_file(f)
      o = run_and_wait(b)
      assert o.to_s.start_with?("# ruby #{f} (exit 0,"), o.to_s.lines.first
      assert o.to_s.include?("2\nto stderr\nhello.rb\n"), o.to_s
      assert vma.buf.equal?(o)
      vma.buffers.close_buffer(o.id)
      vma.buffers.close_buffer(b.id)
    }
  end

  # Unsaved changes are saved first; a second run replaces the output
  def test_saves_first_and_replaces_output
    Dir.mktmpdir("vma-run") { |d|
      f = File.join(d, "edit.rb")
      File.write(f, "puts :old\n")
      b = open_new_file(f)
      o1 = run_and_wait(b)
      vma.buffers.set_current_buffer_by_id(b.id)
      b.set_pos(0)
      keys "d d"
      keys "i p u t s space : n e w esc"
      o2 = run_and_wait(b)
      assert_eq "puts :new\n", File.read(f), "not saved before running"
      assert o2.to_s.include?("new\n"), o2.to_s
      assert vma.buffers.list.none? { |x| x.equal?(o1) }, "old output buffer still open"
      assert_eq 1, outputs.size
      vma.buffers.close_buffer(o2.id)
      vma.buffers.close_buffer(b.id)
    }
  end

  # An error: the exit status and the message with its file:line
  def test_error_and_buffer_without_file
    b = create_new_buffer("puts :before\nraise 'boom'\n", "runtest")
    o = run_and_wait(b)
    assert o.to_s.lines.first.include?("exit 1"), o.to_s.lines.first
    assert o.to_s.include?("before\n"), o.to_s
    assert o.to_s =~ /vimamsa-run.*\.rb:2:in .*boom/, o.to_s
    vma.buffers.close_buffer(o.id)
  end

  # The action search lists id and description in columns of their own
  def test_action_search_columns
    rows = vma.actions.search_actions_update_callback("bufrunruby")
    row = rows.find { |_k, id, _d| id == "buf.run.ruby" }
    assert row, rows.first(3).inspect
    assert_eq 3, row.size
    assert row[2].start_with?("Run the file as Ruby"), row.inspect
  end
end
