require "tmpdir"

# :extract_file_links lists the existing files named in the current file in a
# new buffer, one absolute path per line.
class TestExtractFileLinks < VmaTest
  def with_dir
    Dir.mktmpdir do |dir|
      File.write("#{dir}/a.pdf", "x")
      FileUtils.mkdir_p("#{dir}/sub")
      File.write("#{dir}/sub/b.txt", "x")
      File.write("#{dir}/notes.txt", "x")
      # Real image: opening a buffer with ⟦img:...⟧ renders it
      GdkPixbuf::Pixbuf.new(colorspace: :rgb, has_alpha: false, bits_per_sample: 8,
                            width: 1, height: 1).save("#{dir}/img.png", "png")
      yield dir
    end
  end

  def open_with(dir, text)
    path = "#{dir}/main.txt"
    File.write(path, text)
    b = open_new_file(path)
    drain_idle
    b
  end

  def test_extracts_existing_files_in_order
    with_dir do |dir|
      text = "See (a.pdf), sub/b.txt and missing.pdf.\n" \
             "Again a.pdf; link ⟦notes⟧ image ⟦img:img.png⟧ dir sub/ url https://x.org/a.pdf\n" \
             "abs #{dir}/sub/b.txt plain words only\n"
      b = open_with(dir, text)
      begin
        act :extract_file_links
        assert_eq "#{dir}/a.pdf\n#{dir}/sub/b.txt\n#{dir}/notes.txt\n#{dir}/img.png\n", vma.buf.to_s
        assert vma.buf.fname.nil?, "result should be an unsaved buffer"
        vma.buffers.close_buffer(vma.buf.id)
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end

  def test_no_links_creates_no_buffer
    with_dir do |dir|
      b = open_with(dir, "nothing here, missing.pdf\n")
      begin
        act :extract_file_links
        assert_eq b.id, vma.buf.id
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end
end
