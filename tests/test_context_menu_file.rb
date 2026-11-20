require "tmpdir"

# Right-clicking text that names an existing file offers to open it.
class TestContextMenuFile < VmaTest
  def menu_labels(view)
    m = view.instance_variable_get(:@context_menu).menu_model
    (0...m.n_items).map { |i| m.get_item_attribute_value(i, "label", GLib::VariantType::STRING) }
  ensure
    view.instance_variable_get(:@context_menu)&.popdown
  end

  # Buffer for dir/notes.txt whose first word is first_word; right-click on it.
  def with_menu(first_word)
    Dir.mktmpdir do |dir|
      File.binwrite("#{dir}/foobar.pdf", "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n\xFF\xFEbinary".b)
      File.write("#{dir}/other.txt", "hello\n")
      path = "#{dir}/notes.txt"
      File.write(path, "#{first_word} rest of line\n")
      b = open_new_file(path)
      begin
        drain_idle
        # Point inside the first word (widget x 5 is in the line-number gutter)
        x, y = b.view.buffer_to_window_coords(:widget, 5, 5)
        b.view.show_context_menu(x, y)
        drain_idle
        yield b, menu_labels(b.view), dir
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end

  def test_binary_file_opens_externally
    with_menu("foobar.pdf") do |b, labels, dir|
      assert labels.include?("Open file (external)"), labels.inspect
      assert !labels.include?("Open file"), labels.inspect
      opened = nil
      orig = Vimamsa.instance_method(:open_with_default_program)
      Vimamsa.send(:define_method, :open_with_default_program) { |p| opened = p }
      begin
        vma.gui.app.lookup_action("ctx_open_file_external").activate(nil)
        drain_idle
      ensure
        Vimamsa.send(:define_method, :open_with_default_program, orig)
      end
      assert_eq File.join(dir, "foobar.pdf"), opened
    end
  end

  def test_text_file_can_open_in_editor
    with_menu("(other.txt).") do |b, labels, dir|
      assert labels.include?("Open file"), labels.inspect
      assert labels.include?("Open file (external)"), labels.inspect
      vma.gui.app.lookup_action("ctx_open_file").activate(nil)
      drain_idle
      assert_eq File.join(dir, "other.txt"), vma.buf.fname
      vma.buffers.close_buffer(vma.buf.id)
    end
  end

  # ⟦help:keybindings⟧ opened from the context menu shows the key bindings,
  # like opening it with the keyboard does
  def test_help_link_opens_from_menu
    with_menu("⟦help:keybindings⟧") do |_b, labels, _dir|
      assert labels.include?("Open link"), labels.inspect
      called = nil
      orig = Vimamsa.instance_method(:call_action)
      Vimamsa.send(:define_method, :call_action) { |id, *a| called = id }
      begin
        vma.gui.app.lookup_action("ctx_open_link").activate(nil)
        drain_idle
      ensure
        Vimamsa.send(:define_method, :call_action, orig)
      end
      assert_eq :show_key_bindings, called
    end
  end

  def test_no_item_for_missing_file
    with_menu("missing.pdf") do |_b, labels, _dir|
      assert !labels.any? { |l| l.start_with?("Open file") }, labels.inspect
    end
  end

  # gf opens the file whose path is under the cursor (like vim)
  def test_gf_opens_file_under_cursor
    Dir.mktmpdir do |dir|
      File.write("#{dir}/other.txt", "hello\n")
      File.write("#{dir}/n.txt", "see (other.txt). missing.txt\n")
      b = open_new_file("#{dir}/n.txt")
      begin
        drain_idle
        b.set_pos(b.to_s.index("other.txt") + 3)
        keys("g f")
        drain_idle
        assert_eq File.join(dir, "other.txt"), vma.buf.fname
        vma.buffers.close_buffer(vma.buf.id)
        drain_idle

        vma.buffers.set_current_buffer(b.id) if vma.buf != b
        b.set_pos(b.to_s.index("missing.txt") + 2)
        keys("g f")
        drain_idle
        assert_eq b.fname, vma.buf.fname
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end

  def test_gf_opens_binary_file_externally
    Dir.mktmpdir do |dir|
      File.binwrite("#{dir}/foobar.pdf", "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n\xFF\xFEbinary".b)
      File.write("#{dir}/n.txt", "foobar.pdf\n")
      b = open_new_file("#{dir}/n.txt")
      opened = nil
      orig = Vimamsa.instance_method(:open_with_default_program)
      Vimamsa.send(:define_method, :open_with_default_program) { |p| opened = p }
      begin
        drain_idle
        b.set_pos(2)
        keys("g f")
        drain_idle
        assert_eq File.join(dir, "foobar.pdf"), opened
      ensure
        Vimamsa.send(:define_method, :open_with_default_program, orig)
        vma.buffers.close_buffer(b.id)
      end
    end
  end

  def test_file_path_at
    Dir.mktmpdir do |dir|
      File.write("#{dir}/a.pdf", "x")
      b = open_new_file(File.write("#{dir}/n.txt", "see \"a.pdf\", and #{dir}/a.pdf b.pdf\n") && "#{dir}/n.txt")
      begin
        s = b.to_s
        assert_eq "#{dir}/a.pdf", b.file_path_at(s.index("a.pdf"))
        assert_eq "#{dir}/a.pdf", b.file_path_at(s.index("#{dir}/a.pdf") + 2)
        assert_eq nil, b.file_path_at(s.index("b.pdf"))
        assert_eq nil, b.file_path_at(s.index("see"))
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end
end
