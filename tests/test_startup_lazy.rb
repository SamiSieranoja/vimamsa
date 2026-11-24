# Startup shortcuts (doc/startup_speed_plan.md): garbage collection off while
# starting, and the red-colors gem (required by cairo) loaded only on use.
class TestStartupLazy < VmaTest
  RED_COLORS = %r{red-colors[^/]*/lib/colors\.rb\z}

  # exe/vimamsa turns GC off; Editor#start's first idle turns it back on
  def test_gc_on_after_startup
    assert_eq false, GC.enable, "garbage collection still off after startup"
  end

  def test_red_colors_not_loaded_at_startup
    skip "red-colors gem spec not found (loaded the normal way)" if $vma_red_colors_dir.nil?
    assert !$LOADED_FEATURES.any? { |f| f =~ RED_COLORS }, "red-colors was loaded at startup"
    assert_eq File.join($vma_red_colors_dir, "lib/colors.rb"), Object.autoload?(:Colors)
  end

  # What cairo uses it for: color names and hex still parse
  def test_cairo_colors_parse
    assert_eq "#FF0000FF", Cairo::Color.parse("red").to_s
    assert_eq "#00FF00FF", Cairo::Color.parse("#00ff00").to_s
  end
end
