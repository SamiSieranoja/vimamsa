require "language_server-protocol"
LSP = LanguageServer::Protocol

class LangSrv
  def new_id()
    return @id += 1
  end

  def initialize(lang)
    # @io = IO.popen("clangd-12 --log=verbose --offset-encoding=utf-8", "r+")
    @lang = lang
    if lang == "cpp"
      @io = IO.popen("clangd-12 --offset-encoding=utf-8", "r+")
    elsif lang == "ruby"
      @io = IO.popen("solargraph stdio", "r+")
    end
    @writer = LSP::Transport::Io::Writer.new(@io)
    @reader = LSP::Transport::Io::Reader.new(@io)
    @id = 0

    wf = []
    for c in conf(:workspace_folders)
      wf << LSP::Interface::WorkspaceFolder.new(uri: c[:uri], name: c[:name])
    end

    pid = Process.pid
    initp = LSP::Interface::InitializeParams.new(
      process_id: pid,
      root_uri: "null",
      workspace_folders: wf,
      capabilities: { 'workspace': { 'workspaceFolders': true } },
    )
    @resp = {}

    @writer.write(id: new_id, params: initp, method: "initialize")

    @lst = Thread.new {
      @reader.read do |r|
        @resp[r[:id]] = r
        pp r
        # exit
      end
    }

  end

  def add_workspaces() # TODO
    # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#workspace_workspaceFolders
    debug "Add workspaces", 2
    a = [LSP::Interface::WorkspaceFolder.new(uri: "file:///...", name: "vimamsa")]
    id = new_id
    # @writer.write(id: id, params: a, method: "textDocument/definition")
    # @writer.write(id: id, params: a, method: "workspace/workspaceFolders")
    @writer.write(id: id, params: a, method: "workspace/didChangeWorkspaceFolders")
    r = wait_for_response(id)
    pp r
  end

  def handle_responses()
    #TODO
    # r = @resp.delete_at(0)
  end

  def wait_for_response(id)
    debug "Waiting for response id:#{id}"
    while @resp[id].nil?
      sleep 0.03
    end
    return @resp[id]
  end

  def get_definition(fpuri, lpos, cpos)
    a = LSP::Interface::DefinitionParams.new(
      position: LSP::Interface::Position.new(line: lpos, character: cpos),
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    @writer.write(id: id, params: a, method: "textDocument/definition")
    r = wait_for_response(id)
    # Ripl.start :binding => binding
    pp r
    line = HSafe.new(r)[:result][0][:range][:start][:line].val
    uri = HSafe.new(r)[:result][0][:uri].val

    if !uri.nil? and !line.nil?
      puts "LINE:" + line.to_s
      puts "URI:" + uri
      fpath = URI.parse(uri).path
      line = line + 1
      return [fpath, line]
    end

    return nil
  end

  def open_file(fp, fc = nil)
    debug "open_file", 2
    fc = IO.read(fp) if fc.nil?
    fpuri = URI.join("file:///", fp).to_s

    a = LSP::Interface::DidOpenTextDocumentParams.new(
      text_document: LSP::Interface::TextDocumentItem.new(
        uri: fpuri,
        text: fc,
        language_id: "c++",
        version: 1,
      ),
    )

    @writer.write(method: "textDocument/didOpen", params: a)
  end
end

class ClangLangsrv
  def new_id()
    return @id += 1
  end

  def initialize()
    # @io = IO.popen("clangd-12 --log=verbose --offset-encoding=utf-8", "r+")
    @io = IO.popen("clangd-12 --offset-encoding=utf-8", "r+")
    @writer = LSP::Transport::Io::Writer.new(@io)
    @reader = LSP::Transport::Io::Reader.new(@io)
    @id = 0

    pid = Process.pid
    initp = LSP::Interface::InitializeParams.new(
      process_id: pid,
      root_uri: "null",
      capabilities: {},
    )
    @resp = {}

    @writer.write(id: new_id, params: initp, method: "initialize")

    @lst = Thread.new {
      @reader.read do |r|
        @resp[r[:id]] = r
        pp r
        # exit
      end
    }

  end

  def handle_responses()
    #TODO
    # r = @resp.delete_at(0)
  end

  def wait_for_response(id)
    debug "Waiting for response id:#{id}"
    while @resp[id].nil?
      sleep 0.03
    end
    return @resp[id]
  end

  def get_definition(fpuri, lpos, cpos)
    a = LSP::Interface::DefinitionParams.new(
      position: LSP::Interface::Position.new(line: lpos, character: cpos),
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    @writer.write(id: id, params: a, method: "textDocument/definition")
    r = wait_for_response(id)
    # Ripl.start :binding => binding
    pp r
    line = HSafe.new(r)[:result][0][:range][:start][:line].val
    uri = HSafe.new(r)[:result][0][:uri].val

    if !uri.nil? and !line.nil?
      puts "LINE:" + line.to_s
      puts "URI:" + uri
      fpath = URI.parse(uri).path
      line = line + 1
      return [fpath, line]
    end

    return nil
  end

  def open_file(fp, fc = nil)
    fc = IO.read(fp) if fc.nil?
    fpuri = URI.join("file:///", fp).to_s

    a = LSP::Interface::DidOpenTextDocumentParams.new(
      text_document: LSP::Interface::TextDocumentItem.new(
        uri: fpuri,
        text: fc,
        language_id: "c++",
        version: 1,
      ),
    )

    @writer.write(method: "textDocument/didOpen", params: a)
  end
end
