require "digest"
require "tempfile"
require "fileutils"
require "pathname"
require "openssl"
require "ripl/multi_line"

module Vimamsa
$ifuncon = false


class Buffer < String
  attr_reader :pos, :lpos, :cpos, :deltas, :edit_history, :fname, :call_func, :pathname, :basename, :dirname, :update_highlight, :marks, :is_highlighted, :syntax_detect_failed, :id, :lang, :images, :last_save, :access_time, :selection_active, :lsp, :edit_version
  attr_writer :call_func, :update_highlight
  # help_page: the name of the help page shown (intro_page.rb), else nil.
  # read_only: edits are refused (help pages). help_buttons: [[action,
  # Gtk::Button]] of a help page's ⟦run:…⟧ links.
  attr_accessor :help_page, :read_only, :help_buttons
  attr_accessor :gui_update_highlight, :update_hl_startpos, :update_hl_endpos, :hl_queue, :syntax_parser, :highlights, :gui_reset_highlight, :is_parsing_syntax, :line_ends, :bt, :line_action_handler, :module, :active_kbd_mode, :title, :subtitle, :paste_lines, :mode_stack, :default_mode, :git_root, :needs_autosave_check

  @@num_buffers = 0

  def initialize(str = "\n", fname = nil, prefix = "buf")
    debug "Buffer.rb: def initialize"
    super(str)

    update_access_time
    @images = []
    @prefix = prefix
    @lang = nil
    @id = @@num_buffers
    @@num_buffers += 1
    @version = 0
    @default_mode = vma.kbd.default_mode
    @mode_stack = [@default_mode]
    gui_create_buffer(@id, self)
    debug "NEW BUFFER fn=#{fname} ID:#{@id}"

    # If true, we will create new line after this and paste there
    @paste_lines = false

    @module = nil

    @last_save = @last_asked_from_user = @file_last_cheked = Time.now
    @t_modified = @last_save
    @last_autosave = @last_save
    @autosave_thread = nil
    # Set when a buffer is loaded via session restore: its autosave file is not
    # checked at load time (that path bypasses check_autosave_load), so defer
    # the check until the user first switches to the buffer. See
    # check_session_restore and BufferList#set_current_buffer.
    @needs_autosave_check = false

    @crypt = nil
    @update_highlight = true
    @syntax_detect_failed = false
    @is_parsing_syntax = false
    @last_update = Time.now - 100
    @highlights = {}

    set_filename(fname)
    @hl_queue = []
    @line_action_handler = nil
    t1 = Time.now

    set_content(str)
    debug "init time:#{Time.now - t1}"

    # TODO: add \n when chars are added after last \n
    self << "\n" if self[-1] != "\n"
    @current_word = nil
    @active_kbd_mode = nil
    if cnf.lsp.enabled?
      init_lsp
    end
    start_autosave_timer
    return self
  end

  def list_str()
    if @fname.nil?
      x = @title
    else
      x = @fname
    end
    return x
  end

  #Check if this buffer is attached to any windows
  def is_active?
    for k in vma.gui.windows.keys
      next if vma.gui.windows[k][:sw].child.nil?
      return true if vma.gui.windows[k][:sw].child.bufo.equal?(self)
    end
    return false
  end

  def update_access_time
    @access_time = Time.now
  end

  # This function is to be called whenever keyboard events start affecting this buffer
  # e.g. switching between buffers, opening a new (this) file
  def set_active
    debug "def set_active", 2
    if vma.kbd.get_scope != :editor
      # If current keyboard mode is not an editor wide mode spanning multiple buffers(e.g. browsing)
      restore_kbd_mode
    end
  end

  # Restore the previous keyboard mode specific to this buffer
  def restore_kbd_mode
    vma.kbd.set_mode_stack(@mode_stack.clone)
  end

  def set_executable
    if File.exist?(@fname)
      FileUtils.chmod("+x", @fname)
      message("Set executable: #{@fname}")
    end
  end

  def lsp_get_def()
    if !@lsp.nil?
      fpuri = URI.join("file:///", @fname).to_s
      @lsp.get_definition(fpuri, @lpos, @cpos)
    end
  end

  def lsp_jump_to_def()
    message("LSP not activated") if @lsp.nil?
    if !@lsp.nil?
      fpuri = URI.join("file:///", @fname).to_s
      r = @lsp.get_definition(fpuri, @lpos, @cpos)
      if !r.nil?
        jump_to_file(r[0], r[1])
      else
        line = get_current_line
        w = line[0, @cpos + 1].to_s[/\w*\z/].to_s + line[@cpos + 1..].to_s[/\A\w*/].to_s
        w = "" unless line[@cpos].to_s =~ /\w/
        msg = w.empty? ? "No definition found" : "No definition found for `#{w}`"
        hint = @lsp.definition_failure_hint(@fname)
        message(hint ? "#{msg}: #{hint}" : msg)
      end
    end
  end

  # Attach this buffer to its language server, once the server is ready (it
  # starts in the background: opening files, e.g. a session restore, doesn't
  # wait for it). @lsp stays nil until then.
  def init_lsp()
    return unless cnf.lsp.enabled?
    # LangSrv is loaded lazily here: buffers (e.g. the minibuffer) can be
    # created during startup before editor.rb requires langservp, so require
    # it on demand. require is idempotent, so this is cheap after first load.
    require "vimamsa/langservp"
    @lsp = nil
    fname = @fname
    lang = @lang
    LangSrv.when_ready(@lang, @fname) do |srv|
      # Still the same file and language, and the buffer still open. (Not
      # "in the buffer list": with a server that is already ready this runs
      # right away, from Buffer#initialize, before the buffer is listed. A
      # closed buffer has no view.)
      next if @fname != fname || @lang != lang || @lsp.equal?(srv)
      next if view.nil?
      @lsp = srv
      srv.open_file(@fname, self.to_s)
    end
  end

  def detect_file_language
    @lang = nil
    @lang = "c" if @fname.match(/\.(c|h)$/)
    # GtkSourceView (below) refines these; .hxx/.ipp/.inl it does not know
    @lang = "cpp" if @fname.match(/\.(cpp|cc|cxx|hpp|hh|hxx|ipp|inl|tpp)$/)
    @lang = "java" if @fname.match(/\.(java)$/)
    @lang = "ruby" if @fname.match(/\.(rb)$/)
    @lang = "hyperplaintext" if @fname.match(/\.(txt)$/)
    @lang = "php" if @fname.match(/\.(php)$/)
    @lsp = nil

    lm = GtkSource::LanguageManager.new

    lm.set_search_path(lm.search_path << ppath("lang/"))
    # An empty name (a buffer that has no file yet) makes GtkSourceView print
    # a CRITICAL assertion
    lang = @fname.empty? ? nil : lm.guess_language(@fname)
    # lang.get_metadata("line-comment-start")
    # lang.get_metadata("block-comment-start")
    # lang.get_metadata("block-comment-end")
    @lang_nfo = lang
    if !lang.nil? and !lang.id.nil?
      debug "Guessed LANG: #{lang.id}"
      @lang = lang.id
    end
    # No extension to go by (e.g. a script named "build"): the #! line
    @lang ||= shebang_language
    debug @lang.inspect

    if @lang
      gui_set_file_lang(@id, @lang)
    end
    return @lang
  end

  # Interpreter in a "#!" line → GtkSourceView language id
  SHEBANG_LANGS = {
    /\Aruby/ => "ruby", /\Apython/ => "python3", /\A(ba|da|z|k|mk)?sh\z/ => "sh",
    /\Aperl/ => "perl", /\A(node|nodejs|deno|bun)\z/ => "js", /\Alua/ => "lua",
    /\Aphp/ => "php", /\Afish\z/ => "fish", /\A(tclsh|wish)/ => "tcl",
    /\A[gmn]?awk\z/ => "awk", /\ARscript\z/ => "r", /\Ajulia\z/ => "julia",
    /\Amake\z/ => "makefile",
  }

  # Language from the first line, e.g. "#!/usr/bin/env ruby" or
  # "#!/bin/bash -e". Reads the file when the buffer has no text yet
  # (detection runs before the content is set).
  def shebang_language
    first = self.empty? ? nil : self[0, 200]
    if first.nil? && @fname && File.file?(@fname) && File.readable?(@fname)
      first = File.open(@fname, "rb") { |f| f.read(200) }.to_s.force_encoding("UTF-8").scrub
    end
    line = first.to_s.lines.first.to_s
    return nil unless line.start_with?("#!")
    words = line[2..].strip.split
    cmd = File.basename(words.shift.to_s)
    if cmd == "env" # skip env's options and VAR=value: "env -S ruby -w"
      words.shift while words[0] && (words[0].start_with?("-") || words[0].include?("="))
      cmd = File.basename(words.shift.to_s)
    end
    SHEBANG_LANGS.each { |re, lang| return lang if cmd.match?(re) }
    nil
  rescue StandardError => e
    debug "shebang_language: #{e}"
    nil
  end

  def set_language(lang_id)
    @lang = lang_id
    gui_set_file_lang(@id, @lang)
  end

  def view()
    # Get the VSourceView < GtkSource::View object corresponding to this buffer
    return vma.gui.buffers[@id]
  end

  def scan_all_words
    words = self.scan(/\b\w+\b/).uniq
    return words
  end

  def cleanup_deleted_images(deleted_text)
    return if @images.empty?
    return unless deleted_text&.include?("⟦img:")
    deleted_text.scan(/⟦img:(.+?)⟧/) do |match|
      tag_path = match[0]
      abs_path = translate_path(tag_path, self)
      @images.delete_if do |img|
        next false unless img[:path] == abs_path || img[:path] == tag_path
        # img[:obj].destroy unless img[:obj].destroyed?
        # Schedule anchor character deletion after the current delta is done.
        # Using the anchor object lets us find the correct position even if
        # prior edits shifted it.
        anchor = img[:anchor]
        buf_ref = self
        run_as_idle proc {
          next if anchor.nil? || anchor.deleted?
          itr = buf_ref.view.buffer.get_iter_at_child_anchor(anchor)
          next if itr.nil?
          pos = itr.offset
          buf_ref.add_delta([pos, DELETE, 1], true)
          buf_ref.calculate_line_and_column_pos
        }
        true
      end
    end
  end

  def add_image(imgpath, pos)
    return if !is_legal_pos(pos)

    vbuf = view.buffer
    itr = vbuf.get_iter_at(:offset => pos)
    return if itr&.child_anchor  # anchor already exists here, image already rendered
    itr2 = vbuf.get_iter_at(:offset => pos + 1)
    vbuf.delete(itr, itr2)
    anchor = vbuf.create_child_anchor(itr)

    da = ResizableImage.new(imgpath, view)
    view.add_child_at_anchor(da, anchor)

    da.set_draw_func do |widget, cr|
      da.do_draw(widget, cr)
    end

    da.scale_image

    @images << { :path => imgpath, :obj => da, :anchor => anchor }

    gui_set_current_buffer(@id) #TODO: needed?
  end

  def set_encrypted(password)
    @crypt = Encrypt.new(password)
    message("Set buffer encrypted")
  end

  def set_unencrypted()
    @crypt = nil
  end

  def unindent
    debug("unindent", 2)
    if visual_mode?
      unindent_selection
      return
    end
    cnf.tab.width!.times {
      p = @pos - 1
      if p >= 0
        if self[p] == " "
          delete(BACKWARD_CHAR)
        end
      else
        break
      end
    }
  end

  # Map every line spanning the visual selection through the block and replace
  # the range with the result, then restore the selection to cover the same
  # lines. The block receives one line (with its trailing "\n") and returns the
  # replacement line.
  def transform_selected_lines
    (startpos, endpos) = get_visual_mode_range2
    first = get_line_start(startpos)
    last = get_line_end(endpos - 1)
    start_lpos = get_line_pos(first)
    end_lpos   = get_line_pos(last)
    r = first..last
    mod = self[r].lines.map { |line| yield(line) }.join
    replace_range(r, mod)
    @selection_start = line_range(start_lpos, 1).begin
    set_pos(line_range(end_lpos, 1).begin)
  end

  def indent_selection
    tw = cnf.tab.width!
    convert = cnf.tab.to_spaces_default?
    convert = true if cnf.tab.to_spaces_languages?.include?(@lang)
    convert = false if cnf.tab.to_spaces_not_languages?.include?(@lang)
    pad = convert ? " " * tw : "\t"
    transform_selected_lines { |line| line == "\n" ? line : pad + line }
  end

  def unindent_selection
    tw = cnf.tab.width!
    transform_selected_lines { |line| line.sub(/^\t| {1,#{tw}}/, "") }
  end

  # Remove all leading whitespace from every line spanning the selection, or
  # from the current line when not in visual mode. The cursor stays on the same
  # character (or moves to the line start if it was inside the indentation).
  def remove_indent_selection
    return transform_selected_lines { |line| line.sub(/^[ \t]+/, "") } if visual_mode?
    r = line_range(@lpos, 1, false)
    indent = self[r][/\A[ \t]*/].size
    return if indent == 0
    newpos = [@pos - indent, r.begin].max
    delete_range(r.begin, r.begin + indent - 1, register: false)
    set_pos(newpos)
  end

  # Like remove_indent_selection, but remove only the indentation common to
  # all selected lines: x leading whitespace chars from each line, where x is
  # the smallest indent among the non-blank lines (relative indentation is
  # kept). Blank lines lose at most x chars. On a single line this removes its
  # whole indent, so outside visual mode it acts on the current line like g i.
  def remove_common_indent_selection
    return remove_indent_selection if !visual_mode?
    (startpos, endpos) = get_visual_mode_range2
    lines = self[get_line_start(startpos)..get_line_end(endpos - 1)].lines
    x = lines.reject { |l| l.strip.empty? }.map { |l| l[/\A[ \t]*/].size }.min
    return if x.nil? || x == 0
    transform_selected_lines { |line| line.sub(/\A[ \t]{0,#{x}}/, "") }
  end

  def handle_drag_and_drop(fname)
    debug "[buffer] Dropped file: #{fname}"
    if is_image_file(fname)
      debug "Dropped image file"
      insert_image_after_current_line(fname)
    elsif file_is_text_file(fname)
      debug "Dropped text file"
      open_new_file(fname)
    else
      debug "Dropped unknown file format"
    end
    # add_image(imgpath, pos)
  end

  def get_file_type()
    return @lang
  end

  # Encoding and line endings of the file on disk ({ encoding:, crlf: }, see
  # read_file_with_format); nil = UTF-8 with \n. The buffer itself is always
  # UTF-8 with \n; save converts back unless the user chooses to convert.
  attr_reader :file_format

  def file_format=(fmt)
    @file_format = fmt
    @keep_file_format = nil # ask again on the next save
  end

  # "ISO-8859-1 with CRLF line endings", or nil for UTF-8 with \n.
  def file_format_desc
    return nil if @file_format.nil?
    enc = @file_format[:encoding]
    parts = []
    parts << enc.name unless [Encoding::UTF_8, Encoding::US_ASCII].include?(enc)
    parts << "CRLF line endings" if @file_format[:crlf]
    return nil if parts.empty?
    parts.join(" with ")
  end

  # Save in the file's original format? The user's answer for this buffer
  # (true = keep, false = convert to UTF-8 + LF), set when asked on save.
  attr_accessor :keep_file_format

  # The decision for the next save: the answer given for this buffer, else
  # cnf.file_format.on_save ("keep" / "convert"); nil = ask.
  def keep_file_format_on_save
    return @keep_file_format unless @keep_file_format.nil?
    case cnf.file_format.on_save!
    when "keep" then true
    when "convert" then false
    end
  end

  # What saving will do with this file's format, for the message shown on load.
  def file_format_save_note
    case keep_file_format_on_save
    when true then "it will be saved in that format"
    when false then "it will be saved as UTF-8 with LF"
    else "you will be asked on first save whether to keep it"
    end
  end

  def ask_file_format(&after)
    params = {}
    params["title"] = "#{CGI.escapeHTML(File.basename(@fname))} is #{file_format_desc}.\nSave it in that format?"
    params["inputs"] = {}
    params["inputs"]["keep_btn"] = { :label => "Keep #{file_format_desc}", :type => :button, :default_focus => true }
    params["inputs"]["convert_btn"] = { :label => "Convert to UTF-8 with LF", :type => :button }
    params[:callback] = proc { |x|
      @keep_file_format = x["keep_btn"] == "submit"
      after&.call
    }
    PopupFormGenerator.new(params).run
  end

  # The bytes to write for content in the file's chosen format, or nil when
  # saving as UTF-8 + \n. Falls back to UTF-8 (with a message) if the text has
  # characters the original encoding cannot hold.
  def encode_for_disk(content)
    return nil if file_format_desc.nil? || !keep_file_format_on_save
    s = @file_format[:crlf] ? content.gsub("\n", "\r\n") : content.dup
    enc = @file_format[:encoding]
    begin
      s = s.encode(enc) unless [Encoding::UTF_8, Encoding::US_ASCII].include?(enc)
    rescue Encoding::UndefinedConversionError => ex
      message("Cannot save #{File.basename(@fname)} as #{enc.name} (#{ex.error_char.dump} has no #{enc.name} code); saved as UTF-8")
      @file_format = { encoding: Encoding::UTF_8, crlf: @file_format[:crlf] }
    end
    s.b
  end

  def revert()
    return if !@fname
    return if !File.exist?(@fname)
    message("Revert buffer #{@fname}")
    str, fmt = read_file_with_format(@fname)
    @file_format = fmt
    str << "\n" if str[-1] != "\n"
    _fold_state
    if !@folds.empty? || (cnf.fold.start_closed? && str =~ FOLD_START_RE)
      # Folded text is not in the buffer as it is on disk, so a diff would
      # not line up: replace wholesale, keep cursor and view by line number.
      revert_by_replace(str)
    else
      revert_by_diff(str)
    end
    @last_save = Time.now
    refresh_title
  end

  # Reload by applying only the differences as deltas, so that cursor, marks
  # and edit positions move with the text around them (e.g. after the file
  # was edited by an external program). The reload is one undo step.
  def revert_by_diff(str)
    return if str == self.to_s
    v = view
    top = v&.top_visible_pos
    nvis = v&.visible_line_count
    cur = @pos
    new_undo_group
    @reloading = true
    for d in diff_deltas(str)
      top = shift_pos_by_delta(top, d) if top
      cur = shift_pos_by_delta(cur, d)
      add_delta(d, true)
    end
    @reloading = false
    new_undo_group
    set_pos(cur.clamp(0, [self.size - 1, 0].max))
    return if v.nil?
    # Keep the same text at the top of the view, unless that would leave the
    # cursor off screen (many lines added between them).
    top = nil if top && nvis && @pos >= top && get_line_and_col_pos(@pos)[0] - get_line_and_col_pos(top)[0] >= nvis
    top = nil if top && @pos < top
    v.handle_deltas(scroll: top.nil?)
    v.scroll_to_top_pos(top) if top
  end

  def revert_by_replace(str)
    v = view
    top = v&.top_visible_pos
    toplnum = top ? get_line_and_col_pos(top)[0] : nil
    (lnum, col) = [@lpos, @cpos]
    self.set_content(str)
    lnum = lnum.clamp(0, @line_ends.size - 1)
    set_line_and_column_pos(lnum, col)
    if v && toplnum
      toplnum = toplnum.clamp(0, @line_ends.size - 1)
      v.scroll_to_top_pos(toplnum == 0 ? 0 : @line_ends[toplnum - 1] + 1)
    end
  end

  # Map position p over delta d. An insert at p moves p only when it is a
  # whole-line insert (ends in "\n"), so text added above a line start pushes
  # it down but text added after the cursor on the same spot does not.
  def shift_pos_by_delta(p, d)
    if d[1] == INSERT
      return p + d[2] if d[0] < p || (d[0] == p && d[3].end_with?("\n"))
    elsif d[1] == DELETE
      return d[0] if p >= d[0] && p < d[0] + d[2]
      return p - d[2] if p >= d[0] + d[2]
    end
    p
  end

  # Deltas (in application order) that turn the buffer contents into newstr.
  # Diffs by line, then by char inside each changed hunk so positions on
  # lines that were only partly edited map precisely.
  def diff_deltas(newstr)
    deltas = []
    pos = 0 # Position in the partially updated buffer
    for (op, a, b) in myers_diff(self.lines, newstr.lines, 1000)
      if op == :eq
        pos += a.sum(&:size)
        next
      end
      del = a.join
      ins = b.join
      parts = [[:change, del, ins]]
      if !del.empty? && !ins.empty? && del.size + ins.size < 4000
        parts = myers_diff(del.chars, ins.chars, 300).map { |(o, x, y)| [o, x.join, y.join] }
      end
      for (o, x, y) in parts
        if o == :eq
          pos += x.size
          next
        end
        deltas << [pos, DELETE, x.size] if !x.empty?
        if !y.empty?
          deltas << [pos, INSERT, y.size, y]
          pos += y.size
        end
      end
    end
    deltas
  end

  # Myers diff of arrays a and b. Returns [[:eq, items, items] or
  # [:change, deleted, inserted], ...]. If more than max_d edits are needed,
  # the differing middle is returned as one :change.
  def myers_diff(a, b, max_d)
    # Common prefix/suffix are cheap and usually most of the input
    pre = 0
    pre += 1 while pre < a.size && pre < b.size && a[pre] == b[pre]
    suf = 0
    suf += 1 while suf < a.size - pre && suf < b.size - pre && a[-1 - suf] == b[-1 - suf]
    am = a[pre...(a.size - suf)]
    bm = b[pre...(b.size - suf)]
    ops = [] # [:eq|:del|:ins, item]
    n = am.size
    m = bm.size
    trace = []
    v = { 1 => 0 }
    found = false
    (0..[n + m, max_d].min).each { |d|
      trace << v.dup
      (-d..d).step(2) { |k|
        x = (k == -d || (k != d && v[k - 1] < v[k + 1])) ? v[k + 1] : v[k - 1] + 1
        y = x - k
        while x < n && y < m && am[x] == bm[y]
          x += 1
          y += 1
        end
        v[k] = x
        if x >= n && y >= m
          found = true
          break
        end
      }
      break if found
    }
    if found
      x = n
      y = m
      (trace.size - 1).downto(0) { |d|
        vd = trace[d]
        k = x - y
        prev_k = (k == -d || (k != d && vd[k - 1] < vd[k + 1])) ? k + 1 : k - 1
        prev_x = d == 0 ? 0 : vd[prev_k]
        prev_y = prev_x - prev_k
        while x > prev_x && y > prev_y
          x -= 1
          y -= 1
          ops << [:eq, am[x]]
        end
        break if d == 0
        if x == prev_x
          ops << [:ins, bm[y - 1]]
        else
          ops << [:del, am[x - 1]]
        end
        x = prev_x
        y = prev_y
      }
      ops.reverse!
    else
      am.each { |e| ops << [:del, e] }
      bm.each { |e| ops << [:ins, e] }
    end

    res = []
    res << [:eq, a[0...pre], a[0...pre]] if pre > 0
    for (op, e) in ops
      if op == :eq
        res << [:eq, [], []] if res.empty? || res[-1][0] != :eq
        res[-1][1] << e
        res[-1][2] << e
      else
        res << [:change, [], []] if res.empty? || res[-1][0] != :change
        res[-1][op == :del ? 1 : 2] << e
      end
    end
    res << [:eq, a[(a.size - suf)..], a[(a.size - suf)..]] if suf > 0
    res
  end

  def init_encrypted(crypt:, filename:, encrypted:)
    @crypt = crypt
    @encrypted_str = encrypted
    set_filename(filename)
    gui_set_buffer_contents(@id, self.to_s)
  end

  def sanitycheck_btree()
    # lines = self.split("\n")

    lines = self.scan(/([^\n]*\n)/).flatten

    i = 0
    ok = true
    @bt.each_line { |r|
      if lines[i] != r #or true
        debug "NO MATCH FOR LINE:"
        debug "i=#{i}["
        # debug "[orig]pos=#{leaf.pos} |#{leaf.data}|"
        # debug "spos=#{spos} nchar=#{leaf.nchar} epos=#{epos} a[]=\nr=|#{r}|"
        debug "fromtree:|#{r}|"
        debug "frombuf:|#{lines[i]}"
        debug "]"
        ok = false
      end
      i += 1
    }

    debug "BT: NO ERRORS" if ok
    debug "BT: ERRORS" if !ok
  end

  def set_content(str)
    @encrypted_str = nil
    @gui_update_highlight = true
    @ftype = nil

    if (str[-1] != "\n")
      str << "\n"
    end

    # Any previously stashed folds refer to the text being replaced (fold.rb);
    # with cnf.fold.start_closed the new content loads with all folds collapsed.
    fold_reset
    str = fold_collapse_all(str) if cnf.fold.start_closed?

    self.replace(str)
    @line_ends = LineTree.from_string(self) # Array-like: see line_tree.rb
    words = scan_all_words
    Autocomplete.add_words(words, @id)

    if cnf.btree.experimental?
      @bt = BufferTree.new(self)
      if cnf.debug?
        sanitycheck_btree()
      end
    end

    @last_update = Time.now - 10
    debug("line_ends")
    @marks = Hash.new
    @basename = ""
    @pathname = Pathname.new(fname) if @fname
    @basename = @pathname.basename if @fname
    @pos = 0 # Position in whole file
    @cpos = 0 # Column position on current line
    @lpos = 0 # Number of current line
    @edit_version = 0 # +1 for every buffer modification
    @larger_cpos = 0 # Store @cpos when move up/down to shorter line than @cpos
    @call_func = nil
    @deltas = []
    @edit_history = []   # Array of groups: [[delta, ...], ...]
    @current_group = []  # In-progress undo group
    @last_delta_time = nil
    @macro_group_active = false
    @redo_stack = []
    @edit_pos_history = []
    @edit_pos_history_i = 0
    # @highlights = {}
    @highlights.delete_if { |x| true }

    @syntax_parser = nil

    @is_highlighted = false
    @update_highlight = true
    @update_hl_startpos = 0
    @update_hl_endpos = self.size - 1

    gui_set_buffer_contents(@id, self.to_s)
    @images = [] #TODO: if reload
    hpt_scan_images(self)

    # add_hl_update(@update_hl_startpos, @update_hl_endpos)
  end

  def set_filename(filename)
    debug "set_filename(filename) #{filename}"
    @fname = filename
    @title = "*#{@prefix}-#{@id}*"
    return if @fname.nil?
    @pathname = Pathname.new(fname) if @fname
    @basename = @pathname.basename if @fname

    @title = File.basename(@fname)
    @dirname = File.dirname(@fname)
    userhome = File.expand_path("~")
    @subtitle = @fname.gsub(/^#{userhome}/, "~")
    vma.buffers.last_dir = @dirname

    detect_file_language
    gui_set_window_title(@title, @subtitle)
  end

  def add_hl_update(startpos, endpos)
    return if @is_highlighted == false

    debug "@update_hl_endpos = #{endpos}"
    @hl_queue << [startpos, endpos]
  end

  def run_delta(delta, auto_update_cpos = false)
    # auto_update_cpos: In some cases position of cursor should be updated automatically based on change to buffer (delta). In other cases this is handled by the action that creates the delta.

    # delta[0]: char position
    # delta[1]: INSERT or DELETE
    # delta[2]: number of chars affected
    # delta[3]: text to add in case of insert

    @version += 1
    if cnf.btree.experimental?
      @bt.handle_delta(Delta.new(delta[0], delta[1], delta[2], delta[3]))
    end

    if !@lsp.nil?
      dc = delta.clone
      dc[3] = "" if dc[3].nil?
      dc[4] = get_line_and_col_pos(delta[0])
      dc[5] = get_line_and_col_pos(delta[0] + delta[2])
      @lsp.handle_delta(dc, @fname, @version)
    end
    pos = delta[0]
    # Reloading from disk keeps the user's own edit positions (shifted by
    # update_index) instead of recording the external changes.
    if !@reloading
      if @edit_pos_history.any? and (@edit_pos_history.last - pos).abs <= 2
        @edit_pos_history.pop
      end

      lsp = get_line_start(pos)

      if @edit_pos_history[-1] != lsp
        @edit_pos_history << lsp
      end
      @edit_pos_history_i = 0
    end

    if delta[1] == DELETE
      delta[3] = self.slice!(delta[0], delta[2])
      cleanup_deleted_images(delta[3])
      @deltas << delta
      update_index(pos, -delta[2])
      update_line_ends(pos, -delta[2], delta[3])
      update_highlights(pos, -delta[2], delta[3])
      update_cursor_pos(pos, -delta[2]) if auto_update_cpos

      @update_hl_startpos = pos - delta[2]
      @update_hl_endpos = pos
      add_hl_update(@update_hl_startpos, @update_hl_endpos)
    elsif delta[1] == INSERT
      self.insert(delta[0], delta[3])
      @deltas << delta
      debug [pos, +delta[2]].inspect
      update_index(pos, +delta[2])
      update_cursor_pos(pos, +delta[2]) if auto_update_cpos
      update_line_ends(pos, +delta[2], delta[3])
      update_highlights(pos, +delta[2], delta[3])

      @update_hl_startpos = pos
      @update_hl_endpos = pos + delta[2]
      add_hl_update(@update_hl_startpos, @update_hl_endpos)

      if delta[3]&.include?("⟦img:")
        buf_ref = self
        run_as_idle proc { hpt_scan_images(buf_ref) }
      end
    end
    debug("DELTA=#{delta.inspect}", 2)
    # sanity_check_line_ends #TODO: enable with debug mode
    #highlight_c()

    @update_highlight = true

    return delta
  end

  # Update cursor position after change in buffer contents.
  # e.g. after processing with external command like indenter
  def update_cursor_pos(pos, changeamount)
    if @pos > pos + 1 && changeamount > 0
      # @pos is after addition
      set_pos(@pos + changeamount)
    elsif @pos > pos && changeamount < 0 && @pos < pos - changeamount
      # @pos is between removal
      set_pos(pos)
    elsif @pos > pos && changeamount < 0 && @pos >= pos - changeamount
      # @pos is after removal
      set_pos(@pos + changeamount)
    end
  end

  def update_index(pos, changeamount)
    # debug "pos #{pos}, changeamount #{changeamount}, @pos #{@pos}"
    @edit_pos_history.collect! { |x| r = x if x <= pos; r = x + changeamount if x > pos; r }
    # TODO: handle between removal case
    for k in @marks.keys
      #            debug "change(?): pos=#{pos}, k=#{k}, #{@marks[k]}, #{changeamount}"
      if @marks[k] > pos
        @marks[k] = @marks[k] + changeamount
      end
    end
    # The panel shows each mark's line number and text
    if equal?(vma.buf) && @marks.keys.any? { |k| k.is_a?(String) && k.size == 1 }
      vma.gui&.file_panel_marks_changed
    end
    # Keep closed-fold placeholder anchors (fold.rb) in sync with edits elsewhere.
    @fold_anchors&.each_key do |k|
      @fold_anchors[k] = @fold_anchors[k] + changeamount if @fold_anchors[k] > pos
    end
  end

  # Flush @current_group into @edit_history and start a new group.
  # Called on mode changes, macro boundaries, and time threshold.
  def new_undo_group
    if @current_group.any?
      @edit_history << @current_group
      @current_group = []
    end
  end

  def apply_inverse_delta(d)
    if d[1] == DELETE
      run_delta([d[0], INSERT, 0, d[3]])
    elsif d[1] == INSERT
      run_delta([d[0], DELETE, d[3].size])
    end
  end

  def undo()
    new_undo_group  # flush any in-progress group first
    return if @edit_history.empty?
    group = @edit_history.pop
    @redo_stack << group
    group.reverse_each { |d| apply_inverse_delta(d) }
    set_pos(group.first[0])
    calculate_line_and_column_pos
  end

  def redo()
    return if @redo_stack.empty?
    group = @redo_stack.pop
    group.each { |d| run_delta(d) }
    @edit_history << group
    set_pos(group.last[0])
    calculate_line_and_column_pos
  end

  def current_char()
    return self[@pos]
  end

  def current_line()
    range = line_range(@lpos, 1)
    return self[range]
  end

  # Line comment marker for this buffer. `fallback` is returned when neither the
  # user rules nor the language define one (nil lets the caller tell that apart).
  def get_com_str(fallback = "//")
    com_str = nil

    # User config: rules matched against filename in order, first match wins.
    if @fname
      fname_base = File.basename(@fname)
      rules = cnf.comment_chars!
      if rules.is_a?(Array)
        match = rules.find { |r| fname_base.match?(r[:pattern]) }
        com_str = match[:char] if match
      end
    end

    if com_str.nil? && !@lang_nfo.nil?
      com_str = @lang_nfo.get_metadata("line-comment-start")
    end

    com_str = fallback if com_str.nil?

    return com_str
  end

  def comment_linerange(r)
    com_str = get_com_str()
    lines = self[r].lines
    mod = ""
    lines.each { |line|
      m = line.match(/^(\s*)(\S.*)/)
      if m == nil or m[2].size == 0
        ret = line
      elsif m[2].size > 0
        ret = "#{m[1]}#{com_str} #{m[2]}\n"
      end
      mod << ret
    }
    replace_range(r, mod)
  end

  def get_line_start(pos)

    # Bsearch: https://www.rubydoc.info/stdlib/core/Array#bsearch-instance_method
    # In find-minimum mode (this is a good choice for typical use case), the block must return true or false, and there must be an index i (0 <= i <= ary.size) so that:
    # the block returns false for any element whose index is less than i, and
    # the block returns true for any element whose index is greater than or equal to i.
    # This method returns the i-th element. If i is equal to ary.size, it returns nil.

    # (OLD) slower version:
    # ls = @line_ends.select { |x| x < pos }.max
    a = @line_ends.bsearch_index { |x| x >= pos }

    a = @line_ends[-1] if a == nil
    a = 0 if a == nil
    return 0 if a == 0 # First line
    a = a - 1
    ls = nil
    ls = @line_ends[a] if a != nil
    # if a != nil and ls != @line_ends[a]
    # debug "NO MATCH @line_ends[a]"
    # end

    if ls == nil
      ls = 0
    else
      ls = ls + 1
    end
    return ls
  end

  def get_line_end(pos)
    return @line_ends.bsearch { |x| x > pos } # @line_ends is sorted
  end

  def comment_selection(op = :comment)
    if visual_mode?
      (startpos, endpos) = get_visual_mode_range2
      first = get_line_start(startpos)
      #      last = get_line_end(endpos)
      last = get_line_end(endpos - 1)
      if op == :comment
        comment_linerange(first..last)
      elsif op == :uncomment
        uncomment_linerange(first..last)
      end
      self.end_visual_mode
    end
  end

  def uncomment_linerange(r)
    com_str = get_com_str()
    #r=self.line_range(self.lpos, 2)
    lines = self[r].split(/(\n)/).each_slice(2).map { |x| x[0] }
    mod = lines.collect { |x| x.sub(/^(\s*)(#{com_str}\s?)/, '\1') + "\n" }.join()
    replace_range(r, mod)
  end

  def get_repeat_num()
    vma.kbd.method_handles_repeat = true
    repeat_num = 1
    if !vma.kbd.next_command_count.nil? and vma.kbd.next_command_count > 0
      repeat_num = vma.kbd.next_command_count
    end
    return repeat_num
  end

  def comment_line(op = :comment)
    num_lines = get_repeat_num()
    lrange = line_range(@lpos, num_lines)
    if op == :comment
      comment_linerange(lrange)
    elsif op == :uncomment
      uncomment_linerange(lrange)
    end
  end

  def current_line_range()
    range = line_range(@lpos, 1)
    return range
  end

  def line_range(start_line, num_lines, include_last_nl = true)
    end_line = start_line + num_lines - 1
    if end_line >= @line_ends.size
      debug("lpos too large")
      end_line = @line_ends.size - 1
    end
    start = @line_ends[start_line - 1] + 1 if start_line > 0
    start = 0 if start_line == 0
    if include_last_nl
      _End = @line_ends[end_line]
    else
      _End = @line_ends[end_line] - 1
    end
    _End = start if _End < start
    debug "line range: start=#{start}, end=#{_End}"
    return start.._End
  end

  def copy(range_id, mark = nil)
    debug "range_id: #{range_id}"
    debug range_id.inspect
    range = get_range(range_id, mark: mark)
    return if range.nil?
    debug range.inspect
    vma.clipboard.set(self[range])
    Gui.flash_range(self, range)
  end

  def update_bufpos_on_change(positions, xpos, changeamount)
    # debug "xpos=#{xpos} changeamount=#{changeamount}"
    positions.collect { |x|
      r = nil
      r = x if x < xpos
      r = x + changeamount if changeamount < 0 && x + changeamount >= xpos
      r = x + changeamount if changeamount > 0 && x >= xpos
      r
    }
  end

  def update_highlights(pos, changeamount, changestr)
    return if !self.is_highlighted
    lpos, cpos = get_line_and_col_pos(pos)
    if @highlights and @highlights[lpos]
      hl = @highlights[lpos]
      hls = hl.collect { |x| x[0] } # highlight range start
      hle = hl.collect { |x| x[1] } # highlight range end
      hls2 = update_bufpos_on_change(hls, cpos, changeamount)
      hle2 = update_bufpos_on_change(hle, cpos, changeamount)
      hlnew = []
      for i in hle.size.times
        if hls2[i] != nil and hle2[i] != nil
          hlnew << [hls2[i], hle2[i], hl[i][2]]
        end
      end
      @highlights[lpos] = hlnew
    end
  end

  # changestr: the inserted text (changeamount >= 0) or the removed text.
  # O(log n) per edit (+ O(k) for k new lines), see line_tree.rb.
  def update_line_ends(pos, changeamount, changestr)
    if changeamount > -1
      @line_ends.insert(pos, changestr)
    else
      @line_ends.delete(pos, changestr)
    end
  end

  # Ranges to use in delete or copy operations
  def get_range(range_id, mark: nil)
    range = nil
    if range_id == :to_word_end
      # TODO: better way to make the search than + 150 from current position
      wmarks = get_word_end_marks(@pos, @pos + 150)
      if wmarks.any?
        range = @pos..(wmarks[0])
      end
    elsif range_id == :to_next_word # start of
      wmarks = get_word_start_marks(@pos, @pos + 150)
      if !wmarks[0].nil?
        range = @pos..(wmarks[0] - 1)
        debug range, 2
      else
        range = get_range(:to_word_end)
      end
      # Ripl.start :binding => binding

    elsif range_id == :to_mark
      debug "TO MARK"
      start = @line_ends[@lpos]
      mpos = @marks[mark]
      if !mpos.nil?
        range = start..mpos
      else
        return nil
      end
    elsif range_id == :to_char # vim d f <char>: up to and including next <char> on line
      lend = @line_ends[@lpos]
      cpos = self.index(mark, @pos + 1)
      return nil if cpos.nil? or cpos >= lend
      range = @pos..cpos
    elsif range_id == :to_char_backward # vim d F <char>: from prev <char> on line, excluding cursor
      lstart = @lpos == 0 ? 0 : @line_ends[@lpos - 1] + 1
      return nil if @pos <= lstart
      cpos = self.rindex(mark, @pos - 1)
      return nil if cpos.nil? or cpos < lstart
      range = cpos..(@pos - 1)
    elsif range_id == :to_line_end
      debug "TO LINE END"
      range = @pos..(@line_ends[@lpos] - 1)
    elsif range_id == :to_line_start
      debug "TO LINE START: #{@lpos}"

      if @cpos == 0
        range = nil
      else
        if @lpos == 0
          startpos = 0
        else
          startpos = @line_ends[@lpos - 1] + 1
        end
        endpos = @pos - 1
        range = startpos..endpos
      end
      # range = startpos..(@pos - 1)
    else
      crash("INVALID RANGE")
    end
    return range if range == nil
    if range.last < range.first
      range = range.last..range.first
      # range.last = range.first
    end
    if range.first < 0
      # range.first = 0
      range = 0..range.last
    end
    if range.last >= self.size
      # range.last = self.size - 1
      range = range.first..(self.size - 1)
    end
    debug range, 2
    return range
  end

  def reset_larger_cpos()
    @larger_cpos = @cpos
  end

  def move(direction)
    debug "cpos:#{@cpos} lpos:#{@lpos} @larger_cpos:#{@larger_cpos}"
    if direction == :forward_page
      debug "FORWARD PAGE"
      visible_range = get_visible_area()
      set_pos(visible_range[1])
      top_where_cursor()
    end
    if direction == :backward_page
      debug "backward PAGE"
      visible_range = get_visible_area()
      set_pos(visible_range[0])
      bottom_where_cursor()
    end

    if direction == FORWARD_CHAR
      return if @pos >= self.size - 1
      set_pos(@pos + 1)
    end
    if direction == BACKWARD_CHAR
      set_pos(@pos - 1)
    end
    if direction == FORWARD_LINE
      if @lpos >= @line_ends.size - 1 # Cursor is on last line
        debug("ON LAST LINE")
        return
      else
        @lpos += 1
      end
    end
    if direction == BACKWARD_LINE
      if @lpos == 0 # Cursor is on first line
        return
      else
        @lpos -= 1
      end
    end

    if direction == FORWARD_CHAR or direction == BACKWARD_CHAR
      reset_larger_cpos
    end

    if direction == BACKWARD_LINE or direction == FORWARD_LINE
      if @lpos > 0
        new_pos = @line_ends[@lpos - 1] - 1
      else
        new_pos = 0
      end

      _line = self.line(@lpos)
      if @cpos > (_line.size - 1)
        debug("$cpos too large: #{@cpos} #{@lpos}")
        if @larger_cpos < @cpos
          @larger_cpos = @cpos
        end
        @cpos = line(@lpos).size - 1
      end

      if @larger_cpos > @cpos and @larger_cpos < (_line.size)
        @cpos = @larger_cpos
      elsif @larger_cpos > @cpos and @larger_cpos >= (_line.size)
        @cpos = line(@lpos).size - 1
      end

      #new_pos += @cpos
      #@pos = new_pos
      calculate_pos_from_cpos_lpos(false)
    end
  end

  def mark_current_position(mark_char)
    @marks[mark_char] = @pos
    vma.gui&.file_panel_marks_changed if equal?(vma.buf)
  end

  # Marks set with m <char>, as { char => pos } sorted by char. @marks also
  # holds internal entries (e.g. bookmarks' "bm:<id>"), which are excluded.
  def user_marks
    @marks.select { |k, _| k.is_a?(String) && k.size == 1 }.sort.to_h
  end

  # Get positions of last characters in words
  def get_word_end_marks(startpos, endpos)
    startpos = 0 if startpos < 0
    endpos = self.size if endpos > self.size
    search_str = self[(startpos)..(endpos)]
    return if search_str == nil
    wsmarks = scan_indexes(search_str, /(?<=\p{Word})[^\p{Word}]/)
    wsmarks = wsmarks.collect { |x| x + startpos - 1 }
    return wsmarks
  end

  # Get positions of first characters in words
  def get_word_start_marks(startpos, endpos)
    startpos = 0 if startpos < 0
    endpos = self.size if endpos > self.size
    search_str = self[(startpos)..(endpos)]
    return if search_str == nil
    wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}/)
    wsmarks = wsmarks.collect { |x| x + startpos }
    return wsmarks
  end

  def scan_marks(startpos, endpos, regstr, offset = 0)
    startpos = 0 if startpos < 0
    endpos = self.size if endpos > self.size
    search_str = self[(startpos)..(endpos)]
    return if search_str == nil
    marks = scan_indexes(search_str, regstr)
    marks = marks.collect { |x| x + startpos + offset }
    return marks
  end

  def handle_word(wnfo)
    word = wnfo[0]
    wtype = wnfo[1]
    if wtype == :url
      open_url(word)
    elsif wtype == :linepointer
      jump_to_file(word[0], word[1], word[2])
    elsif wtype == :textfile
      open_new_file(word)
    elsif wtype == :file
      open_with_default_program(word)
    elsif wtype == :hpt_link
      open_new_file(word)
    elsif wtype == :help
      case word
      when "keybindings" then call_action("help.keys")
      when "vim_conflicts" then call_action("help.vim_conflicts")
      when *HELP_PAGES then show_help_page(word)
      else message("No help page #{word}")
      end
    elsif wtype == :run
      hpt_run_link(word)
    end
  end

  # Activated when enter/return pressed
  def handle_line_action()
    # Enter on a fold-start ({{{) or a closed-fold placeholder toggles the fold.
    return if fold_toggle_at(lpos)
    if line_action_handler.class == Proc or line_action_handler.class == Method
      # Custom handler
      line_action_handler.call(lpos)
    else
      # Generic default action
      cur_nonwhitespace_word_action()
    end
  end

  def get_word_in_pos(p, boundary: :space)
    maxws = 200 # max word size
    if boundary == :space
      wem = scan_marks(p, p + maxws, /(?<=\S)\s/, -1)
      wsm = scan_marks(p - maxws, p, /((?<=\s)\S)|^\S/)
      word_start = wsm[-1]
      word_end = wem[0]
    elsif boundary == :word2
      wem = scan_marks(p, p + maxws, /\b/,-1)
      wsm = scan_marks(p - maxws, p, /\b\w/)
      word_start = wsm[-1]
      word_end = wem.select{|x|x>=word_start}[0]
     
    elsif boundary == :word
    #TODO: change name :word. This works only with autocomplete
      wsm = scan_marks(p - maxws, p, /\b\w/)
      word_start = wsm[-1]
      word_end = p
    end

    word_start = p if word_start == nil
    word_end = p if word_end == nil
    word = self[word_start..word_end]

    return [word, (word_start..word_end)]
  end

  def get_cur_nonwhitespace_word()
    # ⟦run:…⟧ / ⟦help:…⟧ links may have spaces in them. On a help page the
    # cursor sits on a link's button, just before the (hidden) link.
    link = hpt_link_at(self, @pos)
    if link.nil? && self[@pos] == HPT_BUTTON_SLOT && hpt_link_at(self, @pos + 1)&.start_with?("⟦run:")
      link = hpt_link_at(self, @pos + 1)
    end
    if link
      if (m = link.match(/\A⟦run:(.*)⟧\z/))
        return [m[1], :run]
      elsif (m = link.match(/\A⟦help:(.*)⟧\z/))
        return [m[1], :help]
      end
    end
    (word, range) = get_word_in_pos(@pos, boundary: :space)
    debug "'WORD: #{word}'"
    # message("Open link #{word}")
    linep = get_file_line_pointer(word)
    debug "linep'#{linep}'"
    if word[0] != "/" and word[0] != "~"
      path = File.expand_path("#{bufs.last_dir}/#{word}")
    else
      path = File.expand_path(word)
    end
    wtype = nil
    if is_url(word)
      wtype = :url
    elsif is_existing_file(path)
      message("PATH:'#{word}'")
      # if vma.can_open_extension?(path)
      if file_is_text_file(path)
        wtype = :textfile
      else
        wtype = :file
      end
      word = path
    elsif linep != nil
      wtype = :linepointer
      word = linep
    elsif (bare_linep = resolve_bare_file_line_pointer(word))
      wtype = :linepointer
      word = bare_linep
    elsif m = word.match(/⟦help:(.*)⟧/)
      return [m[1], :help]
    else
      fn = hpt_check_cur_word(word)
      if !fn.nil?
        return [fn, :hpt_link]
      end
    end

    return [word, wtype]
  end

  # Existing file named by the whitespace-delimited word at pos, or nil.
  # Surrounding quotes, brackets and punctuation are ignored ("(foo.pdf)." ->
  # foo.pdf). Relative names resolve against this buffer's directory, then the
  # last used directory, then the working directory.
  def file_path_at(pos)
    word, _range = get_word_in_pos(pos, boundary: :space)
    return nil if word.nil?
    resolve_file_path(word)
  end

  # Absolute path of the existing file that word names, or nil. See
  # file_path_at for the rules.
  def resolve_file_path(word)
    word = word.strip.sub(/\A[("'`\[<{]+/, "").sub(/[)"'`\]>},.;:!?]+\z/, "")
    return nil if word.empty? or is_url(word)
    if word.start_with?("/", "~")
      cands = [File.expand_path(word)]
    else
      dirs = [@fname && File.dirname(@fname), bufs.last_dir, Dir.pwd].compact.uniq
      cands = dirs.map { |d| File.expand_path(word, d) }
    end
    cands.find { |p| File.file?(p) }
  end

  # Absolute paths of the existing files named in this buffer, unique, in
  # order of first appearance: whitespace-separated words (as for
  # file_path_at) and hyperplaintext links ⟦path⟧ / ⟦img:path⟧ / ⟦audio:path⟧.
  # Like hpt_check_cur_word, a link may leave out a ".txt" extension. Plain
  # words are only checked if they contain "." or "/", which skips most text.
  def file_links
    found = []
    to_s.scan(/⟦(?:(?:audio|img):)?([^⟧]+)⟧|(\S+)/).uniq.each do |link, word|
      if link
        p = resolve_file_path(link) || resolve_file_path("#{link}.txt")
      elsif word.include?(".") or word.include?("/")
        p = resolve_file_path(word)
      end
      found << p if p
    end
    found.uniq
  end

  def cur_nonwhitespace_word_action()

    # (word, wtype) = get_cur_nonwhitespace_word()
    wnfo = get_cur_nonwhitespace_word()
    handle_word(wnfo)
  end

  # J: join the next line to the current one as Vim does. The next line's
  # leading whitespace goes, and one space is put between them unless the
  # next line is empty (or blank), the current line is empty or ends in
  # whitespace, or the next line starts with ")". The cursor goes to the join
  # point: the space, or the first joined character; when nothing is joined
  # (an empty next line), the last character of the current line.
  # (tests/test_join_lines_vim.rb)
  def join_lines()
    if @lpos >= @line_ends.size - 1 # Cursor is on last line
      debug("ON LAST LINE")
      return
    end
    nl = @line_ends[@lpos] # the current line's "\n"
    cur = line(@lpos).chomp
    nxt_full = line(@lpos + 1).chomp
    lead = nxt_full[/\A\s*/].size
    nxt = nxt_full[lead..]
    sep = (nxt.empty? || cur.empty? || cur.match?(/\s\z/) || nxt.start_with?(")")) ? "" : " "
    # The "\n" and the next line's indentation (inclusive range)
    delete_range(nl, nl + lead, register: false)
    insert_txt_at(sep, nl) if !sep.empty?
    set_pos(nxt.empty? && !cur.empty? ? nl - 1 : nl)
  end

  def replace_with_char(char)
    debug "self_pos:'#{self[@pos]}'"
    return if self[@pos] == "\n"
    d1 = [@pos, DELETE, 1]
    d2 = [@pos, INSERT, 1, char]
    add_delta(d1, true)
    add_delta(d2, true)
    debug "DELTAS:#{self.deltas.inspect} "
  end

  def insert_txt_at(c, pos)
    if c.nil? or pos.nil?
      error("input c=nil || pos=nil")
      return
    end
    c = c.force_encoding("UTF-8");  #TODO:correct?
    c = "\n" if c == "\r"
    add_delta([pos, INSERT, c.size, c], true)
    calculate_line_and_column_pos
  end

  def append(c)
    pos = self.size - 1
    add_delta([pos, INSERT, c.size, c], true)
    calculate_line_and_column_pos
  end

  def execute_current_line_in_terminal(autoclose = false)
    s = get_current_line
    exec_in_terminal(s, autoclose)
  end

  def insert_new_line()
    s = get_current_line
    $hook.call(:insert_new_line, s)
    insert_txt("\n")
    # message("foo")
  end

  def insert_txt(c, mode = BEFORE)
    # start_profiler
    #Sometimes we get ASCII-8BIT although actually UTF-8  "incompatible character encodings: UTF-8 and ASCII-8BIT (Encoding::CompatibilityError)"
    c = c.force_encoding("UTF-8");  #TODO:correct?

    c = "\n" if c == "\r"
    if cnf.indent_based_on_last_line? and c == "\n" and @lpos > 0
      # Indent start of new line based on last line
      last_line = line(@lpos)
      m = /^( +)([^ ]+|$)/.match(last_line)
      if m
        c = c + " " * m[1].size if m
      end

      #if tab indent
      m = /^(\t+)([^\t]+|$)/.match(last_line)
      if m
        c = c + "\t" * m[1].size if m
      end

      # debug m.inspect
    end
    if mode == BEFORE
      insert_pos = @pos
      @pos += c.size
    elsif mode == AFTER
      insert_pos = @pos + 1
    else
      return
    end

    #self.insert(insert_pos,c)
    add_delta([insert_pos, INSERT, c.size, c], true)
    #debug("encoding: #{c.encoding}")
    #debug "c.size: #{c.size}"
    calculate_line_and_column_pos
    #@pos += c.size
    # end_profiler

    # Covers both the key binding path and the Wayland IM insert-text path
    if vma.kbd&.get_mode == :insert
      v = (self.view rescue nil)
      v.autocp_on_insert(c) if v.respond_to?(:autocp_on_insert)
    end
  end

  # Update buffer contents to newstr
  # Change by taking diff of old/new content
  def update_content(newstr)
    diff = Differ.diff_by_char(newstr, self.to_s)

    da = diff.get_raw_array

    pos = 0
    posA = 0
    posB = 0
    deltas = []

    for x in da
      if x.class == String
        posA += x.size
        posB += x.size
      elsif x.class == Differ::Change
        if x.insert?
          deltas << [posB, INSERT, x.insert.size, x.insert.clone]
          posB += x.insert.size
        elsif x.delete?
          posA += x.delete.size
          deltas << [posB, DELETE, x.delete.size]
        end
      end
    end
    for d in deltas
      add_delta(d, true, true)
    end
  end

  def selection_active?
    @selection_active
  end

  def end_selection()
    # @selection_start = nil
    @selection_active = false
    @visual_mode = false
    # print(caller())
  end

  # Keep an active selection on the same text after `amount` chars were
  # inserted at `at` (e.g. a comment added above it by an async task).
  def shift_selection_start(at, amount)
    return if @selection_start.nil? || @selection_start < at
    @selection_start += amount
  end

  def start_selection()
    @selection_start = @pos
    @selection_active = true
    @visual_mode = true #TODO: change use of @visual_mode into @selection_active
  end

  # Select the whole buffer (cursor lands on the final char)
  def select_all()
    return false if self.size == 0
    @selection_start = 0
    @selection_active = true
    @visual_mode = true # copy/delete of SELECTION are guarded by @visual_mode
    set_pos(self.size - 1)
    return true
  end

  # Start selection if not already started
  def continue_selection()
    start_selection if !@selection_active
  end

  def copy_active_selection(x = nil)
    debug "!COPY SELECTION vm=#{@visual_mode}"
    return if !@visual_mode

    debug "COPY SELECTION"
    s = self[get_visual_mode_range]
    if x == :append
      debug "APPEND"
      s += "\n" + vma.clipboard.get()
    end

    vma.clipboard.set(s)
    end_visual_mode
    return true
  end

  # Apply a text transform to the current visual selection: yields the selected
  # text, replaces the range with the block's return value, and ends visual
  # mode. No-op returning nil when not in visual mode; otherwise returns the
  # replacement text (truthy), so callers can guard follow-up work on it.
  def transform_visual_selection
    return if !@visual_mode
    r = get_visual_mode_range
    txt = yield(self[r])
    replace_range(r, txt)
    end_visual_mode
    txt
  end

  # Wrap `txt` with hyperplaintext style markers for `op`, or strip all markers
  # when op == :clear. Shared by style_transform (selection) and set_line_style.
  def apply_style_markers(txt, op)
    txt = "⦁" + txt + "⦁" if op == :bold
    txt = "⟦" + txt + "⟧" if op == :link
    txt = "❙" + txt + "❙" if op == :title
    txt = "╱" + txt + "╱" if op == :italic
    txt.gsub!(/[❙◼⟦⟧⦁╱]/, "") if op == :clear
    txt
  end

  def transform_text(txt, op)
    txt.upcase! if op == :upcase
    txt.downcase! if op == :downcase
    txt.gsub!(/\w+/, &:capitalize) if op == :capitalize
    txt.swapcase! if op == :swapcase
    txt.reverse! if op == :reverse
    txt = to_camel_case(txt) if op == :camelcase
    txt
  end

  def transform_selection(op)
    transform_visual_selection { |txt| transform_text(txt, op) }
  end

  # Apply transform `op` to a motion range, like vim's gU/gu/g~ operators.
  # range_id :line = current line without its newline (gUU); otherwise a
  # get_range id, e.g. :to_next_word (gUw). Cursor goes to the range start.
  def transform_range(range_id, op)
    if range_id == :line
      lstart = @lpos == 0 ? 0 : @line_ends[@lpos - 1] + 1
      lend = @line_ends[@lpos]
      range = lstart < lend ? lstart..(lend - 1) : nil
    else
      range = get_range(range_id)
    end
    return if range.nil?
    old = self[range]
    txt = transform_text(old.dup, op)
    replace_range(range, txt) if txt != old
    set_pos(range.first)
  end

  def eval_whole_buf(x = 888)
    s = self.to_s
    begin
      eval(s)
    rescue Exception
      message("Error running eval")
    else
    end
  end

  # Apply converter to the visual selection, or to the current line (without
  # its newline) when not in visual mode.
  def convert_selected_text(converter_id)
    #TODO: Detect if changed?
    if @visual_mode
      return if !transform_visual_selection { |txt| $vma.apply_conv(converter_id, txt) }
    else
      r = line_range(@lpos, 1, false)
      r = r.begin..(r.begin - 1) if self[r] == "\n" # empty line
      # Converters may add a trailing newline; the line already has one
      txt = $vma.apply_conv(converter_id, self[r]).chomp
      replace_range(r, txt)
    end
    view.after_action
  end

  def style_transform(op)
    #TODO: if txt[-1]=="\n"
    transform_visual_selection { |txt| apply_style_markers(txt, op) }
  end

  def set_line_style(op)
    lrange = line_range(@lpos, 1, false)
    txt = self[lrange]
    txt.gsub!(/◼ /, "") if op == :clear
    txt = apply_style_markers(txt, op)

    if [:h1, :h2, :h3, :h4].include?(op)
      txt.gsub!(/[❙◼⟦⟧⦁╱]/, "")
      txt.strip!
      txt = "◼ " + txt if op == :h1
      txt = "◼◼ " + txt if op == :h2
      txt = "◼◼◼ " + txt if op == :h3
      txt = "◼◼◼◼ " + txt if op == :h4
    end
    replace_range(lrange, txt)
  end

  def copy_line()
    num_lines = get_repeat_num()
    vma.clipboard.set(self[line_range(@lpos, num_lines)], linewise: true)
  end

  def put_file_path_to_clipboard
    vma.clipboard.set(self.fname)
  end

  def put_file_ref_to_clipboard
    vma.clipboard.set(self.fname + ":#{@lpos}")
  end

  def end_visual_mode()
    debug "end_visual_mode, #{vma.kbd.get_mode}, #{visual_mode?}", 2
    return if vma.kbd.get_mode != :visual
    if !visual_mode?
      debug "end_visual_mode, !visual_mode?"
      # TODO: should not happen
    end
    debug "End visual mode"
    # Selection still up: listeners can read get_visual_mode_range (dictation review)
    vma.hook.call(:visual_mode_ending, self)
    end_selection
    vma.kbd.to_previous_mode
    @visual_mode = false
    return true
  end

  def get_visual_mode_range2()
    r = get_visual_mode_range
    return [r.begin, r.end]
  end

  def get_current_line
    s = self[line_range(@lpos, 1)]
    return s
  end

  def get_current_selection()
    return "" if !@visual_mode
    return self[get_visual_mode_range]
  end

  def get_visual_mode_range()
    _start = @selection_start || @pos
    _end = @pos
    _start, _end = _end, _start if _start > _end
    return _start..(_end)
  end

  def selection_start()
    return -1 if !@visual_mode
    return @selection_start if @visual_mode
  end

  def visual_mode?()
    return @visual_mode
  end

  def value()
    return self.to_s
  end

  def save_as()
    debug "save_as"
    savepath = ""

    # If current file has fname, save to that fname
    # Else search for previously opened files and save to the directory of
    # the last viewed file that has a filename
    # selffers[$buffer_history.reverse[1]].fname

    if @fname
      savepath = File.dirname(@fname)
    else
      savepath = buflist.get_last_dir
    end
    gui_file_saveas(savepath)
    # calls back to file_saveas
  end

  def save_as_callback(fpath, confirmed = false)
    # The check if file exists is handled by Gtk::FileChooserDialog in GTK4
    # Keeping this code from GTK3 in case want to do this manually at some point
    # if !confirmed
    # @unconfirmed_path = fpath
    # if File.exist?(fpath) and File.file?(fpath)
    # params = {}
    # params["title"] = "The file already exists, overwrite? \r #{fpath}"
    # params["inputs"] = {}
    # params["inputs"]["yes_btn"] = { :label => "Yes", :type => :button, :default_focus => true }
    # callback = proc { |x| save_as_check_callback(x) }
    # params[:callback] = callback
    # PopupFormGenerator.new(params).run
    # return
    # elsif File.exist?(fpath) #and File.directory?(fpath)
    # params = {}
    # params["title"] = "Can't write to the destination.\r #{fpath}"
    # params["inputs"] = {}
    # params["inputs"]["ok_btn"] = { :label => "Ok", :type => :button, :default_focus => true }
    # PopupFormGenerator.new(params).run
    # return
    # end
    # end

    set_filename(fpath)
    save()
    # set_filename re-detects the language and drops the LSP client; attach the
    # one for the new language (e.g. an untitled buffer saved as foo.cpp).
    init_lsp if cnf.lsp.enabled?
    gui_set_window_title(@title, @subtitle) #TODO: if not active buffer?
  end

  # original_format: write in the file's own encoding / line endings when the
  # user chose to keep them (save only; backups etc. stay UTF-8).
  def write_contents_to_file(fpath, original_format: false)
    # content_for_disk re-inflates any closed folds so the file always holds the
    # fully expanded text (see fold.rb); equals self.to_s when nothing is folded.
    disk = content_for_disk
    raw = original_format && @crypt.nil? ? encode_for_disk(disk) : nil
    if raw
      mode = "wb"
      contents = raw
    elsif @crypt != nil
      mode = "wb+"
      contents = Encrypt::HEADER_V2 + @crypt.encrypt(disk)
    else
      mode = "w+"
      contents = disk
    end

    Thread.new {
      begin
        io = File.open(fpath, mode)
        io.set_encoding(self.encoding) unless raw # raw: already encoded bytes
        io.write(contents)
        io.close
      rescue Encoding::UndefinedConversionError => ex
        puts "Encoding::UndefinedConversionError"
        # this might happen when trying to save UTF-8 as US-ASCII
        # so just warn, try to save as UTF-8 instead.
        warn("Saving as UTF-8 because of: #{ex.class}: #{ex}")
        io.rewind

        io.set_encoding(Encoding::UTF_8)
        io.write(contents)
      rescue Errno::EACCES => ex
        GLib::Idle.add { message("File #{fpath} not writeable"); false }
        #TODO: show message box
      end
      @last_save = Time.now
      GLib::Idle.add { refresh_title; false }
      if cnf.auto_chmod_exec? && !@crypt && contents.match?(%r{\A#!\s*/\S})
        begin
          FileUtils.chmod("+x", fpath)
          GLib::Idle.add { message("Set executable: #{fpath}"); false }
        rescue => e
          GLib::Idle.add { message("chmod failed: #{e}"); false }
        end
      end
      debug "file saved on #{@last_save}"
      sleep 3
    }
  end

  def check_if_modified_outside_callback(x)
    debug "check_if_modified_outside_callback"
    if x["yes_btn"] == "submit"
      revert()
    end
  end

  def unsaved_changes?
    return true if @t_modified > @last_save
    return false
  end

  def refresh_title
    if vma.buf.equal?(self) # a Buffer is a String: == compares the text
      mod = unsaved_changes?
      pfx = mod ? "+ " : ""
      gui_set_window_title(pfx + title, subtitle, modified: mod)
    end
  end

  def check_if_modified_outside
    # Don't check if less than 8 seconds since last checked
    return false if @fname.nil?
    # Tests write and reload files quickly; the reload prompt would pop up
    # unasked in the middle of a run and take the keyboard with it.
    return false if vma_test_mode?
    return false if Time.now - 8 < @file_last_cheked
    @file_last_cheked = Time.now
    return false if !File.exist?(@fname)

    file_stat = File.stat(@fname)
    modification_time = file_stat.mtime

    if modification_time > @last_save and @last_asked_from_user < modification_time
      @last_asked_from_user = Time.now
      debug "File modified outside this program."
      params = {}
      params["title"] = "The file has been modified outside this program. Reload from disk? \r #{@fname}"
      params["inputs"] = {}
      params["inputs"]["yes_btn"] = { :label => "Yes", :type => :button, :default_focus => true }
      callback = proc { |x| check_if_modified_outside_callback(x) }
      params[:callback] = callback
      PopupFormGenerator.new(params).run
      return true
    end

    return false
  end

  AUTOSAVE_INTERVAL = 5 # seconds between autosave checks

  def autosave_path
    return nil if @fname.nil?
    dir = File.dirname(@fname)
    base = File.basename(@fname)
    File.join(dir, ".#{base}_vma_autosave")
  end

  def autosave
    return if @fname.nil?
    return if @t_modified <= @last_autosave
    apath = autosave_path
    contents = content_for_disk   # re-inflate closed folds (fold.rb)
    Thread.new {
      begin
        File.open(apath, "w+") { |io| io.set_encoding(self.encoding); io.write(contents) }
        @last_autosave = Time.now
        debug "autosaved to #{apath}"
      rescue => ex
        debug "autosave failed: #{ex}"
      end
    }
  end

  def start_autosave_timer
    @autosave_thread = Thread.new {
      loop do
        sleep AUTOSAVE_INTERVAL
        autosave
      end
    }
  end

  def delete_autosave_file
    apath = autosave_path
    return if apath.nil?
    File.delete(apath) if File.exist?(apath)
  rescue => ex
    debug "delete autosave failed: #{ex}"
  end

  # Run a deferred autosave check the first time a session-restored buffer is
  # entered. No-op unless flagged (see @needs_autosave_check). Cleared before
  # the check so it fires at most once.
  def check_autosave_load_if_pending
    return unless @needs_autosave_check
    @needs_autosave_check = false
    check_autosave_load
  end

  def check_autosave_load
    apath = autosave_path
    return if apath.nil? || !File.exist?(apath)
    if File.read(apath) == content_for_disk   # autosave stores the inflated form
      delete_autosave_file
      return
    end
    # The autosave predates the file on disk: the file has been saved/changed
    # more recently, so the autosave holds an outdated version. Drop it silently
    # rather than prompting. (A newer autosave — unsaved changes from a crash —
    # still prompts below.)
    if File.exist?(@fname) && File.mtime(apath) < File.mtime(@fname)
      delete_autosave_file
      return
    end
    title = "An autosave file was found for <b>#{File.basename(@fname)}</b>. Load autosave?"
    params = {
      "title" => title,
      "inputs" => {
        "yes_btn"    => { :label => "Load",           :type => :button, :default_focus => true },
        "diff_btn"   => { :label => "Review diff",    :type => :button },
        "delete_btn" => { :label => "Delete autosave", :type => :button },
      },
      :callback => proc { |x| load_autosave_callback(x) },
    }
    PopupFormGenerator.new(params).run
  end

  def load_autosave_callback(x)
    if x["yes_btn"] == "submit"
      str = read_file("", autosave_path)
      set_content(str)
      @t_modified = Time.now
      refresh_title
      message("Loaded autosave for #{@fname}")
    elsif x["diff_btn"] == "submit"
      apath = autosave_path
      diff_str = run_cmd("diff -u #{Shellwords.escape(@fname)} #{Shellwords.escape(apath)}")
      create_new_file(nil, diff_str.empty? ? "(no differences)\n" : diff_str)
      gui_set_file_lang(vma.buf.id, "diff") unless diff_str.empty?
      check_autosave_load
    elsif x["delete_btn"] == "submit"
      delete_autosave_file
      message("Deleted autosave for #{@fname}")
    end
  end

  def save()
    return if @module.respond_to?(:on_save) and @module.on_save
    check_if_modified_outside
    if !@fname
      save_as()
      return
    end
    if file_format_desc && keep_file_format_on_save.nil?
      ask_file_format { save }
      return
    end
    message("Saving file #{@fname}")
    write_contents_to_file(@fname, original_format: true)
    delete_autosave_file
    hook.call(:file_saved, self)
  end

  def close()
    idx = vma.buffers.get_buffer_by_id(@id)
    vma.buffers.close_buffer(idx)
  end

  def backup()
    fname = @fname
    return if !@fname
    spfx = fname.gsub("=", "==").gsub("/", "=:")
    spath = get_data_path("backup")
    FileUtils.mkdir_p(spath) rescue nil
    return false if !can_save_to_directory?(spath)
    datetime = DateTime.now().strftime("%d%m%Y:%H%M%S")
    savepath = "#{spath}/#{spfx}_#{datetime}"
    message("Backup buffer #{fname} TO: #{savepath}")
    if is_path_writable(savepath)
      write_contents_to_file(savepath)
    else
      message("PATH NOT WRITABLE: #{savepath}")
    end
  end
end

def is_path_writable(fpath)
  r = false
  if fpath.class == String
    r = true if File.writable?(Pathname.new(fpath).dirname)
  end
  return r
end

def backup_all_buffers()
  for b in bufs
    b.backup
  end
  message("Backup all buffers")
end
end # module Vimamsa
