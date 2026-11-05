require "tmpdir"
require "fileutils"

# Buffers produced by the diff actions are named after what they diff, with
# "diff" in the name, instead of the generic "*buf-N*".
class TestDiffBufferName < VmaTest

  # Temp git repo with one committed file that is then modified on disk.
  def with_dirty_repo
    dir = Dir.mktmpdir("vma_diffname")
    repo = File.join(dir, "myrepo")
    Dir.mkdir(repo)
    path = File.join(repo, "notes.txt")
    File.write(path, "one\ntwo\n")
    system("git", "-C", repo, "init", "-q")
    system("git", "-C", repo, "add", "notes.txt")
    system("git", "-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
    File.write(path, "one\nTWO\n")
    yield repo, path
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_git_diff_buffer_name
    return skip("git not installed") unless system("which git >/dev/null 2>&1")
    with_dirty_repo do |repo, path|
      jump_to_file(path, 1)
      git_diff_buffer
      assert_eq "*gitdiff-notes.txt-#{vma.buf.id}*", vma.buf.list_str
    end
  end

  def test_git_diff_w_name
    return skip("git not installed") unless system("which git >/dev/null 2>&1")
    with_dirty_repo do |repo, path|
      jump_to_file(path, 1)
      git_diff_w
      assert_eq "*gitdiff-myrepo-#{vma.buf.id}*", vma.buf.list_str
    end
  end

  def test_unsaved_diff_name
    return skip("diff not installed") unless system("which diff >/dev/null 2>&1")
    with_dirty_repo do |repo, path|
      jump_to_file(path, 1)
      vma.buf.insert_txt("x")
      diff_buffer
      assert_eq "*diff-unsaved-notes.txt-#{vma.buf.id}*", vma.buf.list_str
    end
  end
end
