
module Vimamsa
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
class VmaTestSkip < StandardError; end

class VmaTest
  attr_reader :failures, :passes, :skips, :times

  # Tests slower than this (seconds) show their time on the result line
  SHOW_TIME_OVER = 0.5

  # Subclasses define test_* methods.
  # Each receives a fresh buffer and the kbd in :command mode.
  def run_all
    @passes = 0
    @failures = []
    @skips = []
    @times = {} # "Class#test" => seconds (setup included)
    test_methods = self.class.instance_methods(false)
                       .select { |m| m.to_s.start_with?("test_") }
                       .sort

    test_methods.each do |m|
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      took = lambda {
        dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
        @times["#{self.class}##{m}"] = dt
        dt > SHOW_TIME_OVER ? " (#{dt.round(1)} s)" : ""
      }
      _setup_test
      begin
        send(m)
        @passes += 1
        puts "  PASS  #{self.class}##{m}#{took.call}"
      rescue VmaTestSkip => e
        @skips << "#{self.class}##{m}: #{e.message}"
        puts "  SKIP  #{self.class}##{m}: #{e.message}#{took.call}"
      rescue VmaTestFailure => e
        @failures << "#{self.class}##{m}: #{e.message}"
        puts "  FAIL  #{self.class}##{m}: #{e.message}#{took.call}"
      rescue => e
        @failures << "#{self.class}##{m}: #{e.class}: #{e.message}"
        puts "  ERROR #{self.class}##{m}: #{e.class}: #{e.message}#{took.call}"
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

  # Execute one action without draining the GLib main loop.
  # Use in tight loops; call drain_idle manually at a suitable interval.
  def act_fast(action)
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

  # Skip the current test (reported as SKIP, not a failure). Use for tests
  # that are unreliable in the current environment (e.g. clipboard/idle timing
  # under headless GTK).
  def skip(msg = "")
    raise VmaTestSkip, msg
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
    20.times { GLib::MainContext.default.iteration(false) }
  end

  # Call the block every interval seconds (running the main loop in between)
  # until it returns something non-nil and non-empty, or timeout seconds
  # pass. Returns the last result. For waiting on something asynchronous
  # without a fixed sleep.
  def poll_until(timeout: 15, interval: 0.2)
    t = Time.now
    loop do
      r = yield
      return r if r && !(r.respond_to?(:empty?) && r.empty?)
      return r if Time.now - t > timeout
      sleep interval
      drain_idle
    end
  end

  # Run the main loop until buf has its language server (servers start in
  # the background), or timeout seconds pass. Returns buf.lsp.
  def wait_for_lsp(buf, timeout = 15)
    t = Time.now
    until buf.lsp || Time.now - t > timeout
      drain_idle
      sleep 0.02
    end
    buf.lsp
  end
end

# ── Runner ───────────────────────────────────────────────────────────────────

def run_vma_tests(*classes)
  classes = ObjectSpace.each_object(Class)
                       .select { |c| c < VmaTest }
                       .sort_by(&:name) if classes.empty?

  total_pass = 0
  total_fail = []
  total_skip = []
  times = {}
  class_times = {}
  t_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  classes.each do |klass|
    puts "\n#{klass}"
    c0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    t = klass.new
    t.run_all
    class_times[klass.name] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - c0
    total_pass += t.passes
    total_fail.concat(t.failures)
    total_skip.concat(t.skips || [])
    times.merge!(t.times || {})
  end
  total_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_start

  # Where the time went, to see what to speed up
  if classes.size > 1
    puts "\n#{"=" * 50}"
    puts "Slowest tests (of #{total_time.round(1)} s):"
    times.sort_by { |_, s| -s }.first(15).each { |n, s| puts format("  %6.1f s  %s", s, n) }
    puts "Slowest classes:"
    class_times.sort_by { |_, s| -s }.first(10).each { |n, s| puts format("  %6.1f s  %s", s, n) }
  end

  puts "\n#{"=" * 50}"
  skip_note = total_skip.empty? ? "" : ", #{total_skip.size} skipped"
  puts "Results: #{total_pass} passed, #{total_fail.size} failed#{skip_note}"
  total_fail.each { |f| puts "  FAIL: #{f}" }
  total_skip.each { |s| puts "  SKIP: #{s}" }
  puts "=" * 50

  total_fail.empty?
end
end # module Vimamsa
