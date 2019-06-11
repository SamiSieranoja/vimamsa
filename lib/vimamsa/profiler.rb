
$prof = false

def enable_profiler()
  require "ruby-prof"
  $prof = true
end

def start_profiler()
  if $prof and !RubyProf.running?
    RubyProf.start
  end
end

$prof_count = 0
def end_profiler()
  if $prof and RubyProf.running?
    results = RubyProf.stop
    #TODO: add action name to fn
    RubyProf::GraphHtmlPrinter.new(results).print(File.open("/tmp/vma-prof_#{$prof_count}.html", "w"))
    $prof_count += 1
  end
end



