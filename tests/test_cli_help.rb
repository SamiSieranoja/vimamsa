# vimamsa --help: the options and the actions, without starting the editor
# (lib/vimamsa/cli_help.rb)
require "open3"
require "rbconfig"
require "tmpdir"

class TestCliHelp < VmaTest
  EXE = File.expand_path("../exe/vimamsa", __dir__)

  def run_help(*args)
    Dir.mktmpdir("vma-help") { |ud|
      # a running editor's listen dir: --help must not be sent to it as a file
      FileUtils.mkdir_p(File.join(ud, "listen"))
      out, st = Open3.capture2e(*vma_editor_command(EXE), "--user-dir", ud, *args)
      [out, st, Dir.children(File.join(ud, "listen"))]
    }
  end

  def test_help_lists_options_and_actions
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    out, st, listen = run_help("--help")
    assert st.success?, "exit status #{st.exitstatus}: #{out[-500..]}"
    assert_eq [], listen, "--help was passed to a running editor"
    assert out.include?("Usage: vimamsa"), out[0, 300]
    assert out.include?("--intro")
    assert out.include?("--user-dir")
    lines = out.lines.map(&:strip)
    save = lines.find { |l| l.start_with?("buf.save ") }
    assert save, "buf.save not listed"
    assert_eq vma.actions["buf.save"].method_name.to_s, save.sub(/\Abuf\.save\s+/, ""), "description"
    %w[help.intro help.demo move.motion op.motion edit.register].each { |id|
      assert lines.any? { |l| l == id || l.start_with?("#{id} ") }, "#{id} not listed"
    }
    n = out[/Actions \((\d+)\)/, 1].to_i
    listed = lines.select { |l| l.match?(/\A[a-z][a-z0-9_]*(\.[a-z0-9_]+)+(\s|\z)/) }.map { |l| l.split[0] }
    assert_eq n, listed.size
    # all real actions; missing ones only from modules (registered on init)
    # and custom.rb (from custom_example.rb, e.g. the getnums converter)
    live = vma.actions.dotted_ids.map(&:to_s)
    assert_eq [], listed - live, "listed but not actions"
    extra = (Dir[File.expand_path("../modules/*/*.rb", __dir__)] + [File.expand_path("../custom_example.rb", __dir__), get_dot_path("custom.rb")])
            .select { |f| File.exist?(f) }.map { |f| File.read(f) }.join
    missing = (live - listed).reject { |id| extra.include?(id) || extra.include?(":#{id.sub("sel.convert.", "")})") || id.include?("zz_") }
    assert missing.empty?, "actions missing from --help: #{missing.inspect}"
    assert !out.include?("Init_vmaext\n" * 2)
  end

  def test_short_option
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    out, st, = run_help("-h")
    assert st.success?
    assert out.include?("Usage: vimamsa")
  end

  # The list is the same as in the running editor, apart from what modules
  # and custom.rb add
  def test_action_lines_format
    lines = Vimamsa.cli_action_lines(vma.actions)
    assert lines.all? { |l| l.start_with?("  ") }
    ids = lines.map { |l| l.split[0] }
    assert_eq ids.sort, ids
    assert ids.include?("buf.save")
  end
end
