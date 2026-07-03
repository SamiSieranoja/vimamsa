require "tmpdir"

class TestFileManager < VmaTest
  def test_sort_mtime_orders_directories_too
    Dir.mktmpdir("vimamsa-fexp-") do |dir|
      older = File.join(dir, "older_dir")
      newer = File.join(dir, "newer_dir")
      afile = File.join(dir, "afile.txt")
      bfile = File.join(dir, "bfile.txt")

      Dir.mkdir(older)
      sleep 1
      Dir.mkdir(newer)
      File.write(afile, "a")
      sleep 1
      File.write(bfile, "b")

      fm = Vimamsa::FileManager.new
      fm.dir_to_buf(dir)
      fm.sort_mtime

      lines = vma.buf.to_s.lines.map(&:chomp)
      dir_lines = lines[3, 2]
      file_lines = lines[6, 2]

      assert_eq ["newer_dir", "older_dir"], dir_lines, "directories should be sorted by mtime descending"
      assert_eq ["bfile.txt", "afile.txt"], file_lines, "files should remain sorted by mtime descending"
    end
  end
end
