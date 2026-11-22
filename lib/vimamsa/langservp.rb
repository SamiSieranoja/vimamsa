require "language_server-protocol"

module Vimamsa
LSP = LanguageServer::Protocol

class LangSrv
  @@languages = {}
  # Languages whose server failed to start: not retried for every buffer (each
  # try blocks the GTK thread, so a session of N files stalled N times) until
  # LangSrv.restart
  @@failed = {}
  attr_accessor :error
  attr_reader :completion_supported, :position_encoding

  # LSP CompletionItemKind (1..25) => short tag for the popup
  COMPLETION_KINDS = {
    1 => "txt", 2 => "mthd", 3 => "fn", 4 => "ctor", 5 => "fld",
    6 => "var", 7 => "cls", 8 => "ifc", 9 => "mod", 10 => "prop",
    11 => "unit", 12 => "val", 13 => "enum", 14 => "kw", 15 => "snip",
    16 => "col", 17 => "file", 18 => "ref", 19 => "dir", 20 => "emem",
    21 => "cons", 22 => "strt", 23 => "evt", 24 => "op", 25 => "tprm",
  }.freeze

  # GtkSourceView language ids for header files => the language their LSP
  # server is configured for, so headers share the server of their sources.
  LSP_LANG = { "chdr" => "c", "cpphdr" => "cpp" }.freeze

  # Stop the server for lang (if running), start a new one and reattach every
  # open buffer of that language (also ones whose server failed to start).
  # Picks up configuration changes the server only reads at startup / file
  # open, e.g. a new compile_flags.txt for clangd. Returns the new server or nil.
  def self.restart(lang)
    lang = LSP_LANG.fetch(lang, lang)
    @@languages.delete(lang)&.shutdown
    @@failed.delete(lang)
    vma.buffers.list.each do |b|
      next if b.fname.nil? || b.lang.nil?
      next unless LSP_LANG.fetch(b.lang, b.lang) == lang
      b.init_lsp
    end
    @@languages[lang]
  end

  # The server for lang, started if needed. fname: the file it is wanted
  # for; a new server runs in that file's project (project_root).
  def self.get(lang, fname = nil)
    lang = LSP_LANG.fetch(lang, lang)
    if @@languages[lang].nil? && !@@failed[lang]
      srv = LangSrv.new(lang, root: project_root(fname))
      if srv.error
        # Only a configured server that did not start counts as failed
        @@failed[lang] = true if srv.configured?
      else
        @@languages[lang] = srv
      end
    end
    return @@languages[lang]
  end

  # Files and dirs that mark a project's top folder
  PROJECT_MARKERS = %w[.git Gemfile compile_commands.json compile_flags.txt]

  # The folder a server for fname works in (its working directory and
  # rootUri): the nearest folder up from fname with a PROJECT_MARKERS entry,
  # else fname's own folder. Never the home directory or /: ruby-lsp indexes
  # its whole workspace, so a file directly in ~ gets an empty folder.
  def self.project_root(fname)
    return nil if fname.nil?
    home = File.expand_path("~")
    dir = File.dirname(File.expand_path(fname))
    d = dir
    until d == home || d == "/" || d == "."
      return d if PROJECT_MARKERS.any? { |m| File.exist?(File.join(d, m)) }
      d = File.dirname(d)
    end
    return dir if dir != home && dir != "/"
    @@empty_root ||= Dir.mktmpdir("vimamsa-lsp-")
  end

  # A server is configured for this language (whether or not it started)
  def configured?
    @configured
  end

  def new_id()
    return @id += 1
  end

  # root: the project folder to run the server in (project_root)
  def initialize(lang, root: nil)
    @error = true
    @root = root

    # Use LSP server specified by user if available
    @lang = lang

    lspconf = nil
    ret = (cnf.lsp.server? || {}).find { |k, v| v[:languages].include?(@lang) }
    lspconf = ret[1] unless ret.nil?
    @configured = !lspconf.nil?

    if !lspconf.nil?
      error = false
      begin
        @io = @root ? IO.popen(lspconf[:command], "r+", chdir: @root) : IO.popen(lspconf[:command], "r+")
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
    @name = lspconf[:name] || @lang
    # file path => latest diagnostics the server published for it
    @diagnostics = {}
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

    # The project folder, unless workspace folders are configured
    if wf.empty? && @root
      wf << LSP::Interface::WorkspaceFolder.new(uri: file_uri(@root), name: File.basename(@root))
    end
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

    @server_gone = false
    @lst = Thread.new {
      begin
      @reader.read do |r|
        if r[:method] == "textDocument/publishDiagnostics"
          path = uri_to_path(r.dig(:params, :uri)) rescue nil
          @diagnostics[path] = r.dig(:params, :diagnostics) || [] if path
          next
        end
        @resp[r[:id]] = r
        cb = @pending_mutex.synchronize { @pending.delete(r[:id]) }
        # GTK is single-threaded; callbacks must run on the main loop
        GLib::Idle.add { cb.call(r); false } if cb
        pp r
      end
      rescue StandardError => e
        debug "LSP reader stopped: #{e}"
      ensure
        # EOF or unreadable output: the server is gone, stop waiting for it
        @server_gone = true
      end
    }

    # LSP spec: wait for initialize result, then send initialized notification.
    # Servers such as ruby-lsp will not respond to any request until this is done.
    init_result = wait_for_response(init_id)
    if init_result.nil?
      message("LSP server #{lspconf[:name]} did not start (command: #{lspconf[:command]})")
      shutdown
      @error = true
      return
    end
    caps = init_result.dig(:result, :capabilities) || {}
    # Units of Position.character: the server's choice (LSP 3.17
    # positionEncoding, or clangd's older offsetEncoding), else the LSP default.
    @position_encoding = caps[:positionEncoding] || init_result.dig(:result, :offsetEncoding) || "utf-16"
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

    # Called before the buffer is changed, so line_text sees the old text the
    # positions refer to.
    sc = lsp_character(fpath, delta[4][0], delta[4][1])
    changes = nil
    if delta[1] == INSERT
      changes = [{ 'rangeLength': 0, 'range': { 'start': { 'line': delta[4][0], 'character': sc }, 'end': { 'line': delta[4][0], 'character': sc } }, 'text': delta[3] }]
    elsif delta[1] == DELETE
      ec = lsp_character(fpath, delta[5][0], delta[5][1])
      changes = [{ 'rangeLength': delta[2], 'range': { 'start': { 'line': delta[4][0], 'character': sc }, 'end': { 'line': delta[5][0], 'character': ec } }, 'text': "" }]
    end
    debug changes.inspect, 2

    if !changes.nil?
      a = LSP::Interface::DidChangeTextDocumentParams.new(
        text_document: LSP::Interface::VersionedTextDocumentIdentifier.new(uri: fpuri, version: version),
        content_changes: changes,
      )
      pp a
      # A notification: no id. With an id it is a request, which clangd
      # rejects (-32601 method not found) without applying the change, so
      # its copy of the file goes stale and positions point at the wrong text.
      @writer.write(params: a, method: "textDocument/didChange")
    end
  end

  # Process id of the server (tests / introspection).
  def pid
    @io&.pid
  end

  # LSP shutdown request + exit notification. The process is reaped in the
  # background, and killed if it has not exited within 2 s.
  def shutdown
    id = new_id
    begin
      @writer.write(id: id, method: "shutdown", params: nil)
      wait_for_response(id, 2)
      @writer.write(method: "exit", params: nil)
    rescue IOError, SystemCallError => e
      debug "LSP shutdown: #{e}"
    end
    @lst&.kill
    io = @io
    @io = nil
    Thread.new do
      pid = io.pid
      20.times do
        break if Process.waitpid(pid, Process::WNOHANG)
        sleep 0.1
      end
      Process.kill("TERM", pid) rescue nil
      Process.waitpid(pid) rescue nil
      io.close rescue nil
    end
  end

  def wait_for_response(id, timeout = 5)
    t = Time.now
    debug "Waiting for response id:#{id}"
    while @resp[id].nil?
      return @resp[id] if @server_gone # a last reply may have come with EOF
      sleep 0.03
      if Time.now - t > timeout
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
      position: LSP::Interface::Position.new(line: lpos, character: lsp_character(fpuri, lpos, cpos)),
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: fpuri),
    )
    id = new_id
    pp a
    @writer.write(id: id, params: a, method: "textDocument/definition")
    r = wait_for_response(id)
    @definition_timed_out = r.nil?
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

    fpath = uri_to_path(uri)
    return [fpath, line + 1]
  end

  def uri_to_path(uri)
    URI::DEFAULT_PARSER.unescape(URI.parse(uri).path)
  end

  # Errors the server reported for file fpath (LSP severity 1), sorted by line
  def errors_for(fpath)
    (@diagnostics[fpath] || []).select { |d| (d[:severity] || 1) == 1 }
      .sort_by { |d| d.dig(:range, :start, :line).to_i }
  end

  # Why get_definition(fpath, ...) just came back empty, for the user: no
  # answer at all, or the server's own errors for the file, which often name
  # the real cause (e.g. "'foo.h' file not found": wrong include paths in
  # compile_commands.json / compile_flags.txt). nil if there is nothing to add.
  def definition_failure_hint(fpath)
    return "no answer from #{@name} within 5 s" if @definition_timed_out
    errs = errors_for(fpath)
    return nil if errs.empty?
    # A missing include usually causes the rest, so show that one first
    e = errs.find { |d| d[:message].to_s =~ /file not found/i } || errs[0]
    n = errs.size
    "#{@name} reports #{n} error#{n == 1 ? "" : "s"} in #{File.basename(fpath)}, e.g. " \
      "line #{e.dig(:range, :start, :line).to_i + 1}: #{e[:message].to_s.lines.first.to_s.strip}"
  end

  # Async textDocument/completion. Never blocks: the callback is invoked on
  # the GTK main loop with parsed items ([{text:, label:, kind:, detail:,
  # source: :lsp}, ...]) when the server responds. If no response arrives
  # within 3 s the request is silently dropped.
  def request_completion(fpath, lpos, cpos, &callback)
    ensure_file_open(fpath)
    fpuri = file_uri(fpath)
    a = LSP::Interface::CompletionParams.new(
      position: LSP::Interface::Position.new(line: lpos, character: lsp_character(fpath, lpos, cpos)),
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

  # Send textDocument/documentSymbol for fpath and return the raw symbols array
  # (either DocumentSymbol or SymbolInformation shape), or nil on error /
  # malformed response.
  private def request_document_symbols(fpath)
    ensure_file_open(fpath)
    a = LSP::Interface::DocumentSymbolParams.new(
      text_document: LSP::Interface::TextDocumentIdentifier.new(uri: file_uri(fpath)),
    )
    id = new_id
    @writer.write(id: id, params: a, method: "textDocument/documentSymbol")
    r = wait_for_response(id)
    return nil if r.nil?
    symbols = r[:result]
    return nil unless symbols.is_a?(Array)
    symbols
  end

  # Send textDocument/documentSymbol and return [{name:, line:}, ...] for functions/methods.
  # Returns nil on error, empty array if no functions found.
  def document_functions(fpath)
    symbols = request_document_symbols(fpath)
    return nil if symbols.nil?

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
    symbols = request_document_symbols(fpath)
    return nil if symbols.nil?

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

  # Ruby character column cpos on line lpos -> Position.character in the
  # server's encoding. They differ when non-ASCII text precedes the column:
  # "ä" is 1 char but 2 bytes in utf-8; "😀" is 1 char but 2 utf-16 units.
  def lsp_character(fpath_or_uri, lpos, cpos)
    return cpos if @position_encoding == "utf-32"
    pre = line_text(fpath_or_uri, lpos)[0, cpos].to_s.scrub
    return cpos if pre.ascii_only?
    if @position_encoding == "utf-8"
      pre.bytesize
    else
      pre.encode("UTF-16LE").bytesize / 2
    end
  end

  # Text of line lpos: from the editor buffer if the file is open (that is
  # what the server has, via didChange), else from disk.
  def line_text(fpath_or_uri, lpos)
    fpath = fpath_or_uri
    fpath = URI::DEFAULT_PARSER.unescape(URI.parse(fpath).path) if fpath.start_with?("file://")
    id = vma.buffers.get_buffer_by_filename(fpath)
    return vma.buffers.get_buffer_by_id(id).line(lpos).to_s if id
    if File.file?(fpath)
      File.foreach(fpath).with_index { |l, i| return l if i == lpos }
    end
    ""
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

def lsp_restart
  lang = vma.buf&.lang
  if !cnf.lsp.enabled?
    message("LSP is not enabled (Settings > Behavior)")
  elsif lang.nil?
    message("No language detected for this buffer")
  elsif LangSrv.restart(lang)
    message("Restarted LSP server for #{lang}")
  else
    message("No LSP server configured or started for #{lang}")
  end
end

def lsp_print_functions
  return unless vma.buf&.fname
  lsp = LangSrv.get(vma.buf.lang, vma.buf.fname)
  if lsp.nil?
    message("No LSP server available for #{vma.buf.lang}")
    return
  end
  lsp.print_functions(vma.buf.fname)
end
end # module Vimamsa
