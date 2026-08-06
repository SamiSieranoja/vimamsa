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

  # FileManager.cur used to raise NameError (uninitialized class variable @@cur)
  # when the file selector had never been opened, crashing any action that
  # called it.
  def test_cur_is_nil_before_file_selector_is_opened
    without_current_filemanager {
      assert_eq nil, Vimamsa::FileManager.cur, "cur should be nil, not raise"
    }
  end

  def test_with_cur_does_not_yield_when_no_file_manager
    without_current_filemanager {
      yielded = false
      ret = Vimamsa::FileManager.with_cur { |fm| yielded = true }
      assert !yielded, "block should not run without an open file selector"
      assert_eq nil, ret
    }
  end

  def test_with_cur_yields_the_current_file_manager
    fm = Vimamsa::FileManager.new
    prev = Vimamsa::FileManager.cur
    Vimamsa::FileManager.class_variable_set(:@@cur, fm)
    begin
      assert_eq fm, Vimamsa::FileManager.with_cur { |x| x }
    ensure
      Vimamsa::FileManager.class_variable_set(:@@cur, prev)
    end
  end

  private

  # Run blk with no file selector open (@@cur = nil), restoring it afterwards.
  def without_current_filemanager
    prev = Vimamsa::FileManager.cur
    Vimamsa::FileManager.class_variable_set(:@@cur, nil)
    begin
      yield
    ensure
      Vimamsa::FileManager.class_variable_set(:@@cur, prev)
    end
  end
end
