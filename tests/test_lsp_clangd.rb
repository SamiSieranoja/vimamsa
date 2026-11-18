require "tmpdir"

# Does LSP work for C++ with clangd, configured exactly as in custom.rb:
#
#   cnf.lsp.enabled = true
#   cnf.lsp.server.clangd = { name: "clangd", command: "clangd --offset-encoding=utf-8", type: "stdio" }
#   cnf.lsp.server.clangd.languages = ["c", "cpp"]
#
# Uses a small C++ file in a temp dir (with compile_flags.txt, so clangd needs
# no build setup). Uses `clangd`, or else the newest working `clangd-NN` on
# PATH (Ubuntu installs e.g. clangd-12 without the bare name). Skips if none
# runs; any other problem (server fails to start, wrong answers) is a failure.
#
# Run explicitly:
#   ruby exe/run_tests.rb lsp_clangd

class TestLspClangd < VmaTest
  SRC = <<~CPP
    struct Point { int x; int y; };

    int add(int a, int b) { return a + b; }

    int main() {
      Point p{1, 2};
      int s = add(p.x, p.y);
      const char *u = "ää"; int t = add(1, 2);
      return s + t + p.
    }
  CPP

  # First clangd binary on PATH that runs, or nil.
  def self.clangd_bin
    return @clangd_bin if defined?(@clangd_bin)
    cands = ["clangd"] + 40.downto(9).map { |n| "clangd-#{n}" }
    @clangd_bin = cands.find { |c| system("#{c} --version > /dev/null 2>&1") }
  end

  def configure_clangd
    require "vimamsa/langservp"
    cnf.lsp.enabled = true
    cnf.lsp.server.clangd = { name: "clangd", command: "#{self.class.clangd_bin} --offset-encoding=utf-8", type: "stdio" }
    cnf.lsp.server.clangd.languages = ["c", "cpp"]
  end

  # Opens the C++ file with the settings above, yields [buffer, lsp, path, dir].
  # One clangd process is shared by all tests of this class.
  def with_clangd
    skip "clangd not on PATH" if self.class.clangd_bin.nil?
    configure_clangd
    @@reset ||= %w[c cpp].each { |l| LangSrv.class_variable_get(:@@languages).delete(l) }
    Dir.mktmpdir("vma_clangd") do |dir|
      File.write(File.join(dir, "compile_flags.txt"), "-std=c++17\n")
      path = File.join(dir, "main.cpp")
      File.write(path, SRC)
      b = open_new_file(path)
      begin
        drain_idle
        assert b.lsp, "LSP did not start for #{File.basename(path)} (lang #{b.lang.inspect}): " \
                      "clangd failed to start or did not answer 'initialize' within 5 s"
        yield b, b.lsp, path, dir
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  ensure
    cnf.lsp.enabled = false
  end

  # [line, char] (0-based, Ruby chars) of the n-th occurrence of str in SRC
  def loc(str, n = 0)
    SRC.lines.each_with_index do |l, i|
      col = -1
      while (col = l.index(str, col + 1))
        return [i, col] if n == 0
        n -= 1
      end
    end
    raise "#{str} not in SRC"
  end

  # clangd parses in the background after didOpen: retry until non-empty.
  def retry_until(tries = 20)
    r = nil
    tries.times do
      r = yield
      break if r && !(r.respond_to?(:empty?) && r.empty?)
      sleep 0.5
      drain_idle
    end
    r
  end

  def test_document_symbols
    with_clangd do |_b, lsp, path|
      funcs = retry_until { lsp.document_functions(path) }
      assert funcs && !funcs.empty?, "no documentSymbol answer from clangd"
      names = funcs.map { |f| f[:name] }
      assert names.include?("add") && names.include?("main"), "functions: #{names.inspect}"
      assert_eq loc("int add")[0] + 1, funcs.find { |f| f[:name] == "add" }[:line]
    end
  end

  def test_jump_to_definition
    with_clangd do |_b, lsp, path|
      line, col = loc("add(p")
      d = retry_until { lsp.get_definition(path, line, col) }
      assert d, "no definition for `add` at #{line}:#{col}"
      assert_eq File.realpath(path), File.realpath(d[0])
      assert_eq loc("int add")[0] + 1, d[1]
    end
  end

  # Non-ASCII text before the cursor ("ää" = 2 chars, 4 bytes): the column
  # must be sent in the server's position encoding (utf-8 bytes with
  # --offset-encoding=utf-8, see LangSrv#lsp_character), else the lookup lands
  # 2 bytes early, on `t`.
  def test_jump_to_definition_after_non_ascii
    with_clangd do |_b, lsp, path|
      line, col = loc("add(1")
      d = retry_until { lsp.get_definition(path, line, col) }
      assert d, "no definition for `add` at #{line}:#{col} (line has non-ASCII text before it: " \
                "character vs. byte offset mismatch?)"
      assert_eq loc("int add")[0] + 1, d[1]
    end
  end

  # Edits reach clangd: textDocument/didChange is a notification, sent without
  # an id. With an id clangd rejected it (method not found) and kept the text
  # as opened, so after adding lines above, a lookup at the new position of
  # `add(p` hit what used to be there instead.
  def test_jump_to_definition_after_edit
    with_clangd do |b, lsp, path|
      retry_until { lsp.get_definition(path, *loc("add(p")) } # parsed
      b.insert_txt_at("// one\n// two\n", 0)
      drain_idle
      line, col = loc("add(p")
      d = retry_until { lsp.get_definition(path, line + 2, col) }
      assert d, "no definition for `add` after the edit"
      assert_eq loc("int add")[0] + 1 + 2, d[1], "clangd did not see the edit"
    end
  end

  def test_completion
    with_clangd do |_b, lsp, path|
      line, col = loc("p.\n")
      col += 2 # after "p."
      items = retry_until(10) do
        got = nil
        lsp.request_completion(path, line, col) { |r| got = r }
        20.times { break if got; sleep 0.1; drain_idle }
        got
      end
      assert items && !items.empty?, "no completion items after `p.`"
      texts = items.map { |i| i[:text] }
      assert texts.include?("x") && texts.include?("y"), "completions: #{texts.first(20).inspect}"
    end
  end

  # Headers: GtkSourceView calls .hpp/.hh "cpphdr" and .h "chdr"; they must
  # use the clangd started for "cpp"/"c" (same process as main.cpp).
  # .hxx is unknown to GtkSourceView and falls back to "cpp".
  def test_header_files_use_clangd
    with_clangd do |_b, lsp, _path, dir|
      %w[point.hpp point.hh point.hxx].each do |name|
        hpath = File.join(dir, name)
        File.write(hpath, "#pragma once\nstruct Pt { int x; };\ninline int twice(int v) { return 2 * v; }\n")
        hb = open_new_file(hpath)
        begin
          drain_idle
          assert hb.lsp, "no LSP for #{name} (lang #{hb.lang.inspect})"
          assert hb.lsp.equal?(lsp), "#{name} started a separate server instead of sharing main.cpp's"
          funcs = retry_until { hb.lsp.document_functions(hpath) }
          assert funcs && funcs.map { |f| f[:name] }.include?("twice"), "#{name} symbols: #{funcs.inspect}"
        ensure
          vma.buffers.close_buffer(hb.id)
        end
      end
    end
  end

  def context_menu_labels(view)
    m = view.instance_variable_get(:@context_menu).menu_model
    (0...m.n_items).map { |i| m.get_item_attribute_value(i, "label", GLib::VariantType::STRING) }
  ensure
    view.instance_variable_get(:@context_menu)&.popdown
  end

  # Right-click menu offers "Jump to Definition" when the buffer has LSP, and
  # choosing it jumps.
  def test_context_menu_jump_to_definition
    with_clangd do |b, _lsp, path|
      line, col = loc("add(p")
      b.set_pos(b.line_range(line, 1).begin + col)
      b.view.show_context_menu(5, 5)
      drain_idle
      assert context_menu_labels(b.view).include?("Jump to Definition")
      # show_context_menu moved the cursor to the click; put it back on `add`
      b.set_pos(b.line_range(line, 1).begin + col)
      sleep 1 # let clangd parse
      vma.gui.app.lookup_action("ctx_lsp_jump_to_definition").activate(nil)
      drain_idle
      assert_eq loc("int add")[0], vma.buf.lpos
    end
  end

  def test_no_context_menu_item_without_lsp
    b = vma.buf # plain text test buffer, LSP disabled
    b.view.show_context_menu(5, 5)
    drain_idle
    assert !context_menu_labels(b.view).include?("Jump to Definition")
  end

  # Saving an untitled buffer as .cpp attaches LSP (and the menu item).
  def test_save_as_cpp_attaches_lsp
    with_clangd do |_b, lsp, _path, dir|
      nb = create_new_buffer("int main() { return 0; }\n", "untitled")
      begin
        assert_eq nil, nb.lsp
        nb.save_as_callback(File.join(dir, "new.cpp"))
        drain_idle
        assert nb.lsp.equal?(lsp), "no LSP after Save As .cpp"
        nb.view.show_context_menu(5, 5)
        drain_idle
        assert context_menu_labels(nb.view).include?("Jump to Definition")
      ensure
        vma.buffers.close_buffer(nb.id)
      end
    end
  end

  # The pnnfast.c case: a header in another dir, no compile flags -> clangd
  # drops declarations using its types, so definition lookup finds nothing.
  # After adding compile_flags.txt, :lsp_restart (new clangd, buffers
  # reattached) makes it work, and the old clangd process exits.
  def test_restart_picks_up_compile_flags
    with_clangd do |_b, _lsp, _path, dir|
      inc = File.join(dir, "inc")
      Dir.mkdir(inc)
      File.write(File.join(inc, "types.h"), "typedef struct { int n; } CODEBOOK;\ntypedef double dist_t;\n")
      cpath = File.join(dir, "prog.c")
      # Like pnnfast.c: more than clang's error limit (19) of unknown-type
      # errors before calc(), so without the header clang stops parsing
      # before reaching it.
      decls = (1..25).map { |i| "dist_t v#{i};\n" }.join
      File.write(cpath, "#include \"types.h\"\n#{decls}void calc(CODEBOOK *cb) { cb->n = 1; }\nint main() { CODEBOOK c; calc(&c); return 0; }\n")
      File.write(File.join(dir, "compile_flags.txt"), "") # no -Iinc yet
      cb = open_new_file(cpath)
      begin
        drain_idle
        old = cb.lsp
        assert old, "no LSP for prog.c"
        call = [27, "int main() { CODEBOOK c; ".size]
        sleep 1
        assert_eq nil, old.get_definition(cpath, *call), "should fail without include path"

        File.write(File.join(dir, "compile_flags.txt"), "-Iinc\n")
        old_pid = old.pid
        act :lsp_restart
        assert cb.lsp && !cb.lsp.equal?(old), "buffer not reattached to a new server"
        d = retry_until { cb.lsp.get_definition(cpath, *call) }
        assert d, "no definition after restart"
        assert_eq [File.realpath(cpath), 27], [File.realpath(d[0]), d[1]]

        # the old clangd exits (and is reaped)
        gone = false
        30.times do
          begin
            Process.kill(0, old_pid)
          rescue Errno::ESRCH
            gone = true
            break
          end
          sleep 0.1
        end
        assert gone, "old clangd (pid #{old_pid}) still running"
      ensure
        vma.buffers.close_buffer(cb.id)
      end
    end
  end
end
