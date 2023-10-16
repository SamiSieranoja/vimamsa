require "language_server-protocol"
LSP = LanguageServer::Protocol

class LangSrv
  @@languages = {}
  attr_accessor :error

  def self.get(lang)
    if @@languages[lang].nil?
      @@languages[lang] = LangSrv.new(lang)
      @@languages[lang] = nil if @@languages[lang].error
    end
    return @@languages[lang]
  end

  def new_id()
    return @id += 1
  end

  def initialize(lang)
    @error = true
    clsp = conf(:custom_lsp)

    # Use LSP server specified by user if available
    @lang = lang
    lspconf = clsp[lang]
    if !lspconf.nil?
      @io = IO.popen(lspconf[:command], "r+")
    else
      return nil
    end
    @writer = LSP::Transport::Io::Writer.new(@io)
    @reader = LSP::Transport::Io::Reader.new(@io)
    @id = 0

    wf = []
    for c in conf(:workspace_folders)
      wf << LSP::Interface::WorkspaceFolder.new(uri: c[:uri], name: c[:name])
    end

    pid = Process.pid

    if lspconf[:name] == "phpactor"
      initp = LSP::Interface::InitializeParams.new(
        process_id: pid,
        root_uri: lspconf[:rooturi],
        workspace_folders: wf,
        capabilities: { 'workspace': { 'workspaceFolders': true } },
      )
    else
      initp = LSP::Interface::InitializeParams.new(
        process_id: pid,
        root_uri: "null",
        workspace_folders: wf,
        capabilities: { 'workspace': { 'workspaceFolders': true } },
      )
    end
    @resp = {}

    @writer.write(id: new_id, params: initp, method: "initialize")

    @lst = Thread.new {
      @reader.read do |r|
        @resp[r[:id]] = r
        pp r
        # exit
      end
    }
    @error = false
  end

  def handle_delta(delta, fpath, version)
    fpuri = URI.join("file:///", fpath).to_s

    # delta[0]: char position
    # delta[1]: INSERT or DELETE
    # delta[2]: number of chars affected
    # delta[3]: text to add in case of insert

    changes = nil
    if delta[1] == INSERT
      changes = [{ 'rangeLength': 0, 'range': { 'start': { 'line': delta[4][0], 'character': delta[4][1] }, 'end': { 'line': delta[4][0], 'character': delta[4][1] } }, 'text': delta[3] }]
    elsif delta[1] == DELETE
      changes = [{ 'rangeLength': delta[2], 'range': { 'start': { 'line': delta[4][0], 'character': delta[4][1] }, 'end': { 'line': delta[5][0], 'character': delta[5][1] } }, 'text': "" }]
    end
    debug changes.inspect, 2

    if !changes.nil?
      a = LSP::Interface::DidChangeTextDocumentParams.new(
        text_document: LSP::Interface::VersionedTextDocumentIdentifier.new(uri: fpuri, version: version),
        content_changes: changes,

      )
      id = new_id
      pp a
      @writer.write(id: id, params: a, method: "textDocument/didChange")
    end
  end

  def wait_for_response(id)
    t = Time.now
    debug "Waiting for response id:#{id}"
    while @resp[id].nil?
      sleep 0.03
      if Time.now - t > 5
        debug "Timeout LSP call id:#{id}"
        return nil
      end
    end
    debug "End waiting id:#{id}"
    return @resp[id]
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

  def get_definition(fpuri, lpos, cpos)
    a = LSP::Interface::DefinitionParams.new(
      position: LSP::Interface::Position.new(line: lpos, character: cpos),
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    @writer.write(id: id, params: a, method: "textDocument/definition")
    r = wait_for_response(id)
    return nil if r.nil?
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
