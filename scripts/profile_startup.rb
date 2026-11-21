# Where the editor's startup time goes. Loaded with -r before exe/vimamsa:
#
#   ruby -r ./scripts/profile_startup.rb exe/vimamsa [file]
#
# Prints to stderr, at exit: the slow requires (a tree, > 10 ms) and, after
# the code is loaded, the slow calls of vimamsa's own methods (a tree, > 10
# ms, inclusive times), with their start offset from when this file was
# loaded. Tracing adds overhead, so method times are somewhat too high.
# Env: VMA_PROFILE_MIN_MS (10), VMA_PROFILE_DEPTH (6).
module StartupProfile
  T0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  MIN = (ENV["VMA_PROFILE_MIN_MS"] || 10).to_f / 1000
  DEPTH = (ENV["VMA_PROFILE_DEPTH"] || 6).to_i
  @lines = [] # [start, depth, text]
  @rdepth = 0
  @stack = []

  def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def self.note(start, depth, dt, text)
    @lines << [start, depth, dt, text] if dt >= MIN
  end

  def self.require_wrap(name)
    t = now
    @rdepth += 1
    d = @rdepth
    yield
  ensure
    @rdepth -= 1
    note(t, d, now - t, "require #{name}")
  end

  OWN = %r{/(lib/vimamsa|modules|exe)/}
  @tp = TracePoint.new(:call, :return) { |tp|
    next unless OWN.match?(tp.path)
    case tp.event
    when :call
      @stack << now
    when :return
      t = @stack.pop
      next if t.nil?
      d = @stack.size
      next if d >= DEPTH
      what = "#{tp.defined_class}##{tp.method_id}"
      note(t, d + 1, now - t, "#{what}  (#{tp.path.sub(%r{.*/(lib|modules|exe)/}, '\1/')}:#{tp.lineno})")
    end
  }

  def self.report
    @tp.disable
    STDERR.puts "=== startup profile (offset s, inclusive ms) ==="
    @lines.sort_by { |s, d, _, _| [s, d] }.each { |s, d, dt, text|
      STDERR.puts format("%6.3f %7.1f %s%s", s - T0, dt * 1000, "  " * (d - 1), text)
    }
  end

  # Method calls are traced from when the code is loaded (tracing during the
  # requires would slow them down a lot)
  def self.start_tracing = @tp.enable
end

module Kernel
  alias_method :__profile_require, :require
  def require(name)
    r = StartupProfile.require_wrap(name) { __profile_require(name) }
    StartupProfile.start_tracing if name == "vimamsa"
    r
  end
end

at_exit { StartupProfile.report }
