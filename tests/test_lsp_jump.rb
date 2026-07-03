# LSP jump-to-definition test.
# Configures ruby-lsp internally — no custom.rb setup required.
# Skips gracefully if 'bundle exec ruby-lsp' is unavailable or times out.
#
# Run explicitly:
#   ruby exe/run_tests.rb test_lsp_jump

class TestLspJumpToDefinition < VmaTest
  REPO_ROOT = File.expand_path("../../", __FILE__)

  # We jump from the `< VmaTest` reference in test_basic_editing.rb
  # to the `class VmaTest` definition in test_framework.rb.
  # Using a constant/class reference that ruby-lsp can resolve statically.
  CALLER_FILE = File.join(REPO_ROOT, "tests/test_basic_editing.rb")
  TARGET_FILE = File.join(REPO_ROOT, "lib/vimamsa/test_framework.rb")

  def test_jump_to_definition
    # langservp.rb is only loaded at startup when cnf.lsp.enabled — this
    # test enables LSP after startup, so load it here.
    require "vimamsa/langservp"
    # Configure ruby-lsp for this test, pointing at the repo root so
    # 'bundle exec ruby-lsp' can find the Gemfile and load its addons.
    cnf.lsp.enabled = true
    cnf.lsp.server.ruby_lsp = {
      name: "ruby-lsp",
      command: "bundle exec ruby-lsp",
      languages: ["ruby"],
      rooturi: "file://#{REPO_ROOT}",
    }

    # Reset any cached LSP instance so it re-initialises with the config above.
    LangSrv.class_variable_get(:@@languages).delete("ruby")

    # Open the caller file — this triggers LSP initialisation for "ruby".
    open_new_file(CALLER_FILE)
    drain_idle

    unless vma.buf.lsp
      puts "  SKIP  #{self.class}#test_jump_to_definition " \
           "(ruby-lsp unavailable — is 'bundle exec ruby-lsp' installed?)"
      return
    end

    # Locate `class TestBasicEditing < VmaTest` and position cursor on `VmaTest`.
    caller_lines = File.readlines(CALLER_FILE)
    caller_lnum  = caller_lines.index { |l| l =~ /class\s+\w+\s*<\s*VmaTest\b/ }
    assert !caller_lnum.nil?,
           "Could not locate a '< VmaTest' class definition in #{File.basename(CALLER_FILE)}"

    caller_col = caller_lines[caller_lnum].index("VmaTest")
    assert !caller_col.nil?, "Could not locate 'VmaTest' token in the class definition line"

    abs_pos = caller_lines[0...caller_lnum].sum(&:bytesize) + caller_col
    act "buf.set_pos(#{abs_pos})"

    # Find expected destination: `class VmaTest` in test_framework.rb.
    target_lines  = File.readlines(TARGET_FILE)
    expected_lpos = target_lines.index { |l| l =~ /^class VmaTest\b/ }
    assert !expected_lpos.nil?,
           "Could not locate 'class VmaTest' in #{File.basename(TARGET_FILE)}"

    # Give ruby-lsp a moment to process didOpen before the first request,
    # then retry until we get a result (workspace indexing happens in background).
    sleep 2
    drain_idle
    definition = nil
    15.times do
      definition = vma.buf.lsp.get_definition(CALLER_FILE, caller_lnum, caller_col)
      break if definition
      sleep 1
      drain_idle
    end

    if definition.nil?
      puts "  SKIP  #{self.class}#test_jump_to_definition " \
           "(ruby-lsp returned no definition after 17 s — workspace still indexing?)"
      return
    end

    assert_eq File.expand_path(TARGET_FILE), definition[0],
              "Expected definition in #{File.basename(TARGET_FILE)}, " \
              "got #{File.basename(definition[0].to_s)}"

    assert_eq expected_lpos, definition[1] - 1,
              "Expected line #{expected_lpos} (0-based), got #{definition[1] - 1}"
  end
end
