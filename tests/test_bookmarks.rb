require "tempfile"

# Persistent bookmarks (lib/vimamsa/bookmarks.rb): , M to add, , ' to list.
class TestBookmarks < VmaTest
  SAMPLE = (1..10).collect { |i| "line #{i}\n" }.join # "line 1" .. "line 10"

  def make_file(contents)
    f = Tempfile.new(["bookmark_target", ".txt"])
    f.write(contents)
    f.flush
    f
  end

  def cleanup(f)
    path = File.expand_path(f.path)
    vma.bookmarks.list.select { |bm| bm[:fname] == path }.each { |bm| vma.bookmarks.delete(bm) }
    close_file(path)
    f.close
    f.unlink
  end

  def close_file(path)
    id = vma.buffers.get_buffer_by_filename(path)
    vma.buffers.close_buffer(id) if id
    drain_idle
  end

  # lpos is 0-based
  def add_at(path, lpos)
    jump_to_file(path, lpos + 1)
    assert_eq lpos, vma.buf.lpos
    act(:bookmark_add)
    bm = vma.bookmarks.list.find { |b| b[:fname] == path && b[:lpos] == lpos }
    assert bm, "bookmark was not added at line #{lpos}"
    bm
  end

  def test_add_and_jump
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    bm = add_at(path, 4)
    assert_eq "line 5", bm[:text]
    assert_eq "line 4", bm[:before]
    assert_eq "line 6", bm[:after]

    create_new_buffer("\n", "other", true)
    assert vma.bookmarks.jump(bm), "jump failed"
    assert_eq path, vma.buf.fname
    assert_eq 4, vma.buf.lpos
  ensure
    cleanup(f)
  end

  def test_keys_add_bookmark
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    jump_to_file(path, 3)
    keys(", M")
    bm = vma.bookmarks.list.find { |b| b[:fname] == path }
    assert bm, ", M did not add a bookmark"
    assert_eq 2, bm[:lpos]
  ensure
    cleanup(f)
  end

  def test_same_line_replaces
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    add_at(path, 4)
    add_at(path, 4)
    assert_eq 1, vma.bookmarks.list.count { |b| b[:fname] == path }
  ensure
    cleanup(f)
  end

  # File changed outside the editor: the line moved, found again by its text
  def test_regexp_recovery_after_external_change
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    bm = add_at(path, 4)
    close_file(path)
    File.write(path, "new a\nnew b\nnew c\n" + SAMPLE)

    assert vma.bookmarks.jump(bm), "jump failed"
    assert_eq 7, vma.buf.lpos
    assert_eq 7, bm[:lpos], "stored line should be updated after jump"
  ensure
    cleanup(f)
  end

  def test_whitespace_changes_still_match
    f = make_file("a\nfoo(x,  y)\nb\n")
    path = File.expand_path(f.path)
    bm = add_at(path, 1)
    close_file(path)
    File.write(path, "z\nz\na\n    foo(x, y)\nb\n")

    vma.bookmarks.jump(bm)
    assert_eq 3, vma.buf.lpos
  ensure
    cleanup(f)
  end

  # Two identical lines: the one with matching context wins even when the
  # other one is at the stored line number.
  def test_duplicate_lines_use_context
    f = make_file("def a\n  x = 1\nend\ndef b\n  y = 2\nend\n")
    path = File.expand_path(f.path)
    bm = add_at(path, 5) # "end" after "y = 2"
    close_file(path)
    File.write(path, "def b\n  y = 2\nend\ndef a\n  x = 1\nend\n")

    vma.bookmarks.jump(bm)
    assert_eq 2, vma.buf.lpos
  ensure
    cleanup(f)
  end

  def test_text_deleted_falls_back_to_line_number
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    bm = add_at(path, 8)
    close_file(path)
    File.write(path, "a\nb\nc\n")

    assert vma.bookmarks.jump(bm), "jump failed"
    assert_eq 2, vma.buf.lpos # clamped to last line
    assert_eq "line 9", bm[:text], "stored text must not be overwritten"
  ensure
    cleanup(f)
  end

  def test_persisted_to_disk
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    bm = add_at(path, 2)
    stored = vma.marshal_load("bookmarks", [])
    assert stored.any? { |b| b[:fname] == path && b[:text] == "line 3" }, "bookmark not saved to disk"

    vma.bookmarks.delete(bm)
    stored = vma.marshal_load("bookmarks", [])
    assert !stored.any? { |b| b[:fname] == path }, "deleted bookmark still on disk"
  ensure
    cleanup(f)
  end

  # Edits in an open buffer move the bookmark; saving stores the new line.
  def test_tracked_while_open_and_saved
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    bm = add_at(path, 4)
    vma.buf.set_pos(0)
    act('buf.insert_txt("new1\nnew2\n")')
    vma.buf.save
    drain_idle

    assert_eq 6, bm[:lpos]
    assert_eq "line 5", bm[:text]
    assert_eq "line 4", bm[:before]
    assert File.read(path).start_with?("new1\nnew2\n"), "file was not saved"
  ensure
    cleanup(f)
  end

  def test_list_newest_first_and_select
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    b1 = add_at(path, 0)
    b3 = add_at(path, 2)
    b5 = add_at(path, 4)
    b1[:created] = Time.now - 300
    b3[:created] = Time.now - 200
    b5[:created] = Time.now - 100

    act(:bookmark_list)
    assert_mode :bmark
    list_id = vma.buf.id
    rows = vma.buf.to_s.lines.select { |l| l.include?(tilde_path(path)) }.collect(&:strip)
    assert_eq ["line 5", "line 3", "line 1"], rows.collect { |r| r.split("  ").last }

    act(:bmark_select) # cursor starts on the first (newest) row
    assert_eq path, vma.buf.fname
    assert_eq 4, vma.buf.lpos
    assert vma.buffers.get_buffer_by_id(list_id).nil?, "list buffer should be closed"
    assert_mode vma.kbd.default_mode
  ensure
    cleanup(f)
  end

  def test_list_delete
    f = make_file(SAMPLE)
    path = File.expand_path(f.path)
    add_at(path, 1)
    bm = add_at(path, 6) # newest -> first row

    act(:bookmark_list)
    act(:bmark_delete)
    assert !vma.bookmarks.list.include?(bm), "bookmark not deleted"
    assert_eq 1, vma.bookmarks.list.count { |b| b[:fname] == path }
    rows = vma.buf.to_s.lines.select { |l| l.include?(tilde_path(path)) }
    assert_eq 1, rows.size
    act(:close_current_buffer)
  ensure
    cleanup(f)
  end
end
