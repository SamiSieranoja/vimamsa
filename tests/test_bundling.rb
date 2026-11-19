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

  # ── restore_host_env (lib/vimamsa/appimage_env.rb) ──

  def test_restore_host_env_puts_back_previous_values
    saved = ENV.to_h
    ENV["VMA_APPIMAGE_ENV"] = " VMA_T_SET VMA_T_UNSET"
    ENV["VMA_HOST_VMA_T_SET"] = "host value"
    ENV["VMA_T_SET"] = "bundle value"
    ENV["VMA_T_UNSET"] = "bundle value"
    restore_host_env
    assert_eq "host value", ENV["VMA_T_SET"]
    assert !ENV.key?("VMA_T_UNSET"), "a variable the host didn't have must be removed"
    assert !ENV.key?("VMA_HOST_VMA_T_SET") && !ENV.key?("VMA_APPIMAGE_ENV")
    out = IO.popen(["sh", "-c", "echo \"$VMA_T_SET|${VMA_T_UNSET-unset}\""], &:read)
    assert_eq "host value|unset\n", out
  ensure
    ENV.replace(saved)
  end

  # Only from the AppImage (AppRun exports APPDIR)
  def test_appimage_children_get_host_environment
    appdir = ENV["APPDIR"]
    skip "not running from the AppImage" if appdir.nil?
    ok = %w[PATH APPDIR APPIMAGE ARGV0 OWD]
    leaked = ENV.reject { |k, v| ok.include?(k) || !v.include?(appdir) }
    assert leaked.empty?, "still pointing into the AppImage: #{leaked.keys.join(", ")}"
    # What the restore must not break: things loaded on first use
    require "vte4"
    assert Vte::Terminal.new
    assert Gst::ElementFactory.make("playbin"), "playbin (bundled GStreamer plugins)"
    png = Dir.glob("#{appdir}/usr/share/icons/hicolor/**/*.png").first || "#{appdir}/vimamsa.png"
    assert GdkPixbuf::Pixbuf.new(file: png)
    # The bundled ruby-lsp still runs (its wrapper drops the user's GEM_HOME)
    out = IO.popen(["ruby-lsp", "--version"], err: [:child, :out], &:read)
    assert out =~ /\d+\.\d+/, "ruby-lsp --version: #{out}"
  end
end
