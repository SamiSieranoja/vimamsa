require "tmpdir"

# LangSrv.project_root: the folder an LSP server runs in (its working
# directory and rootUri). ruby-lsp indexes its whole workspace, and used to
# get the editor's current directory, often the home directory.
class TestLspRoot < VmaTest
  REPO = File.expand_path("..", __dir__)

  def setup_lsp
    require "vimamsa/langservp"
  end

  def test_nearest_project_marker
    setup_lsp
    assert_eq REPO, LangSrv.project_root(File.join(REPO, "lib/vimamsa/editor.rb"))
    Dir.mktmpdir { |d|
      FileUtils.mkdir_p("#{d}/proj/src/deep")
      File.write("#{d}/proj/Gemfile", "")
      assert_eq "#{d}/proj", LangSrv.project_root("#{d}/proj/src/deep/x.rb")
    }
  end

  # No marker up to the home directory (or /): the file's own folder
  def test_without_marker_the_files_folder
    setup_lsp
    Dir.mktmpdir { |d|
      FileUtils.mkdir_p("#{d}/a/b")
      root = LangSrv.project_root("#{d}/a/b/x.rb")
      assert_eq "#{d}/a/b", root
    }
  end

  # Never the home directory: a file directly in ~ gets an empty folder
  def test_never_home
    setup_lsp
    home = File.expand_path("~")
    r = LangSrv.project_root(File.join(home, "notes.rb"))
    assert r != home, "home directory as the project root"
    assert File.directory?(r)
    assert_eq [], Dir.children(r)
    assert_eq nil, LangSrv.project_root(nil)
  end
end
