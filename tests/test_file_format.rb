require "tmpdir"

# Files that are not UTF-8 / \n (e.g. Latin-1 with CRLF) open converted to
# UTF-8 + \n; the first save asks whether to keep the original format.
class TestFileFormat < VmaTest
  LATIN1_CRLF = "/* caf\xE9 */\r\nint x;\r\n".b

  def with_file(bytes, name = "f.c")
    Dir.mktmpdir do |dir|
      path = File.join(dir, name)
      File.binwrite(path, bytes)
      b = nil
      begin
        b = open_new_file(path)
        drain_idle
        yield b, path
      ensure
        PopupFormGenerator.reset_popup_queue
        vma.buffers.close_buffer(b.id) if b
      end
    end
  end

  # Press button `id` in the active popup.
  def answer_popup(id)
    popup = PopupFormGenerator.class_variable_get(:@@popup_active)
    assert popup, "no popup shown"
    popup.instance_variable_get(:@ret)[id] = "submit"
    popup.submit
    drain_idle
  end

  # Saving writes from a thread (truncate, then write): wait until the file
  # has new, non-empty content.
  def wait_for_write(path, old)
    data = nil
    50.times do
      data = File.binread(path)
      break if data != old && !data.empty?
      sleep 0.05
    end
    data
  end

  def test_latin1_crlf_file_opens_as_utf8
    with_file(LATIN1_CRLF) do |b, path|
      assert b, "file did not open"
      assert_eq "/* café */\nint x;\n", b.to_s
      assert_eq Encoding::UTF_8, b.to_s.encoding
      assert_eq "ISO-8859-1 with CRLF line endings", b.file_format_desc
      assert file_is_text_file(path)
    end
  end

  def test_save_keep_original_format
    with_file(LATIN1_CRLF) do |b, path|
      b.insert_txt_at("int y;\n", b.line_range(1, 1).begin) # before "int x;"
      b.save
      assert PopupFormGenerator.popup_active?, "first save should ask"
      assert_eq LATIN1_CRLF, File.binread(path) # nothing written yet
      answer_popup("keep_btn")
      data = wait_for_write(path, LATIN1_CRLF)
      assert_eq "/* caf\xE9 */\r\nint y;\r\nint x;\r\n".b, data

      # second save does not ask again
      b.insert_txt_at("z", 0)
      b.save
      assert !PopupFormGenerator.popup_active?, "asked twice"
      assert_eq "z/* caf\xE9 */\r\n".b, wait_for_write(path, data)[0, 13]
    end
  end

  def test_save_convert_to_utf8
    with_file(LATIN1_CRLF) do |b, path|
      b.save
      answer_popup("convert_btn")
      assert_eq "/* café */\nint x;\n".b, wait_for_write(path, LATIN1_CRLF)
    end
  end

  # A character Latin-1 cannot hold: saved as UTF-8 (CRLF kept), with a message.
  def test_keep_falls_back_to_utf8_for_unencodable_text
    with_file(LATIN1_CRLF) do |b, path|
      b.insert_txt_at("€", 0)
      b.save
      answer_popup("keep_btn")
      assert_eq "€/* café */\r\nint x;\r\n".b, wait_for_write(path, LATIN1_CRLF)
      msgs = $vmag.instance_variable_get(:@minibuf_messages)
      assert msgs.first(3).any? { |m| m.include?("Cannot save f.c as ISO-8859-1") }, msgs.first(3).inspect
    end
  end

  def test_utf8_lf_file_saves_without_asking
    with_file("int ä;\n") do |b, path|
      assert_eq nil, b.file_format_desc
      b.insert_txt_at("x", 0)
      b.save
      assert !PopupFormGenerator.popup_active?
      assert_eq "xint ä;\n".b, wait_for_write(path, "int ä;\n".b)
    end
  end

  # `vimamsa <file>` with an instance running drops the path into the listen
  # dir; non-UTF-8 files used to be ignored there without a message.
  def test_file_from_command_line_opens
    Dir.mktmpdir do |dir|
      path = File.join(dir, "pnn.c")
      File.binwrite(path, LATIN1_CRLF)
      drop = File.join(dir, "vmarun-test")
      File.write(drop, path)
      vma.open_file_listener([drop])
      drain_idle
      b = vma.buffers.list.find { |x| x.fname == path }
      assert b, "file from listen dir was not opened"
      assert_eq "/* café */\nint x;\n", b.to_s
      vma.buffers.close_buffer(b.id)
    end
  end

  # Settings > Behavior: cnf.file_format.on_save = "keep" / "convert" saves
  # without asking.
  def with_on_save(value)
    old = cnf.file_format.on_save!
    cnf.file_format.on_save = value
    yield
  ensure
    cnf.file_format.on_save = old
  end

  def test_setting_keep_saves_original_without_asking
    with_on_save("keep") do
      with_file(LATIN1_CRLF) do |b, path|
        b.insert_txt_at("z", 0)
        b.save
        assert !PopupFormGenerator.popup_active?, "should not ask"
        assert_eq "z/* caf\xE9 */\r\nint x;\r\n".b, wait_for_write(path, LATIN1_CRLF)
      end
    end
  end

  def test_setting_convert_saves_utf8_without_asking
    with_on_save("convert") do
      with_file(LATIN1_CRLF) do |b, path|
        b.save
        assert !PopupFormGenerator.popup_active?, "should not ask"
        assert_eq "/* café */\nint x;\n".b, wait_for_write(path, LATIN1_CRLF)
      end
    end
  end

  # An answer given in the dialog wins over a later change of the setting.
  def test_answer_overrides_setting
    with_file(LATIN1_CRLF) do |b, path|
      b.save
      answer_popup("convert_btn")
      data = wait_for_write(path, LATIN1_CRLF)
      with_on_save("keep") do
        b.insert_txt_at("z", 0)
        b.save
        assert_eq "z/* café */\n".b, wait_for_write(path, data)[0, 13]
      end
    end
  end

  def test_setting_in_settings_dialog
    s = SETTINGS_DEFS.flat_map { |g| g[:settings] }.find { |x| x[:key] == [:file_format, :on_save] }
    assert s, "file_format.on_save missing from the settings dialog"
    assert_eq ["ask", "keep", "convert"], s[:options]
    assert_eq "ask", cnf.file_format.on_save!
  end

  # git diff of a Latin-1 + CRLF file: shown as UTF-8 with \n, no error.
  def test_git_diff_of_latin1_file
    skip("git not installed") unless system("which git >/dev/null 2>&1")
    Dir.mktmpdir do |dir|
      path = File.join(dir, "f.c")
      File.binwrite(path, LATIN1_CRLF)
      system("git", "-C", dir, "init", "-q")
      system("git", "-C", dir, "add", "f.c")
      system("git", "-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
      File.binwrite(path, "/* caf\xE9 */\r\nint y;\r\n".b)
      b = open_new_file(path)
      begin
        git_diff_buffer
        d = vma.buf
        assert !d.equal?(b), "no diff buffer"
        assert_eq Encoding::UTF_8, d.to_s.encoding
        assert d.to_s.valid_encoding?
        assert d.to_s.include?(" /* café */\n"), d.to_s
        assert d.to_s.include?("-int x;\n+int y;\n"), d.to_s
        assert !d.to_s.include?("\r")
        vma.buffers.close_buffer(d.id)
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end

  # Diff of unsaved changes: the buffer (UTF-8 + \n) is compared with the file
  # as loaded, so only the edited line differs, not every line.
  def test_diff_unsaved_of_latin1_file
    with_file("/* caf\xE9 */\r\nint x;\r\nint z;\r\n".b) do |b, path|
      b.insert_txt_at("q", b.line_range(2, 1).begin) # "qint z;"
      diff_buffer
      d = vma.buf
      changed = d.to_s.lines.select { |l| l =~ /^[-+][^-+]/ }
      assert_eq ["-int z;\n", "+qint z;\n"], changed
      assert d.to_s.start_with?("--- #{path}\n+++ #{path}\n"), d.to_s.lines.first(2).inspect
      # enter on the changed line jumps back to the file
      d.set_pos(d.to_s.index("+qint"))
      diff_buffer_jump_to_source
      assert vma.buf.equal?(b), "did not jump to the file"
      assert_eq 2, b.lpos
      vma.buffers.close_buffer(d.id)
    end
  end
end
