require "tmpdir"

class TestAck < VmaTest
  # Regression: ack output from a latin-1 file used to raise
  # "invalid byte sequence in UTF-8" in Ack#ack_buffer and kill the editor.
  def test_non_utf8_match_does_not_raise
    if `which ack ack-grep 2>/dev/null`.strip.empty?
      skip "ack not installed"
    end
    Dir.mktmpdir do |dir|
      File.binwrite("#{dir}/latin1.c", "needlexyz caf\xE9\n".b)
      vma.define_singleton_method(:get_content_search_paths) { [dir] }
      begin
        Ack.new.ack_buffer("needlexyz")
        drain_idle
      ensure
        vma.singleton_class.send(:remove_method, :get_content_search_paths)
      end
      assert_eq true, vma.buf.to_s.include?("latin1.c:1:needlexyz caf")
    end
  end
end
