# LSP jump-to-definition test.
# Configures ruby-lsp internally — no custom.rb setup required.
# Skips gracefully if 'bundle exec ruby-lsp' is unavailable or times out.
#
# Run explicitly:
#   ruby exe/run_tests.rb test_lsp_jump

class TestLspJumpToDefinition < VmaTest
  REPO_ROOT = File.expand_path("../../", __FILE__)

  # We jump from the `LangSrv` reference in buffer.rb to `class LangSrv` in
  # langservp.rb. The reference is inside `module Vimamsa`, so ruby-lsp can
  # resolve it statically. (A top-level reference such as `< VmaTest` in a
  # test file can't be: VmaTest is Vimamsa::VmaTest, reachable only because
  # Vimamsa is mixed into Object at runtime. ruby-lsp answers [] for it.)
  CALLER_FILE = File.join(REPO_ROOT, "lib/vimamsa/buffer.rb")
  CALLER_LINE = /LangSrv\.when_ready/
  TOKEN = "LangSrv"

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
    LangSrv.forget("ruby")

    # Open the caller file — this triggers LSP initialisation for "ruby".
    open_new_file(CALLER_FILE)
    wait_for_lsp(vma.buf)
    skip "ruby-lsp unavailable — is 'bundle exec ruby-lsp' installed?" unless vma.buf.lsp

    caller_lines = File.readlines(CALLER_FILE)
    caller_lnum = caller_lines.index { |l| l =~ CALLER_LINE }
    assert !caller_lnum.nil?, "no #{CALLER_LINE.inspect} line in #{File.basename(CALLER_FILE)}"
    caller_col = caller_lines[caller_lnum].index(TOKEN)

    # Retry until ruby-lsp has indexed the workspace (in the background
    # after initialize; it answers [] until then, a few seconds)
    definition = poll_until(timeout: 20) {
      vma.buf.lsp.get_definition(CALLER_FILE, caller_lnum, caller_col)
    }
    assert !definition.nil?, "ruby-lsp found no definition for #{TOKEN} within 20 s"

    # The file and line it points at define the class. (Not one fixed path:
    # another copy of the sources in the workspace, e.g. under build/, may
    # be listed first.)
    path, line = definition
    assert_eq "langservp.rb", File.basename(path.to_s), "definition in #{path}"
    text = File.readlines(path)[line - 1].to_s
    assert text =~ /^\s*class LangSrv\b/, "definition line #{line} of #{path} is #{text.inspect}"
  end
end
