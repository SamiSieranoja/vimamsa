require "digest"
require "tempfile"
require "fileutils"
require "pathname"
require "openssl"
require "ripl/multi_line"

$buffer_history = []

$update_highlight = false

$ifuncon = false

class Buffer < String
  attr_reader :pos, :lpos, :cpos, :deltas, :edit_history, :fname, :call_func, :pathname, :basename, :dirname, :update_highlight, :marks, :is_highlighted, :syntax_detect_failed, :id, :lang, :images, :last_save
  attr_writer :call_func, :update_highlight
  attr_accessor :gui_update_highlight, :update_hl_startpos, :update_hl_endpos, :hl_queue, :syntax_parser, :highlights, :gui_reset_highlight, :is_parsing_syntax, :line_ends, :bt, :line_action_handler, :module, :active_kbd_mode, :title, :subtitle, :paste_lines

  @@num_buffers = 0

  def initialize(str = "\n", fname = nil, prefix = "buf")
    debug "Buffer.rb: def initialize"
    super(str)

    @images = []
    @audiofiles = []
    @lang = nil
    @id = @@num_buffers
    @@num_buffers += 1
    @version = 0
    gui_create_buffer(@id, self)
    debug "NEW BUFFER fn=#{fname} ID:#{@id}"

    # If true, we will create new line after this and paste there
    @paste_lines = false

    @module = nil

    @last_save = @last_asked_from_user = @file_last_cheked = Time.now

    @crypt = nil
    @update_highlight = true
    @syntax_detect_failed = false
    @is_parsing_syntax = false
    @last_update = Time.now - 100
    @highlights = {}
    if fname != nil
      @fname = File.expand_path(fname)
      detect_file_language()
    else
      @fname = fname
    end
    @hl_queue = []
    @line_action_handler = nil

    @dirname = nil
    @title = "*#{prefix}-#{@id}*"
    @subtitle = ""

    if @fname
      @title = File.basename(@fname)
      @dirname = File.dirname(@fname)
      userhome = File.expand_path("~")
      # @subtitle = @dirname.gsub(/^#{userhome}/, "~")
      @subtitle = @fname.gsub(/^#{userhome}/, "~")
    end

    t1 = Time.now

    set_content(str)
    debug "init time:#{Time.now - t1}"

    # TODO: add \n when chars are added after last \n
    self << "\n" if self[-1] != "\n"
    @current_word = nil
    @active_kbd_mode = nil
    if conf(:enable_lsp)
      init_lsp
    end
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

  def set_active
    if !@active_kbd_mode.nil?
      $kbd.set_mode(@active_kbd_mode)
    else
      $kbd.set_mode_to_default
    end
    # gui_set_current_buffer(@id)
  end

  def set_executable
    if File.exists?(@fname)
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
    if !@lsp.nil?
      fpuri = URI.join("file:///", @fname).to_s
      r = @lsp.get_definition(fpuri, @lpos, @cpos)
      if !r.nil?
        jump_to_file(r[0], r[1])
      end
    end
  end

  def init_lsp()
    if conf(:enable_lsp) and !@lang.nil?
      @lsp = LangSrv.get(@lang.to_sym)
      if @lang == "php"
        # Ripl.start :binding => binding
      end
    end

    if !@lsp.nil?
      @lsp.open_file(@fname, self.to_s)
    end
  end

  def detect_file_language
    @lang = nil
    @lang = "c" if @fname.match(/\.(c|h|cpp)$/)
    @lang = "java" if @fname.match(/\.(java)$/)
    @lang = "ruby" if @fname.match(/\.(rb)$/)
    @lang = "hyperplaintext" if @fname.match(/\.(txt)$/)
    @lang = "php" if @fname.match(/\.(php)$/)
    @lsp = nil

    lm = GtkSource::LanguageManager.new

    lm.set_search_path(lm.search_path << ppath("lang/"))
    lang = lm.guess_language(@fname)
    # lang.get_metadata("line-comment-start")
    # lang.get_metadata("block-comment-start")
    # lang.get_metadata("block-comment-end")
    @lang_nfo = lang
    if !lang.nil? and !lang.id.nil?
      debug "Guessed LANG: #{lang.id}"
      @lang = lang.id
    end
    puts @lang.inspect

    if @lang
      gui_set_file_lang(@id, @lang)
    end
    return @lang
  end

  def view()
    # Get the VSourceView < GtkSource::View object corresponding to this buffer
    return vma.gui.buffers[@id]
  end

  # Replace char at pos with audio widget for
  def add_audio(afpath, pos)
    return if !is_legal_pos(pos)
    afpath = File.expand_path(afpath)
    return if !File.exist?(afpath)

    vbuf = view.buffer
    itr = vbuf.get_iter_at(:offset => pos)
    itr2 = vbuf.get_iter_at(:offset => pos + 1)
    vbuf.delete(itr, itr2)
    anchor = vbuf.create_child_anchor(itr)

    mf = Gtk::MediaFile.new(afpath)
    mc = Gtk::MediaControls.new(mf)
    # mc = Gtk::MediaControls.new(Gtk::MediaFile.new)
    # Thread.new{mf.play;sleep 0.01; mf.pause}
    @audiofiles << mc

    view.add_child_at_anchor(mc, anchor)
    mc.set_size_request(500, 20)
    mc.set_margin_start(view.gutter_width + 10)

    provider = Gtk::CssProvider.new
    mc.add_css_class("medctr")

    provider.load(data: ".medctr {   background-color:#353535; }")
    mc.style_context.add_provider(provider)

    pp mf.set_prepared(true)
    # pp mf.pause
    pp mf.duration
    pp mf.has_audio?

    # >> Gtk::MediaControls.signals
    # => ["direction-changed", "destroy", "show", "hide", "map", "unmap", "realize", "unrealize", "state-flags-changed", "mnemonic-activate", "move-focus", "keynav-failed", "query-tooltip", "notify"]

    # If this is done too early, the gutter is not yet drawn which
    # will result in wrong position
    if @audiofiles.size == 1
      run_as_idle proc { self.reset_audio_widget_positions }
    end
    $audiof = mf
  end

  def reset_audio_widget_positions
    debug "reset_audio_widget_positions", 2
    for mc in @audiofiles
      mc.set_size_request(500, 20)
      mc.set_margin_start(view.gutter_width + 10)
    end
    return false
  end

  def add_image(imgpath, pos)
    return if !is_legal_pos(pos)

    vbuf = view.buffer
    itr = vbuf.get_iter_at(:offset => pos)
    itr2 = vbuf.get_iter_at(:offset => pos + 1)
    vbuf.delete(itr, itr2)
    anchor = vbuf.create_child_anchor(itr)

    da = ResizableImage.new(imgpath, view)
    view.add_child_at_anchor(da, anchor)

    da.set_draw_func do |widget, cr|
      da.do_draw(widget, cr)
    end

    da.scale_image

    # vma.gui.handle_image_resize #TODO:gtk4
    @images << { :path => imgpath, :obj => da }

    gui_set_current_buffer(@id) #TODO: needed?
  end

  def is_legal_pos(pos, op = :read)
    return false if pos < 0
    if op == :add
      return false if pos > self.size
    elsif op == :read
      return false if pos >= self.size
    end
    return true
  end

  def set_encrypted(password)
    @crypt = Encrypt.new(password)
    message("Set buffer encrypted")
  end

  def set_unencrypted()
    @crypt = nil
  end

  def add_new_line(txt)
    # buf.jump(END_OF_LINE);buf.insert_txt("\n");
  end

  def insert_image_after_current_line(fname)
    lr = current_line_range()
    a = "⟦img:#{fname}⟧\n"
    b = " \n"
    txt = a + b
    insert_txt_at(txt, lr.end + 1)
    buf.view.handle_deltas
    imgpos = lr.end + 1 + a.size
    add_image(fname, imgpos)
  end

  def handle_drag_and_drop(fname)
    debug "[buffer] Dropped file: #{fname}"
    if is_image_file(fname)
      debug "Dropped image file"
      insert_image_after_current_line(fname)
    elsif vma.can_open_extension?(fname)
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

  def revert()
    return if !@fname
    return if !File.exists?(@fname)
    message("Revert buffer #{@fname}")
    str = read_file("", @fname)
    self.set_content(str)
  end

  def decrypt(password)
    begin
      @crypt = Encrypt.new(password)
      str = @crypt.decrypt(@encrypted_str)
    rescue OpenSSL::Cipher::CipherError => e
      str = "incorrect password"
    end
    self.set_content(str)
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
    if str[0..10] == "VMACRYPT001"
      @encrypted_str = str[11..-1]
      callback = proc { |x| decrypt_cur_buffer(x) }
      gui_one_input_action("Decrypt", "Password:", "decrypt", callback, { :hide => true })
      str = "ENCRYPTED"
    else
      # @crypt = nil
    end

    if (str[-1] != "\n")
      str << "\n"
    end

    self.replace(str)
    @line_ends = scan_indexes(self, /\n/)

    # @bt = BufferTree.new(str)
    if $experimental
      @bt = BufferTree.new(self)
      if $debug
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
    @need_redraw = 1
    @call_func = nil
    @deltas = []
    @edit_history = []
    @redo_stack = []
    @edit_pos_history = []
    @edit_pos_history_i = 0
    # @highlights = {}
    @highlights.delete_if { |x| true }

    @syntax_parser = nil

    @is_highlighted = false
    @update_highlight = true
    @update_hl_startpos = 0 #TODO
    @update_hl_endpos = self.size - 1

    gui_set_buffer_contents(@id, self.to_s)
    @images = [] #TODO: if reload
    hpt_scan_images(self)

    # add_hl_update(@update_hl_startpos, @update_hl_endpos)
  end

  def set_filename(filename)
    @fname = filename
    @pathname = Pathname.new(fname) if @fname
    @basename = @pathname.basename if @fname

    @title = File.basename(@fname)
    @dirname = File.dirname(@fname)
    userhome = File.expand_path("~")
    @subtitle = @dirname.gsub(/^#{userhome}/, "~")
    vma.buffers.last_dir = @dirname

    detect_file_language
  end

  def get_short_path()
    fpath = self.fname
    if fpath.size > 50
      fpath = fpath[-50..-1]
    end
    return fpath
  end

  def line(lpos)
    if @line_ends.size == 0
      return self
    end

    #TODO: implement using line_range()
    if lpos >= @line_ends.size
      debug("lpos too large") #TODO
      return ""
    elsif lpos == @line_ends.size
    end
    start = @line_ends[lpos - 1] + 1 if lpos > 0
    start = 0 if lpos == 0
    _end = @line_ends[lpos]
    debug "start: _#{start}, end: #{_end}"
    return self[start.._end]
  end

  def is_delta_ok(delta)
    ret = true
    pos = delta[0]
    if pos < 0
      ret = false
      debug "pos=#{pos} < 0"
    elsif pos > self.size
      debug "pos=#{pos} > self.size=#{self.size}"
      ret = false
    end
    if ret == false
      # crash("DELTA OK=#{ret}")
    end
    return ret
  end

  #TODO: change to apply=true as default
  def add_delta(delta, apply = false, auto_update_cpos = false)
    return if !is_delta_ok(delta)
    if delta[1] == DELETE
      return if delta[0] >= self.size
      # If go over length of buffer
      if delta[0] + delta[2] >= self.size
        delta[2] = self.size - delta[0]
      end
    end

    @edit_version += 1
    @redo_stack = []
    if apply
      delta = run_delta(delta, auto_update_cpos)
    else
      @deltas << delta
    end
    @edit_history << delta
    if self[-1] != "\n"
      add_delta([self.size, INSERT, 1, "\n"], true)
    end
    reset_larger_cpos #TODO: correct here?
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
    if $experimental
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
    if @edit_pos_history.any? and (@edit_pos_history.last - pos).abs <= 2
      @edit_pos_history.pop
    end

    lsp = get_line_start(pos)

    if @edit_pos_history[-1] != lsp
      @edit_pos_history << lsp
    end
    @edit_pos_history_i = 0

    if delta[1] == DELETE
      delta[3] = self.slice!(delta[0], delta[2])
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
    end
    debug("DELTA=#{delta.inspect}", 2)
    # sanity_check_line_ends #TODO: enable with debug mode
    #highlight_c()

    $update_highlight = true
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
  end

  def jump_to_last_edit()
    return if @edit_pos_history.empty?
    @edit_pos_history_i += 1

    if @edit_pos_history_i > @edit_pos_history.size
      @edit_pos_history_i = 0
    end

    #        if @edit_pos_history.size >= @edit_pos_history_i
    set_pos(@edit_pos_history[-@edit_pos_history_i])
    center_on_current_line
    return true
    #        end
  end

  def jump_to_next_edit()
    return if @edit_pos_history.empty?
    @edit_pos_history_i -= 1
    @edit_pos_history_i = @edit_pos_history.size - 1 if @edit_pos_history_i < 0
    debug "@edit_pos_history_i=#{@edit_pos_history_i}"
    set_pos(@edit_pos_history[-@edit_pos_history_i])
    center_on_current_line
    return true
  end

  def jump_to_random_pos()
    set_pos(rand(self.size))
  end

  def undo()
    debug @edit_history.inspect
    return if !@edit_history.any?
    last_delta = @edit_history.pop
    @redo_stack << last_delta
    debug last_delta.inspect
    if last_delta[1] == DELETE
      d = [last_delta[0], INSERT, 0, last_delta[3]]
      run_delta(d)
    elsif last_delta[1] == INSERT
      d = [last_delta[0], DELETE, last_delta[3].size]
      run_delta(d)
    else
      return #TODO: assert?
    end
    set_pos(last_delta[0])
    #recalc_line_ends #TODO: optimize?
    calculate_line_and_column_pos
  end

  def redo()
    return if !@redo_stack.any?
    #last_delta = @edit_history[-1].pop
    redo_delta = @redo_stack.pop
    #printf("==== UNDO ====\n")
    debug redo_delta.inspect
    run_delta(redo_delta)
    @edit_history << redo_delta
    set_pos(redo_delta[0])
    #recalc_line_ends #TODO: optimize?
    calculate_line_and_column_pos
  end

  def current_char()
    return self[@pos]
  end

  def current_line()
    range = line_range(@lpos, 1)
    return self[range]
  end

  def get_com_str()
    # return nil if @syntax_detect_failed

    com_str = nil
    # if get_file_type() == "c" or get_file_type() == "java"
    # com_str = "//"
    # elsif get_file_type() == "ruby"
    # com_str = "#"
    # else
    # com_str = "//"
    # end

    if !@lang_nfo.nil?
      com_str = @lang_nfo.get_metadata("line-comment-start")
    end

    # lang.get_metadata("block-comment-start")
    # lang.get_metadata("block-comment-end")

    com_str = "//" if com_str.nil?

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
    if a > 0
      a = a - 1
    else
      a = 0
    end
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
    return @line_ends.select { |x| x > pos }.min
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
    $method_handles_repeat = true
    repeat_num = 1
    if !$next_command_count.nil? and $next_command_count > 0
      repeat_num = $next_command_count
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

  def replace_range(range, text)
    delete_range(range.first, range.last)
    insert_txt_at(text, range.begin)
  end

  def current_line_range()
    range = line_range(@lpos, 1)
    return range
  end

  def line_range(start_line, num_lines, include_last_nl = true)
    end_line = start_line + num_lines - 1
    if end_line >= @line_ends.size
      debug("lpos too large") #TODO
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

  def copy(range_id)
    @paste_lines = false
    debug "range_id: #{range_id}"
    debug range_id.inspect
    range = get_range(range_id)
    debug range.inspect
    set_clipboard(self[range])
  end

  def recalc_line_ends()
    t1 = Time.now
    leo = @line_ends.clone
    @line_ends = scan_indexes(self, /\n/)
    if @line_ends == leo
      debug "No change to line ends"
    else
      debug "CHANGES to line ends"
    end

    debug "Scan line_end time: #{Time.now - t1}"
    #debug @line_ends
  end

  def sanity_check_line_ends()
    leo = @line_ends.clone
    @line_ends = scan_indexes(self, /\n/)
    if @line_ends == leo
      debug "No change to line ends"
    else
      debug "CHANGES to line ends"
      debug leo.inspect
      debug @line_ends.inspect
      crash("CHANGES to line ends")
    end
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
    return if !self.is_highlighted # $cnf[:syntax_highlight]
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

  def update_line_ends(pos, changeamount, changestr)
    if changeamount > -1
      changeamount = changestr.size
      i_nl = scan_indexes(changestr, /\n/)
      i_nl.collect! { |x| x + pos }
    end
    #    debug "change:#{changeamount}"
    #TODO: this is the bottle neck in insert_txt action
    @line_ends.collect! { |x|
      r = nil
      r = x if x < pos
      r = x + changeamount if changeamount < 0 && x + changeamount >= pos
      r = x + changeamount if changeamount > 0 && x >= pos
      r
    }.compact!

    if changeamount > -1 && i_nl.size > 0
      @line_ends.concat(i_nl)
      @line_ends.sort!
    end
  end

  def at_end_of_line?()
    return (self[@pos] == "\n" or at_end_of_buffer?)
  end

  def at_end_of_buffer?()
    return @pos == self.size
  end

  def jump_to_pos(new_pos)
    set_pos(new_pos)
  end

  def set_pos(new_pos)
    if new_pos >= self.size
      @pos = self.size - 1 # TODO:??right side of last char
    elsif new_pos >= 0
      @pos = new_pos
    end
    gui_set_cursor_pos(@id, @pos)
    calculate_line_and_column_pos

    check_if_modified_outside
  end

  # Get the line number of character position
  def get_line_pos(pos)
    lpos = @line_ends.bsearch_index { |x, _| x >= pos }
    return lpos
  end

  # Calculate the two dimensional column and line positions based on
  # (one dimensional) position in the buffer.
  def get_line_and_col_pos(pos)
    pos = self.size if pos > self.size
    pos = 0 if pos < 0

    lpos = get_line_pos(pos)

    lpos = @line_ends.size if lpos == nil
    cpos = pos
    cpos -= @line_ends[lpos - 1] + 1 if lpos > 0

    return [lpos, cpos]
  end

  def calculate_line_and_column_pos(reset = true)
    @lpos, @cpos = get_line_and_col_pos(@pos)
    reset_larger_cpos if reset
  end

  def set_line_and_column_pos(lpos, cpos, _reset_larger_cpos = true)
    @lpos = lpos if !lpos.nil?
    @cpos = cpos if !cpos.nil?
    if @lpos > 0
      new_pos = @line_ends[@lpos - 1] + 1
    else
      new_pos = 0
    end

    if @cpos > (line(@lpos).size - 1)
      debug("$cpos too large: #{@cpos} #{@lpos}")
      if @larger_cpos < @cpos
        @larger_cpos = @cpos
      end
      @cpos = line(@lpos).size - 1
    end
    new_pos += @cpos
    set_pos(new_pos)
    reset_larger_cpos if _reset_larger_cpos
  end

  # Calculate the one dimensional array index based on column and line positions
  def calculate_pos_from_cpos_lpos(reset = true)
    set_line_and_column_pos(nil, nil)
  end

  def delete2(range_id, mark = nil)
    # if mark != nil
    # debug mark, 2
    # return
    # end

    @paste_lines = false
    range = get_range(range_id, mark: mark)
    return if range == nil
    debug "RANGE"
    debug range.inspect
    debug range.inspect
    debug "------"
    delete_range(range.first, range.last)
    pos = [range.first, @pos].min
    set_pos(pos)
  end

  def delete(op, x = nil)
    @paste_lines = false
    # Delete selection
    if op == SELECTION && visual_mode?
      (startpos, endpos) = get_visual_mode_range2
      delete_range(startpos, endpos, x)
      @pos = [@pos, @selection_start].min
      end_visual_mode
      #return

      # Delete current char
    elsif op == CURRENT_CHAR_FORWARD
      return if @pos >= self.size - 1 # May not delete last '\n'
      add_delta([@pos, DELETE, 1], true)

      # Delete current char and then move backward
    elsif op == CURRENT_CHAR_BACKWARD
      add_delta([@pos, DELETE, 1], true)
      @pos -= 1

      # Delete the char before current char and move backward
    elsif op == BACKWARD_CHAR and @pos > 0
      add_delta([@pos - 1, DELETE, 1], true)
      @pos -= 1
    elsif op == FORWARD_CHAR #TODO: ok?
      add_delta([@pos + 1, DELETE, 1], true)
    end
    set_pos(@pos)
    #recalc_line_ends
    calculate_line_and_column_pos
    #need_redraw!
  end

  def delete_range(startpos, endpos, x = nil)
    s = self[startpos..endpos]
    if startpos == endpos or s == ""
      return
    end
    if x == :append
      debug "APPEND"
      s += "\n" + get_clipboard()
    end
    set_clipboard(s)
    add_delta([startpos, DELETE, (endpos - startpos + 1)], true)
    #recalc_line_ends
    calculate_line_and_column_pos
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
      open_existing_file(word)
    elsif wtype == :file
      open_with_default_program(word)
    elsif wtype == :hpt_link
      open_existing_file(word)
    elsif wtype == :help
      if word == "keybindings"
        call_action(:show_key_bindings)
      end
    else
      #TODO
    end
  end

  def context_menu_items()
    m = []
    if @visual_mode
      seltxt = get_current_selection
      m << ["Copy", self.method("copy_active_selection"), nil]
      m << ["Join lines", self.method("convert_selected_text"), :joinlines]
      # m << ["Sort", self.method("convert_selected_text"), :sortlines]
      m << ["Sort", method("call"), :sortlines]
      m << ["Filter: get numbers", method("call"), :getnums_on_lines]
      m << ["Delete selection", method("call"), :delete_selection]

      # m << ["Search in dictionary", self.method("handle_word"), nil]
      # m << ["Search in google", self.method("handle_word"), nil]
      m << ["Execute in terminal", method("exec_in_terminal"), seltxt]
    else
      (word, wtype) = get_cur_nonwhitespace_word()
      if wtype == :url
        m << ["Open url", self.method("open_url"), word]
      elsif wtype == :linepointer
        m << ["Jump to line", self.method("handle_word"), [word, wtype]]
      elsif wtype == :textfile
        m << ["Open text file", self.method("handle_word"), [word, wtype]]
      elsif wtype == :file
        m << ["Open file (xdg-open)", self.method("handle_word"), [word, wtype]]
      elsif wtype == :hpt_link
        m << ["Jump to file", self.method("handle_word"), [word, wtype]]
      else
        # m << ["TODO", self.method("handle_word"), word]
        m << ["Paste", method("call"), :paste_after]
      end
    end
    return m
  end

  # Activated when enter/return pressed
  def handle_line_action()
    if line_action_handler.class == Proc
      # Custom handler
      line_action_handler.call(lpos)
    else
      # Generic default action
      cur_nonwhitespace_word_action()
    end
  end

  def get_cur_nonwhitespace_word()
    wem = scan_marks(@pos, @pos + 200, /(?<=\S)\s/, -1)
    wsm = scan_marks(@pos - 200, @pos, /((?<=\s)\S)|^\S/)

    word_start = wsm[-1]
    word_end = wem[0]
    word_start = pos if word_start == nil
    word_end = pos if word_end == nil
    word = self[word_start..word_end]
    debug "'WORD: #{word}'"
    # message("Open link #{word}")
    linep = get_file_line_pointer(word)
    debug "linep'#{linep}'"
    path = File.expand_path(word)
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
      # elsif hpt_check_cur_word(word) #TODO: check only
      # debug word
    elsif linep != nil
      wtype = :linepointer
      word = linep
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

  def cur_nonwhitespace_word_action()

    # (word, wtype) = get_cur_nonwhitespace_word()
    wnfo = get_cur_nonwhitespace_word()
    handle_word(wnfo)
  end

  def jump_to_next_instance_of_word()
    if $kbd.last_action == $kbd.cur_action and @current_word != nil
      # debug "REPEATING *"
    else
      start_search = [@pos - 150, 0].max

      search_str1 = self[start_search..(@pos)]
      wsmarks = scan_indexes(search_str1, /(?<=[^\p{Word}])\p{Word}/)
      a = wsmarks[-1]
      a = 0 if a == nil

      search_str2 = self[(@pos)..(@pos + 150)]
      wemarks = scan_indexes(search_str2, /(?<=\p{Word})[^\p{Word}]/)
      b = wemarks[0]
      word_start = (@pos - search_str1.size + a + 1)
      word_start = 0 if !(word_start >= 0)
      @current_word = self[word_start..(@pos + b - 1)]
    end

    #TODO: search for /[^\p{Word}]WORD[^\p{Word}]/
    position_of_next_word = self.index(@current_word, @pos + 1)
    if position_of_next_word != nil
      set_pos(position_of_next_word)
    else #Search from beginning
      position_of_next_word = self.index(@current_word)
      set_pos(position_of_next_word) if position_of_next_word != nil
    end
    center_on_current_line
    return true
  end

  def jump_word(direction, wordpos)
    offset = 0
    if direction == FORWARD
      debug "POS: #{@pos},"
      search_str = self[(@pos)..(@pos + 250)]
      return if search_str == nil
      if wordpos == WORD_START # vim 'w'
        wsmarks = scan_indexes(search_str, /(?<=[^\p{Word}])\p{Word}|\Z/) # \Z = end of string, just before last newline.
        wsmarks2 = scan_indexes(search_str, /\n[ \t]*\n/) # "empty" lines that have whitespace
        wsmarks2 = wsmarks2.collect { |x| x + 1 }
        wsmarks = (wsmarks2 + wsmarks).sort.uniq
        offset = 0
        if wsmarks.any?
          next_pos = @pos + wsmarks[0] + offset
          set_pos(next_pos)
        end
      elsif wordpos == WORD_END
        search_str = self[(@pos + 1)..(@pos + 150)]
        wsmarks = scan_indexes(search_str, /(?<=\p{Word})[^\p{Word}]/)
        offset = -1
        if wsmarks.any?
          next_pos = @pos + 1 + wsmarks[0] + offset
          set_pos(next_pos)
        end
      end
    end
    if direction == BACKWARD #  vim 'b'
      start_search = @pos - 150 #TODO 150 length limit
      start_search = 0 if start_search < 0
      search_str = self[start_search..(@pos - 1)]
      return if search_str == nil
      wsmarks = scan_indexes(search_str,
                             #/(^|(\W)\w|\n)/) #TODO 150 length limit
                             #/^|(?<=[^\p{Word}])\p{Word}|(?<=\n)\n/) #include empty lines?
                             /\A|(?<=[^\p{Word}])\p{Word}/) # Start of string or nonword,word.

      offset = 0

      if wsmarks.any?
        next_pos = start_search + wsmarks.last + offset
        set_pos(next_pos)
      end
    end
  end

  def jump_to_mark(mark_char)
    p = @marks[mark_char]
    set_pos(p) if p
    center_on_current_line
    return true
  end

  def jump(target)
    if target == START_OF_BUFFER
      set_pos(0)
    end
    if target == END_OF_BUFFER
      set_pos(self.size - 1)
    end
    if target == BEGINNING_OF_LINE
      @cpos = 0
      calculate_pos_from_cpos_lpos
    end
    if target == END_OF_LINE
      @cpos = line(@lpos).size - 1
      calculate_pos_from_cpos_lpos
    end

    if target == FIRST_NON_WHITESPACE
      l = current_line()
      debug l.inspect
      @cpos = line(@lpos).size - 1
      a = scan_indexes(l, /\S/)
      debug a.inspect
      if a.any?
        @cpos = a[0]
      else
        @cpos = 0
      end
      calculate_pos_from_cpos_lpos
    end
  end

  def jump_to_line(line_n = 1)

    #    $method_handles_repeat = true
    #    if !$next_command_count.nil? and $next_command_count > 0
    #        line_n = $next_command_count
    #        debug "jump to line:#{line_n}"
    #    end
    debug "jump to line:#{line_n}"
    line_n = get_repeat_num() if line_n == 1

    if line_n > @line_ends.size
      debug("lpos too large") #TODO
      return
    end
    if line_n == 1
      set_pos(0)
    else
      set_pos(@line_ends[line_n - 2] + 1)
    end
  end

  def join_lines()
    if @lpos >= @line_ends.size - 1 # Cursor is on last line
      debug("ON LAST LINE")
      return
    else
      # TODO: replace all whitespace between lines with ' '
      jump(END_OF_LINE)
      delete(CURRENT_CHAR_FORWARD)
      #insert_txt(' ',AFTER)
      insert_txt(" ", BEFORE)
    end
  end

  def jump_to_next_instance_of_char(char, direction = FORWARD)

    #return if at_end_of_line?
    if direction == FORWARD
      position_of_next_char = self.index(char, @pos + 1)
      if position_of_next_char != nil
        @pos = position_of_next_char
      end
    elsif direction == BACKWARD
      start_search = @pos - 250
      start_search = 0 if start_search < 0
      search_substr = self[start_search..(@pos - 1)]
      _pos = search_substr.reverse.index(char)
      if _pos != nil
        @pos -= (_pos + 1)
      end
    end
    m = method("jump_to_next_instance_of_char")
    set_last_command({ method: m, params: [char, direction] })
    $last_find_command = { char: char, direction: direction }
    set_pos(@pos)
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
    if $cnf[:indent_based_on_last_line] and c == "\n" and @lpos > 0
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
    #recalc_line_ends #TODO: optimize?
    calculate_line_and_column_pos
    #need_redraw!
    #@pos += c.size
    # end_profiler
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

  def need_redraw!
    @need_redraw = true
  end

  def need_redraw?
    return @need_redraw
  end

  def set_redrawed
    @need_redraw = false
  end

  # Create a new line after current line and insert text on that line
  def put_to_new_next_line(txt)
    l = current_line_range()
    insert_txt_at(txt, l.end + 1)
    set_pos(l.end + 1)
  end

  # Start asynchronous read of system clipboard
  def paste_start(at, register)
    @clipboard_paste_running = true
    clipboard = vma.gui.window.display.clipboard
    clipboard.read_text_async do |_clipboard, result|
      begin
        text = clipboard.read_text_finish(result)
      rescue Gio::IOError::NotSupported
        # Happens when pasting from KeePassX and clipboard cleared
        debug Gio::IOError::NotSupported
      else
        paste_finish(text, at, register)
      end
    end
  end

  def paste_finish(text, at, register)
    debug "PASTE: #{text}"

    # If we did not put this text to clipboard
    if text != $clipboard[-1]
      @paste_lines = false
    end

    text = sanitize_input(text)

    $clipboard << text

    return if text == ""

    if @paste_lines
      debug "PASTE LINES"
      put_to_new_next_line(text)
    else
      if at_end_of_buffer? or at_end_of_line? or at == BEFORE
        pos = @pos
      else
        pos = @pos + 1
      end
      insert_txt_at(text, pos)
      set_pos(pos + text.size)
    end
    set_pos(@pos)
    @clipboard_paste_running = false
  end

  def paste(at = AFTER, register = nil)
    # Macro's don't work with asynchronous call using GTK
    # TODO: implement as synchronous?
    # Use internal clipboard
    if vma.macro.running_macro
      text = get_clipboard()
      paste_finish(text, at, register)
    else
      # Get clipboard using GUI
      paste_start(at, register)
    end
    return true
  end

  def delete_line()
    $method_handles_repeat = true
    num_lines = 1
    if !$next_command_count.nil? and $next_command_count > 0
      num_lines = $next_command_count
      debug "copy num_lines:#{num_lines}"
    end
    lrange = line_range(@lpos, num_lines)
    s = self[lrange]
    add_delta([lrange.begin, DELETE, lrange.end - lrange.begin + 1], true)
    set_clipboard(s)
    update_pos(lrange.begin)
    @paste_lines = true
    #recalc_line_ends
  end

  def update_pos(pos)
    @pos = pos
    calculate_line_and_column_pos
  end

  def start_visual_mode()
    @visual_mode = true
    @selection_start = @pos
    $kbd.set_mode(:visual)
  end

  def copy_active_selection(x = nil)
    debug "!COPY SELECTION"
    @paste_lines = false
    return if !@visual_mode

    debug "COPY SELECTION"
    s = self[get_visual_mode_range]
    if x == :append
      debug "APPEND"
      s += "\n" + get_clipboard()
    end

    set_clipboard(s)
    end_visual_mode
    return true
  end

  def transform_selection(op)
    return if !@visual_mode
    r = get_visual_mode_range
    txt = self[r]
    txt.upcase! if op == :upcase
    txt.downcase! if op == :downcase
    txt.gsub!(/\w+/, &:capitalize) if op == :capitalize
    txt.swapcase! if op == :swapcase
    txt.reverse! if op == :reverse

    replace_range(r, txt)
    end_visual_mode
  end

  def convert_selected_text(converter_id)
    return if !@visual_mode
    r = get_visual_mode_range
    txt = self[r]
    txt = $vma.apply_conv(converter_id, txt)
    #TODO: Detect if changed?
    replace_range(r, txt)
    end_visual_mode
  end

  def style_transform(op)
    return if !@visual_mode
    r = get_visual_mode_range
    #TODO: if txt[-1]=="\n"
    txt = self[r]
    txt = "⦁" + txt + "⦁" if op == :bold
    txt = "⟦" + txt + "⟧" if op == :link
    txt = "❙" + txt + "❙" if op == :title
    txt.gsub!(/[❙◼⟦⟧⦁]/, "") if op == :clear

    replace_range(r, txt)
    end_visual_mode
  end

  def set_line_style(op)
    lrange = line_range(@lpos, 1, false)
    txt = self[lrange]
    # txt = "◼ " + txt if op == :heading
    txt = "⦁" + txt + "⦁" if op == :bold
    txt = "❙" + txt + "❙" if op == :title
    txt.gsub!(/◼ /, "") if op == :clear
    txt.gsub!(/[❙◼⟦⟧⦁]/, "") if op == :clear or [:h1, :h2, :h3, :h4].include?(op)

    if [:h1, :h2, :h3, :h4].include?(op)
      txt.strip!
      txt = "◼ " + txt if op == :h1
      txt = "◼◼ " + txt if op == :h2
      txt = "◼◼◼ " + txt if op == :h3
      txt = "◼◼◼◼ " + txt if op == :h4
    end
    replace_range(lrange, txt)
  end

  def copy_line()
    $method_handles_repeat = true
    num_lines = 1
    if !$next_command_count.nil? and $next_command_count > 0
      num_lines = $next_command_count
      debug "copy num_lines:#{num_lines}"
    end
    set_clipboard(self[line_range(@lpos, num_lines)])
    @paste_lines = true
  end

  def put_file_path_to_clipboard
    set_clipboard(self.fname)
  end

  def put_file_ref_to_clipboard
    set_clipboard(self.fname + ":#{@lpos}")
  end

  def delete_active_selection() #TODO: remove this function
    return if !@visual_mode #TODO: this should not happen

    _start, _end = get_visual_mode_range
    set_clipboard(self[_start, _end])
    end_visual_mode
  end

  def end_visual_mode()
    return if !visual_mode?
    debug "End visual mode"
    #TODO:take previous mode (insert|command) from stack?
    $kbd.set_mode(:command)
    @visual_mode = false
    return true
  end

  def get_visual_mode_range2()
    r = get_visual_mode_range
    if r.begin > r.end
      debug "r.begin > r.end"
      Ripl.start :binding => binding
    end
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
    _start = @selection_start
    _end = @pos

    _start, _end = _end, _start if _start > _end
    # _end = _end + 1 if _start < _end #TODO:verify if correct
    # return _start..(_end - 1)
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
    # Else search for previously open files and save to the directory of
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

  def save_as_check_callback(vals)
    if vals["yes_btn"] == "submit"
      save_as_callback(@unconfirmed_path, true)
    end
  end

  def save_as_callback(fpath, confirmed = false)
    # The check if file exists is handled by Gtk::FileChooserDialog in GTK4
    # Keeping this code from GTK3 in case want to do this manually at some point
    # if !confirmed
    # @unconfirmed_path = fpath
    # if File.exists?(fpath) and File.file?(fpath)
    # params = {}
    # params["title"] = "The file already exists, overwrite? \r #{fpath}"
    # params["inputs"] = {}
    # params["inputs"]["yes_btn"] = { :label => "Yes", :type => :button, :default_focus => true }
    # callback = proc { |x| save_as_check_callback(x) }
    # params[:callback] = callback
    # PopupFormGenerator.new(params).run
    # return
    # elsif File.exists?(fpath) #and File.directory?(fpath)
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
    gui_set_window_title(@title, @subtitle) #TODO: if not active buffer?
  end

  def write_contents_to_file(fpath)
    if @crypt != nil
      mode = "wb+"
      contents = "VMACRYPT001" + @crypt.encrypt(self.to_s)
    else
      mode = "w+"
      contents = self.to_s
    end

    Thread.new {
      begin
        io = File.open(fpath, mode)
        io.set_encoding(self.encoding)
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
        message("File #{fpath} not writeable")
        #TODO: show message box
      end
      @last_save = Time.now
      puts "file saved on #{@last_save}"
      sleep 3
    }
  end

  def check_if_modified_outside_callback(x)
    debug "check_if_modified_outside_callback"
    if x["yes_btn"] == "submit"
      revert()
    end
  end

  def check_if_modified_outside
    # Don't check if less than 8 seconds since last checked
    return false if @fname.nil?
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

  def save()
    check_if_modified_outside
    if !@fname
      save_as()
      return
    end
    message("Saving file #{@fname}")
    write_contents_to_file(@fname)
  end

  # Indents whole buffer using external program
  def indent()
    file = Tempfile.new("out")
    infile = Tempfile.new("in")
    file.write(self.to_s)
    file.flush
    bufc = "FOO"

    tmppos = @pos

    message("Auto format #{@fname}")

    ftype = get_file_type()
    if ["chdr", "c", "cpp", "cpphdr"].include?(ftype)

      #C/C++/Java/JavaScript/Objective-C/Protobuf code
      system("clang-format -style='{BasedOnStyle: LLVM, ColumnLimit: 100,  SortIncludes: false}' #{file.path} > #{infile.path}")
      bufc = IO.read(infile.path)
    elsif ftype == "Javascript"
      cmd = "clang-format #{file.path} > #{infile.path}'"
      debug cmd
      system(cmd)
      bufc = IO.read(infile.path)
    elsif ftype == "ruby"
      cmd = "rufo #{file.path}"
      debug cmd
      system(cmd)
      bufc = IO.read(file.path)
    else
      message("No auto-format handler for file of type: #{ftype}")
      return
    end
    self.update_content(bufc)
    center_on_current_line #TODO: needed?
    file.close; file.unlink
    infile.close; infile.unlink
  end

  def close()
    idx = vma.buffers.get_buffer_by_id(@id)
    vma.buffers.close_buffer(idx)
  end

  def backup()
    fname = @fname
    return if !@fname
    spfx = fname.gsub("=", "==").gsub("/", "=:")
    spath = File.expand_path("~/.vimamsa/backup")
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

#TODO: function not used
def write_to_file(savepath, s)
  if is_path_writable(savepath)
    IO.write(savepath, self.to_s)
  else
    message("PATH NOT WRITABLE: #{savepath}")
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
