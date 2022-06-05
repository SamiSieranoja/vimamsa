require "language_server-protocol"
LSP = LanguageServer::Protocol

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
    @resp = []

    @writer.write(id: new_id, params: initp, method: "initialize")

    @lst = Thread.new {
      @reader.read do |r|
        @resp << r
        puts r
        # exit
      end
    }

    # TODO:
    # workspace_folders: [LSP::Interface::WorkspaceFolder.new(uri: root_uri, name: "vimamsa")],
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
    @writer.write(id: new_id, params: a, method: "textDocument/definition")
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
