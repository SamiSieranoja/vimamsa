require "tmpdir"

# alt-h / alt-l switch to the previous/next file in the file panel's display
# order (dirs sorted by name, files sorted within each dir) while the panel is
# open, and do nothing while it is hidden. See FileTreePanel#select_adjacent.
class TestFilePanel < VmaTest

  # Two files in one fresh temp dir: adjacent names in the same dir group are
  # guaranteed adjacent in the flattened panel order, whatever other buffers
  # exist from earlier tests.
  def with_two_files(same_content: false)
    Dir.mktmpdir do |dir|
      fa = File.join(dir, "aaa.txt")
      fb = File.join(dir, "bbb.txt")
      File.write(fa, same_content ? "x\n" : "a\n")
      File.write(fb, same_content ? "x\n" : "b\n")
      ba = open_new_file(fa)
      bb = open_new_file(fb)
      begin
        yield ba, bb
      ensure
        vma.buffers.close_buffer(ba.id)
        vma.buffers.close_buffer(bb.id)
      end
    end
  end

  def with_panel_open
    act :toggle_file_panel unless vma.gui.file_panel_shown?
    yield
  ensure
    act :toggle_file_panel if vma.gui.file_panel_shown?
  end

  def test_alt_h_l_move_in_panel_order
    with_two_files do |ba, bb|
      with_panel_open do
        assert_eq bb.id, vma.buf.id       # opened last
        keys("alt-h")                     # prev file in panel order
        assert_eq ba.id, vma.buf.id
        keys("alt-l")                     # next file in panel order
        assert_eq bb.id, vma.buf.id
      end
    end
  end

  # The current file's row is bold with the brighter fg; the others are plain.
  # Same contents: Buffer < String, so buffer identity must not use ==.
  def test_current_file_row_is_highlighted
    with_two_files(same_content: true) do |ba, bb|
      with_panel_open do
        fp = vma.gui.file_panel
        assert_eq fp.current_markup("● bbb.txt"), fp.row_labels[bb.id]
        assert_eq "  aaa.txt", fp.row_labels[ba.id]
        keys("alt-h")
        assert_eq fp.current_markup("● aaa.txt"), fp.row_labels[ba.id]
        assert_eq "  bbb.txt", fp.row_labels[bb.id]
      end
    end
  end

  # g s labels the panel's file rows; typing a label switches to that file.
  # Labels follow panel order: first file row gets "A", second "S", ...
  def test_easy_jump_picks_file_by_label
    with_two_files do |ba, bb|
      with_panel_open do
        assert_eq bb.id, vma.buf.id
        keys("g s")
        assert vma.gui.file_panel.easy_jump_active?, "picker should be active after g s"
        # ba ("aaa.txt") sorts first in its dir group; find its label.
        label = nil
        vma.gui.file_panel.instance_variable_get(:@ej_targets).each do |l, id|
          label = l if id == ba.id
        end
        assert label, "no label assigned to aaa.txt"
        # one token per keystroke (labels are 2 chars when many buffers exist)
        keys(label.downcase.chars.join(" "))
        assert_eq ba.id, vma.buf.id
        assert_eq false, vma.gui.file_panel.easy_jump_active?
      end
    end
  end

  # g s labels are reddish markup spans in front of the (escaped) file name.
  def test_easy_jump_labels_are_colored
    with_two_files do |ba, bb|
      with_panel_open do
        fp = vma.gui.file_panel
        keys("g s")
        label = fp.instance_variable_get(:@ej_targets).key(ba.id)
        markup = fp.row_labels[ba.id]
        assert markup.start_with?(fp.ej_label_markup(label)), "label span missing: #{markup}"
        assert markup.include?(fp.panel_color(:file_panel_ej_label_fg))
        assert markup.end_with?("aaa.txt")
        # the current row's label keeps its own span ahead of the bold name
        cur = fp.row_labels[bb.id]
        assert cur.start_with?(fp.ej_label_markup(fp.instance_variable_get(:@ej_targets).key(bb.id)))
        keys("esc")
        assert_eq false, fp.row_labels[ba.id].include?("<span")
      end
    end
  end

  # Row text is markup, so file names with markup chars must be escaped.
  def test_file_name_markup_is_escaped
    Dir.mktmpdir do |dir|
      fn = File.join(dir, "a&<b>.txt")
      File.write(fn, "x\n")
      b = open_new_file(fn)
      begin
        with_panel_open do
          assert vma.gui.file_panel.row_labels[b.id].include?("a&amp;&lt;b&gt;.txt")
        end
      ensure
        vma.buffers.close_buffer(b.id)
      end
    end
  end

  def test_easy_jump_esc_cancels
    with_two_files do |ba, bb|
      with_panel_open do
        before = vma.buf.id
        keys("g s")
        assert vma.gui.file_panel.easy_jump_active?
        keys("esc")
        assert_eq false, vma.gui.file_panel.easy_jump_active?
        assert_eq before, vma.buf.id
        # keyboard override removed: normal keys work again (alt-h moves)
        keys("alt-h")
        assert_eq ba.id, vma.buf.id
      end
    end
  end

  def test_easy_jump_noop_when_panel_hidden
    with_two_files do |ba, bb|
      before = vma.buf.id
      keys("g s")
      assert_eq false, !!vma.gui.file_panel.easy_jump_active?
      assert_eq before, vma.buf.id
    end
  end

  def test_alt_h_l_noop_when_panel_hidden
    with_two_files do |ba, bb|
      assert_eq false, !!vma.gui.file_panel_shown?
      before = vma.buf.id
      keys("alt-h")
      assert_eq before, vma.buf.id
      keys("alt-l")
      assert_eq before, vma.buf.id
    end
  end

  # File rows carry a close (x) icon right in front of the name; folder rows
  # don't. Press shows a pressed background; release on the same button
  # closes the file, release elsewhere cancels.
  def test_close_button_closes_file
    with_two_files do |ba, bb|
      with_panel_open do
        fp = vma.gui.file_panel
        drain_idle # lay out the tree so cell areas exist
        fp.file_rows.each_value { |it| assert it[FileTreePanel::COL_CLOSE].include?(FileTreePanel::CLOSE_GLYPH) }
        fp.instance_variable_get(:@store).each do |_m, _p, it|
          assert_eq nil, it[FileTreePanel::COL_CLOSE] if it[FileTreePanel::COL_BUF_ID] == 0
        end

        # hit test: the icon cell hits, the name text right after it doesn't
        x, y = fp.close_button_center(ba.id)
        assert_eq ba.id, fp.close_hit(x, y)
        assert_eq nil, fp.close_hit(x + fp.close_w, y)

        # hover tint, then pressed tint
        fp.set_close_hover(ba.id)
        assert fp.file_rows[ba.id][FileTreePanel::COL_CLOSE].include?(fp.panel_color(:file_panel_close_hover_bg))
        fp.close_press(ba.id)
        assert fp.file_rows[ba.id][FileTreePanel::COL_CLOSE].include?(fp.panel_color(:file_panel_close_pressed_bg))
        assert_eq :normal, fp.close_state(bb.id)

        # release off the button: cancelled, nothing closes
        fp.close_release(nil)
        drain_idle
        assert fp.row_labels.key?(ba.id), "release elsewhere must not close"

        # press + release on the button closes it; current file stays
        assert_eq bb.id, vma.buf.id
        fp.close_press(ba.id)
        fp.close_release(ba.id)
        drain_idle
        assert vma.buffers.list.none? { |b| b.equal?(ba) }, "aaa.txt still open"
        assert_eq nil, fp.row_labels[ba.id]
        assert_eq bb.id, vma.buf.id
        fp.set_close_hover(nil)
      end
    end
  end
end
