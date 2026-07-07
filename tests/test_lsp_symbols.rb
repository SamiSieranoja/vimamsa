# LSP documentSymbol test — exercises LangSrv#document_functions (and the
# shared request_document_symbols scaffolding it now delegates to).
# Skips gracefully if 'bundle exec ruby-lsp' is unavailable or times out.
#
# Run explicitly:
#   ruby exe/run_tests.rb test_lsp_symbols

class TestLspSymbols < VmaTest
  REPO_ROOT = File.expand_path("../../", __FILE__)
  # test_framework.rb defines VmaTest with clearly named methods (run_all, etc.)
  SYMBOL_FILE = File.join(REPO_ROOT, "lib/vimamsa/test_framework.rb")

  def configure_ruby_lsp
    require "vimamsa/langservp"
    cnf.lsp.enabled = true
    cnf.lsp.server.ruby_lsp = {
      name: "ruby-lsp",
      command: "bundle exec ruby-lsp",
      languages: ["ruby"],
      rooturi: "file://#{REPO_ROOT}",
    }
    LangSrv.class_variable_get(:@@languages).delete("ruby")
  end

  def test_document_functions_lists_methods
    configure_ruby_lsp
    open_new_file(SYMBOL_FILE)
    drain_idle

    lsp = vma.buf.lsp
    unless lsp
      puts "  SKIP  #{self.class}#test_document_functions_lists_methods " \
           "(ruby-lsp unavailable — is 'bundle exec ruby-lsp' installed?)"
      return
    end

    # documentSymbol is per-file; give didOpen a moment, then retry.
    sleep 1
    drain_idle
    funcs = nil
    15.times do
      funcs = lsp.document_functions(SYMBOL_FILE)
      break if funcs && !funcs.empty?
      sleep 1
      drain_idle
    end

    if funcs.nil? || funcs.empty?
      puts "  SKIP  #{self.class}#test_document_functions_lists_methods " \
           "(ruby-lsp returned no symbols — still indexing?)"
      return
    end

    # Shape: [{ name:, line: }, ...] with 1-based lines.
    assert(funcs.all? { |f| f.key?(:name) && f.key?(:line) },
           "each entry should have :name and :line")
    names = funcs.map { |f| f[:name] }
    assert(names.include?("run_all"),
           "expected method 'run_all' among symbols, got: #{names.first(20).inspect}")

    # Cross-check the reported line against the file (1-based).
    entry = funcs.find { |f| f[:name] == "run_all" }
    file_lines = File.readlines(SYMBOL_FILE)
    assert(entry[:line] > 0, "run_all should have a real line number")
    assert(file_lines[entry[:line] - 1] =~ /def\s+run_all\b/,
           "line #{entry[:line]} should hold 'def run_all', got: #{file_lines[entry[:line] - 1].inspect}")
  end
end
