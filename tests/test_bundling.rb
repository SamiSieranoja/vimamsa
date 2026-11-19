require "tmpdir"
require "open3"

# Code changes for running from a bundle (doc/bundling_plan.md, "Code changes
# needed regardless of format").
class TestBundling < VmaTest
  def with_env(name, val)
    old = ENV[name]
    ENV[name] = val
    yield
  ensure
    ENV[name] = old
  end

  def test_launcher_runs_gem_binstub_by_default
    with_env("APPIMAGE", nil) {
      assert_eq "vimamsa %F", desktop_exec_command
      assert desktop_entry_contents.include?("\nExec=vimamsa %F\n")
    }
  end

  def test_launcher_runs_the_appimage
    with_env("APPIMAGE", "/home/u/Apps/Vimamsa-x86_64.AppImage") {
      assert_eq %{"/home/u/Apps/Vimamsa-x86_64.AppImage" %F}, desktop_exec_command
    }
  end

  def test_launcher_quotes_odd_appimage_paths
    # Spaces stay inside the quotes; " ` $ \ are escaped, % is doubled
    with_env("APPIMAGE", %{/home/u/My Apps/a"b$c%d\\e.AppImage}) {
      assert_eq %{"/home/u/My Apps/a\\\\"b\\\\$c%%d\\\\\\\\e.AppImage" %F}, desktop_exec_command
    }
  end

  # exe/vimamsa must load lib/ next to itself, not ./lib of the current dir
  def test_exe_load_path_is_relative_to_script
    exe = File.expand_path("../exe/vimamsa", __dir__)
    src = File.read(exe)
    assert !src.include?('File.expand_path("lib")'), "exe/vimamsa uses ./lib of the current directory"
    Dir.mktmpdir { |dir|
      # A decoy lib/vimamsa.rb in the current directory must not be loaded
      Dir.mkdir("#{dir}/lib")
      File.write("#{dir}/lib/vimamsa.rb", "puts 'DECOY'; exit 3\n")
      code = src[/\A.*?\$LOAD_PATH\.unshift\(File\.join\(scriptdir, "ext"\)\)\n/m]
      assert code, "load path lines not found in exe/vimamsa"
      code = code.sub(/^require "ripl\/multi_line"\n/, "")
      script = "#{dir}/probe.rb"
      File.write(script, code.sub("selfpath = __FILE__", "selfpath = #{exe.inspect}") +
                         "puts $LOAD_PATH.first(2)\n")
      out, st = Open3.capture2e(RbConfig.ruby, script, chdir: dir)
      assert st.success?, out
      root = File.expand_path("..", __dir__)
      assert_eq ["#{root}/ext", "#{root}/lib"], out.split("\n").last(2)
    }
  end
end
