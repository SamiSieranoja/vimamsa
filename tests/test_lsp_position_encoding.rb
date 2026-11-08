require "tmpdir"

# LangSrv#lsp_character converts Ruby character columns to the units of the
# server's position encoding. Needs no language server.
class TestLspPositionEncoding < VmaTest
  LINE = "s = \"ää😀\"; x\n" # "x" is at char 11

  def with_lsp(encoding)
    require "vimamsa/langservp"
    lsp = LangSrv.allocate
    lsp.instance_variable_set(:@position_encoding, encoding)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "a.c")
      File.write(path, "first\n#{LINE}")
      yield lsp, path
    end
  end

  def test_utf8_counts_bytes
    with_lsp("utf-8") { |lsp, path| assert_eq 16, lsp.lsp_character(path, 1, 11) }
  end

  def test_utf16_counts_code_units
    with_lsp("utf-16") { |lsp, path| assert_eq 12, lsp.lsp_character(path, 1, 11) }
  end

  def test_utf32_counts_chars
    with_lsp("utf-32") { |lsp, path| assert_eq 11, lsp.lsp_character(path, 1, 11) }
  end

  def test_ascii_prefix_unchanged
    with_lsp("utf-8") { |lsp, path| assert_eq 3, lsp.lsp_character(path, 1, 3) }
  end

  def test_file_uri_and_open_buffer
    with_lsp("utf-8") do |lsp, path|
      b = open_new_file(path)
      begin
        # The open buffer, not the file on disk, is what the server sees.
        b.set_pos(b.line_range(1, 1).begin)
        b.insert_txt("ö")
        uri = lsp.file_uri(path)
        assert_eq 18, lsp.lsp_character(uri, 1, 12)
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end
end
