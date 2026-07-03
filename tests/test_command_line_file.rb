require "tmpdir"

class TestCommandLineFile < VmaTest
  def test_missing_command_line_file_is_not_created
    Dir.mktmpdir do |dir|
      path = File.join(dir, "created.txt")

      result = open_new_file(path)

      assert !result, "opening a missing file should not return a buffer"
      assert !File.exist?(path), "missing command-line path should not be created"
    end
  end

  def test_existing_command_line_file_keeps_its_contents
    Dir.mktmpdir do |dir|
      path = File.join(dir, "existing.txt")
      File.write(path, "existing contents\n")

      open_new_file(path)

      assert_eq path, vma.buf.fname
      assert_eq "existing contents\n", vma.buf.to_s
      assert_eq "existing contents\n", File.read(path)
    end
  end
end
