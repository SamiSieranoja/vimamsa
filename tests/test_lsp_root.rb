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

  # A server that can't start in one project (e.g. `bundle exec ruby-lsp`
  # where there is no Gemfile) is not retried there, but the language still
  # gets a server in other projects.
  def test_failed_server_is_per_project
    setup_lsp
    Dir.mktmpdir { |d|
      log = "#{d}/started"
      %w[a b].each { |p| FileUtils.mkdir_p("#{d}/#{p}"); File.write("#{d}/#{p}/Gemfile", "") }
      cnf.lsp.server.vma_test_fake = { name: "fake", type: "stdio",
                                       command: "sh -c 'pwd >> #{log}; exit 1'" }
      cnf.lsp.server.vma_test_fake.languages = ["vma_test_lang"]
      failed = LangSrv.class_variable_get(:@@failed)
      wait_failed = proc { |p|
        t = Time.now
        drain_idle until failed[["vma_test_lang", "#{d}/#{p}"]] || Time.now - t > 10
      }
      assert_eq nil, LangSrv.get("vma_test_lang", "#{d}/a/x.rb")
      wait_failed.call("a")
      assert_eq nil, LangSrv.get("vma_test_lang", "#{d}/a/y.rb")   # not retried in a
      assert_eq nil, LangSrv.get("vma_test_lang", "#{d}/b/x.rb")   # but tried in b
      wait_failed.call("b")
      started = File.readlines(log, chomp: true).map { |l| File.realpath(l) }
      assert_eq ["#{d}/a", "#{d}/b"].map { |x| File.realpath(x) }, started
    }
  ensure
    LangSrv.forget("vma_test_lang")
  end

  # Opening a file doesn't wait for its language server to start (a session
  # restore opens many): the buffer attaches once the server answers.
  def test_open_does_not_wait_for_server
    setup_lsp
    Dir.mktmpdir do |d|
      File.write("#{d}/Gemfile", "")
      File.write("#{d}/x.vmatest", "hello\n")
      # Never answers initialize: the start would block for the 5 s timeout
      cnf.lsp.server.vma_test_slow = { name: "slow", type: "stdio", command: "sleep 30" }
      cnf.lsp.server.vma_test_slow.languages = ["vma_test_slow"]
      b = create_new_buffer("hello\n", "x")
      b.instance_variable_set(:@fname, "#{d}/x.vmatest")
      b.instance_variable_set(:@lang, "vma_test_slow")
      prev = cnf.lsp.enabled?
      cnf.lsp.enabled = true
      t = Time.now
      b.init_lsp
      assert Time.now - t < 1, "init_lsp waited #{(Time.now - t).round(1)} s for the server"
      assert_eq nil, b.lsp
      srv = LangSrv.class_variable_get(:@@languages)[["vma_test_slow", d]]
      assert srv&.starting?, "server not starting in the background"
    ensure
      cnf.lsp.enabled = prev
      srv&.shutdown
      LangSrv.forget("vma_test_slow")
    end
  end

  # A minimal LSP server: answers initialize, and null to other requests
  FAKE_SERVER = <<~'RUBY'
    require "json"
    $stdout.sync = true
    reply = ->(id, result) {
      b = JSON.generate(jsonrpc: "2.0", id: id, result: result)
      $stdout.write("Content-Length: #{b.bytesize}\r\n\r\n#{b}")
    }
    while (h = $stdin.gets("\r\n\r\n"))
      m = JSON.parse($stdin.read(h[/Content-Length: (\d+)/, 1].to_i))
      if m["method"] == "initialize"
        reply.(m["id"], { capabilities: { definitionProvider: true } })
      elsif m["id"]
        reply.(m["id"], nil)
      end
    end
  RUBY

  # Bug: with the project's server already running, a newly opened file was
  # attached from inside Buffer#initialize, before the buffer was listed, and
  # the "still open?" check dropped it: only the first file of a project got
  # LSP.
  def test_second_file_of_project_attaches
    setup_lsp
    prev = cnf.lsp.enabled?
    Dir.mktmpdir do |d|
      File.write("#{d}/Gemfile", "")
      File.write("#{d}/server.rb", FAKE_SERVER)
      %w[a b].each { |n| File.write("#{d}/#{n}.lua", "print(1)\n") }
      cnf.lsp.server.vma_test_fake_ok = { name: "fake-ok", type: "stdio", command: "#{RbConfig.ruby} #{d}/server.rb" }
      cnf.lsp.server.vma_test_fake_ok.languages = ["lua"]
      cnf.lsp.enabled = true
      ba = open_new_file("#{d}/a.lua")
      assert_eq "lua", ba.lang
      assert wait_for_lsp(ba, 10), "first file of the project got no LSP"
      bb = open_new_file("#{d}/b.lua")
      drain_idle
      assert bb.lsp.equal?(ba.lsp), "second file of the project got no LSP"
    ensure
      cnf.lsp.enabled = prev
      ba&.lsp&.shutdown
      LangSrv.forget("lua")
    end
  end
end
