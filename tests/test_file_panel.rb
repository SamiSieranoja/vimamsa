require "tmpdir"

# alt-h / alt-l switch to the previous/next file in the file panel's display
# order (dirs sorted by name, files sorted within each dir) while the panel is
# open, and do nothing while it is hidden. See FileTreePanel#select_adjacent.
class TestFilePanel < VmaTest

  # Two files in one fresh temp dir: adjacent names in the same dir group are
  # guaranteed adjacent in the flattened panel order, whatever other buffers
  # exist from earlier tests.
  def with_two_files
    Dir.mktmpdir do |dir|
      fa = File.join(dir, "aaa.txt")
      fb = File.join(dir, "bbb.txt")
      File.write(fa, "a\n")
      File.write(fb, "b\n")
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

  # ` s labels the panel's file rows; typing a label switches to that file.
  # Labels follow panel order: first file row gets "A", second "S", ...
  def test_easy_jump_picks_file_by_label
    with_two_files do |ba, bb|
      with_panel_open do
        assert_eq bb.id, vma.buf.id
        keys("` s")
        assert vma.gui.file_panel.easy_jump_active?, "picker should be active after ` s"
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

  def test_easy_jump_esc_cancels
    with_two_files do |ba, bb|
      with_panel_open do
        before = vma.buf.id
        keys("` s")
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
      keys("` s")
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
end
