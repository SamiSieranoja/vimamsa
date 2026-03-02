# VmaTest — integration test base class
#
# Tests run inside the live GTK app (headless or normal) after vma.start.
# Each test method gets a fresh empty buffer.
#
# Two ways to drive the editor:
#   act(:action_name)         — execute a registered action directly
#   act("buf.insert_txt(…)")  — eval a string action
#   keys("i h e l l o esc")  — simulate a space-separated key sequence
#
# Assertions raise VmaTestFailure on mismatch (caught by the runner).
#
# Usage:
#   Run all tests:  run_vma_tests
#   Run one class:  run_vma_tests(MyTests)

class VmaTestFailure < StandardError; end

class VmaTest
  attr_reader :failures, :passes

  # Subclasses define test_* methods.
  # Each receives a fresh buffer and the kbd in :command mode.
  def run_all
    @passes = 0
    @failures = []
    test_methods = self.class.instance_methods(false)
                       .select { |m| m.to_s.start_with?("test_") }
                       .sort

    test_methods.each do |m|
      _setup_test
      begin
        send(m)
        @passes += 1
        puts "  PASS  #{self.class}##{m}"
      rescue VmaTestFailure => e
        @failures << "#{self.class}##{m}: #{e.message}"
        puts "  FAIL  #{self.class}##{m}: #{e.message}"
      rescue => e
        @failures << "#{self.class}##{m}: #{e.class}: #{e.message}"
        puts "  ERROR #{self.class}##{m}: #{e.class}: #{e.message}"
        puts e.backtrace.first(5).join("\n")
      end
    end
  end

  # ── Actions ──────────────────────────────────────────────────────────────

  # Execute one action (symbol, string, or proc)
  def act(action)
    exec_action(action)
    drain_idle
  end

  # Simulate a space-separated key sequence in the current mode.
  # E.g.:  keys("i h e l l o esc")
  # Special tokens: ctrl-x, alt-x, shift-X, esc, enter, backspace, tab, space
  def keys(seq)
    seq.split.each do |k|
      vma.kbd.match_key_conf(k, nil, :key_press)
      # Emit a key_release for modifier-only keys so state resets correctly
      vma.kbd.match_key_conf(k + "!", nil, :key_release) if %w[ctrl alt shift].include?(k)
    end
    drain_idle
  end

  # ── Assertions ───────────────────────────────────────────────────────────

  def assert_buf(expected, msg = nil)
    actual = vma.buf.to_s
    return if actual == expected
    raise VmaTestFailure, (msg || "buffer mismatch\n  expected: #{expected.inspect}\n  actual:   #{actual.inspect}")
  end

  def assert_pos(lpos, cpos, msg = nil)
    al = vma.buf.lpos
    ac = vma.buf.cpos
    return if al == lpos && ac == cpos
    raise VmaTestFailure, (msg || "position mismatch: expected line #{lpos} col #{cpos}, got line #{al} col #{ac}")
  end

  def assert_mode(expected_mode, msg = nil)
    actual = vma.kbd.get_mode
    return if actual == expected_mode
    raise VmaTestFailure, (msg || "mode mismatch: expected #{expected_mode.inspect}, got #{actual.inspect}")
  end

  def assert_eq(expected, actual, msg = nil)
    return if expected == actual
    raise VmaTestFailure, (msg || "expected #{expected.inspect}, got #{actual.inspect}")
  end

  def assert(cond, msg = "assertion failed")
    raise VmaTestFailure, msg unless cond
  end

  private

  def _setup_test
    # Fresh buffer, command mode
    b = create_new_buffer("\n", "test", true)
    vma.kbd.set_mode(:command) rescue nil
    drain_idle
  end

  # Let any GLib::Idle callbacks run before we check state
  def drain_idle
    5.times { GLib::MainContext.default.iteration(false) }
  end
end

# ── Runner ───────────────────────────────────────────────────────────────────

def run_vma_tests(*classes)
  classes = ObjectSpace.each_object(Class)
                       .select { |c| c < VmaTest }
                       .sort_by(&:name) if classes.empty?

  total_pass = 0
  total_fail = []

  classes.each do |klass|
    puts "\n#{klass}"
    t = klass.new
    t.run_all
    total_pass += t.passes
    total_fail.concat(t.failures)
  end

  puts "\n#{"=" * 50}"
  puts "Results: #{total_pass} passed, #{total_fail.size} failed"
  total_fail.each { |f| puts "  FAIL: #{f}" }
  puts "=" * 50

  total_fail.empty?
end
