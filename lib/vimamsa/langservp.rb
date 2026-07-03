require "language_server-protocol"

module Vimamsa
LSP = LanguageServer::Protocol

class LangSrv
  @@languages = {}
  attr_accessor :error
  attr_reader :completion_supported

  # LSP CompletionItemKind (1..25) => short tag for the popup
  COMPLETION_KINDS = {
    1 => "txt", 2 => "mthd", 3 => "fn", 4 => "ctor", 5 => "fld",
    6 => "var", 7 => "cls", 8 => "ifc", 9 => "mod", 10 => "prop",
    11 => "unit", 12 => "val", 13 => "enum", 14 => "kw", 15 => "snip",
    16 => "col", 17 => "file", 18 => "ref", 19 => "dir", 20 => "emem",
    21 => "cons", 22 => "strt", 23 => "evt", 24 => "op", 25 => "tprm",
  }.freeze

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

    # Use LSP server specified by user if available
    @lang = lang

    lspconf = nil
    ret = (cnf.lsp.server? || {}).find { |k, v| v[:languages].include?(@lang) }
    lspconf = ret[1] unless ret.nil?

    if !lspconf.nil?
      error = false
      begin
        @io = IO.popen(lspconf[:command], "r+")
      rescue Errno::ENOENT => e
        pp e
        error = true
      rescue StandardError => e
        debug "StandardError @io = IO.popen(lspconf[:command] ...", 2
        pp e
        error = true
      end
      if error or @io.nil?
        message("Could not start lsp server #{lspconf[:name]}")
        error = true
        return nil
      end
    else
      return nil
    end
    @writer = LSP::Transport::Io::Writer.new(@io)
    @reader = LSP::Transport::Io::Reader.new(@io)
    @id = 0

    wf = []
    for c in cnf.workspace_folders!
      wf << LSP::Interface::WorkspaceFolder.new(uri: c[:uri], name: c[:name])
    end
    debug "WORKSPACE FOLDERS", 2
    debug wf.inspect, 2

    pid = Process.pid

    root_uri = lspconf[:rooturi] || (wf.empty? ? nil : wf.first.uri)
    initp = LSP::Interface::InitializeParams.new(
      process_id: pid,
      root_uri: root_uri,
      workspace_folders: wf.empty? ? nil : wf,
      capabilities: {
        'workspace' => { 'workspaceFolders' => true },
        'textDocument' => {
          'definition' => { 'linkSupport' => true },
          'completion' => { 'completionItem' => { 'snippetSupport' => false } },
        },
      },
    )
    @resp = {}
    @pending = {} # id => callback, marshaled to the GTK thread on response
    @pending_mutex = Mutex.new
    init_id = new_id

    @writer.write(id: init_id, params: initp, method: "initialize")

    @lst = Thread.new {
      @reader.read do |r|
        @resp[r[:id]] = r
        cb = @pending_mutex.synchronize { @pending.delete(r[:id]) }
        # GTK is single-threaded; callbacks must run on the main loop
        GLib::Idle.add { cb.call(r); false } if cb
        pp r
      end
    }

    # LSP spec: wait for initialize result, then send initialized notification.
    # Servers such as ruby-lsp will not respond to any request until this is done.
    init_result = wait_for_response(init_id)
    if init_result.nil?
      @error = true
      return
    end
    caps = init_result.dig(:result, :capabilities) || {}
    @completion_supported = !!(caps[:completionProvider] || caps["completionProvider"])
    unless caps[:definitionProvider] || caps["definitionProvider"]
      message("Warning: LSP server #{lspconf[:name]} did not advertise definitionProvider — " \
              "jump to definition will not work. Try running with 'bundle exec'.")
    end
    @writer.write(method: "initialized", params: {})
    @error = false
  end

  def handle_delta(delta, fpath, version)
    fpuri = file_uri(fpath)

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

  def get_definition(fpath_or_uri, lpos, cpos)
    fpuri = fpath_or_uri.start_with?("file://") ? fpath_or_uri : file_uri(fpath_or_uri)
    a = LSP::Interface::DefinitionParams.new(
      position: LSP::Interface::Position.new(line: lpos, character: cpos),
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    pp a
    @writer.write(id: id, params: a, method: "textDocument/definition")
    r = wait_for_response(id)
    return nil if r.nil?
    pp r

    result = r[:result]
    return nil unless result

    # result may be: Location, Location[], or LocationLink[]
    items = result.is_a?(Array) ? result : [result]
    return nil if items.empty?

    item  = items[0]
    # Location uses :uri + :range; LocationLink uses :targetUri + :targetSelectionRange
    uri   = item[:uri] || item[:targetUri]
    range = item[:range] || item[:targetSelectionRange] || item[:targetRange]
    line  = range&.dig(:start, :line)

    return nil unless uri && line

    fpath = URI.parse(uri).path
    return [fpath, line + 1]
  end

  # Async textDocument/completion. Never blocks: the callback is invoked on
  # the GTK main loop with parsed items ([{text:, label:, kind:, detail:,
  # source: :lsp}, ...]) when the server responds. If no response arrives
  # within 3 s the request is silently dropped.
  # Note: line/character are sent as Ruby char offsets although LSP defaults
  # to UTF-16 code units — same pragmatic choice as didChange/definition
  # above; differs only when non-BMP chars precede the cursor on the line.
  def request_completion(fpath, lpos, cpos, &callback)
    ensure_file_open(fpath)
    fpuri = file_uri(fpath)
    a = LSP::Interface::CompletionParams.new(
      position: LSP::Interface::Position.new(line: lpos, character: cpos),
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    @pending_mutex.synchronize {
      @pending[id] = proc { |r| callback.call(parse_completion(r)) }
    }
    @writer.write(id: id, params: a, method: "textDocument/completion")
    GLib::Timeout.add(3000) do
      @pending_mutex.synchronize { @pending.delete(id) }
      false
    end
  end

  # Parse a completion response: CompletionItem[] or CompletionList.
  # We ignore textEdit ranges and always replace the current word
  # (Buffer#complete_current_word) — correct for word-like completions.
  def parse_completion(r)
    result = r[:result]
    return [] if result.nil?
    items = result.is_a?(Array) ? result : (result[:items] || [])
    return [] if !items.is_a?(Array)
    out = []
    items.first(500).each do |it|
      text = it.dig(:textEdit, :newText) || it[:insertText] || it[:label]
      next if text.nil? or text.empty?
      if it[:insertTextFormat] == 2
        # Snippet format: strip ${1:placeholder} and $1 tab stops
        text = text.gsub(/\$\{\d+:?([^}]*)\}/) { $1 }.gsub(/\$\d+/, "")
      end
      out << { text: text,
               label: it[:label],
               kind: COMPLETION_KINDS[it[:kind]],
               detail: it[:detail],
               sort: (it[:sortText] || it[:label] || text).to_s,
               source: :lsp }
    end
    out.sort_by! { |x| x[:sort] }
    return out.first(100)
  end

  # LSP SymbolKind values for callable things
  FUNCTION_KINDS = [6, 9, 12].freeze  # Function, Constructor, Method
  CLASS_KINDS    = [5, 10, 11, 23].freeze  # Class, Module, Interface, Namespace

  # Recursively collect symbols of function kinds.
  # Handles both flat SymbolInformation[] and nested DocumentSymbol[] (with :children).
  def collect_functions(symbols)
    result = []
    symbols.each do |s|
      result << s if FUNCTION_KINDS.include?(s[:kind])
      result.concat(collect_functions(s[:children])) if s[:children].is_a?(Array)
    end
    result
  end

  # Flatten all FUNCTION_KINDS from a symbol subtree into [{name:, line:}, ...].
  def flatten_functions(symbols)
    result = []
    symbols.each do |s|
      if FUNCTION_KINDS.include?(s[:kind])
        line = s.dig(:range, :start, :line)
        result << { name: s[:name], line: line ? line + 1 : 0 }
      end
      result.concat(flatten_functions(s[:children])) if s[:children].is_a?(Array)
    end
    result
  end

  # Build groups from a nested DocumentSymbol[].
  # Returns [{name:, line:, functions: [{name:, line:}, ...]}, ...]
  # name: nil = top-level (ungrouped) functions.
  def collect_groups_nested(symbols)
    groups = []
    top_funcs = []
    symbols.each do |s|
      if CLASS_KINDS.include?(s[:kind])
        line = s.dig(:range, :start, :line)
        funcs = s[:children].is_a?(Array) ? flatten_functions(s[:children]) : []
        groups << { name: s[:name], line: line ? line + 1 : 0, functions: funcs }
      elsif FUNCTION_KINDS.include?(s[:kind])
        line = s.dig(:range, :start, :line)
        top_funcs << { name: s[:name], line: line ? line + 1 : 0 }
      end
    end
    groups.unshift({ name: nil, line: nil, functions: top_funcs }) unless top_funcs.empty?
    groups
  end

  # Build groups from a flat SymbolInformation[] using :containerName.
  def collect_groups_flat(symbols)
  
    by_container = {}
    symbols.each do |s|
      next unless FUNCTION_KINDS.include?(s[:kind])
      container = s[:containerName] || ""
      line = s.dig(:location, :range, :start, :line)
      by_container[container] ||= []
      by_container[container] << { name: s[:name], line: line ? line + 1 : 0 }
    end
    groups = []
    top_funcs = by_container.delete("") || []
    by_container.keys.sort.each do |container|
      groups << { name: container, line: 0, functions: by_container[container] }
    end
    groups << { name: nil, line: nil, functions: top_funcs } unless top_funcs.empty?
    
    groups
  end

  # Send textDocument/documentSymbol and return [{name:, line:}, ...] for functions/methods.
  # Returns nil on error, empty array if no functions found.
  def document_functions(fpath)
    ensure_file_open(fpath)
    fpuri = file_uri(fpath)
    a = LSP::Interface::DocumentSymbolParams.new(
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    @writer.write(id: id, params: a, method: "textDocument/documentSymbol")
    r = wait_for_response(id)
    return nil if r.nil?

    symbols = r[:result]
    return nil if !symbols.is_a?(Array)

    functions = collect_functions(symbols)
    functions.map do |s|
      line = s.dig(:range, :start, :line) || s.dig(:location, :range, :start, :line)
      { name: s[:name], line: line ? line + 1 : 0 }
    end
  end

  # Like document_functions but returns functions grouped by class/module.
  # Returns [{name:, line:, functions: [{name:, line:}, ...]}, ...]
  # name: nil means top-level (ungrouped) functions.
  def document_functions_grouped(fpath)
    ensure_file_open(fpath)
    fpuri = file_uri(fpath)
    a = LSP::Interface::DocumentSymbolParams.new(
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    @writer.write(id: id, params: a, method: "textDocument/documentSymbol")
    r = wait_for_response(id)
    return nil if r.nil?

    symbols = r[:result]
    return nil unless symbols.is_a?(Array)

    # Detect nested (DocumentSymbol) vs flat (SymbolInformation) format
    if symbols.any? { |s| s.key?(:children) }
      collect_groups_nested(symbols)
    else
      collect_groups_flat(symbols)
    end
  end

  # Send textDocument/documentSymbol, filter to functions/methods, and puts them.
  def print_functions(fpath)
    funcs = document_functions(fpath)
    if funcs.nil? || funcs.empty?
      puts "(no functions found in #{File.basename(fpath)})"
      return
    end

    puts "=== Functions in #{File.basename(fpath)} ==="
    funcs.each do |f|
      line_str = f[:line] > 0 ? ":#{f[:line]}" : ""
      puts "  #{f[:name]}#{line_str}"
    end
  end

  def file_uri(fp)
    URI.join("file:///", fp).to_s
  end

  def open_file(fp, fc = nil, lang: nil)
    debug "open_file", 2
    @opened_files ||= {}
    fpuri = file_uri(fp)
    fc = IO.read(fp) if fc.nil?
    lang ||= @lang

    a = LSP::Interface::DidOpenTextDocumentParams.new(
      text_document: LSP::Interface::TextDocumentItem.new(
        uri: fpuri,
        text: fc,
        language_id: lang,
        version: 1,
      ),
    )

    @writer.write(method: "textDocument/didOpen", params: a)
    @opened_files[fpuri] = true
  end

  def ensure_file_open(fp, fc = nil)
    @opened_files ||= {}
    fpuri = file_uri(fp)
    open_file(fp, fc) unless @opened_files[fpuri]
  end
end

def lsp_print_functions
  return unless vma.buf&.fname
  lsp = LangSrv.get(vma.buf.lang)
  if lsp.nil?
    message("No LSP server available for #{vma.buf.lang}")
    return
  end
  lsp.print_functions(vma.buf.fname)
end
end # module Vimamsa
