
module Vimamsa

# Word-based completion candidates collected from open buffers.
# Words are stored per buffer (buffer id => {word => count}) so that a
# re-scan on save replaces that buffer's words and stale words drop out.
class Autocomplete
  @@buf_words = {}    # buffer id => { word => count }
  @@scan_version = {} # buffer id => edit_version at last scan

  MAX_WORD_LENGTH = 100
  MAX_SCAN_SIZE = 500_000 # don't rescan larger buffers on the fly

  def self.init
    vma.hook.register(:file_saved, self.method("update_index"))
  end

  def self.update_index(bu)
    debug "Autocomplete.update_index", 2
    scan_buffer(bu)
  end

  # Called from Buffer#set_content with the initial word list
  def self.add_words(words, buf_id = nil)
    counts = Hash.new(0)
    for w in words
      counts[w] += 1 if w.size < MAX_WORD_LENGTH
    end
    @@buf_words[buf_id || :global] = counts
  end

  def self.scan_buffer(bu)
    counts = Hash.new(0)
    bu.scan(/\b\w+\b/) { |w| counts[w] += 1 if w.size < MAX_WORD_LENGTH }
    @@buf_words[bu.id] = counts
    @@scan_version[bu.id] = bu.edit_version
  end

  # Re-scan the buffer being edited if it has changed since the last scan,
  # so the popup also offers words typed since the last save.
  def self.refresh_current(bu)
    return if bu.nil? or bu.size >= MAX_SCAN_SIZE
    return if @@scan_version[bu.id] == bu.edit_version
    scan_buffer(bu)
  end

  def self.remove_buffer(buf_id)
    @@buf_words.delete(buf_id)
    @@scan_version.delete(buf_id)
  end

  # Match quality tiers: case-sensitive prefix > case-insensitive prefix >
  # substring > in-order subsequence. nil = no match.
  def self.match_tier(word, prefix, prefix_down)
    return 3 if word.start_with?(prefix)
    wd = word.downcase
    return 2 if wd.start_with?(prefix_down)
    return 1 if wd.include?(prefix_down)
    return 0 if subsequence?(prefix_down, wd)
    return nil
  end

  def self.subsequence?(needle, haystack)
    i = -1
    needle.each_char do |ch|
      i = haystack.index(ch, i + 1)
      return false if i.nil?
    end
    return true
  end

  # Ranked completion candidates for prefix, best match first.
  def self.matching_words(prefix, max: nil)
    return [] if prefix.nil? or prefix.empty?
    max ||= cnf.autocomplete.max_items! || 50
    pd = prefix.downcase
    freq = Hash.new(0)
    @@buf_words.each_value { |h| h.each { |w, c| freq[w] += c } }
    scored = []
    freq.each do |w, c|
      next if w == prefix
      tier = match_tier(w, prefix, pd)
      next if tier.nil?
      scored << [-tier, -[c, 99].min, w.size, w]
    end
    scored.sort!
    return scored[0...max].map { |x| x[3] }
  end

  # Filter LSP completion items ({text:, ...}) against the currently typed
  # prefix, keeping the server's order within each match tier.
  def self.filter_lsp_items(items, prefix)
    return [] if items.nil? or items.empty?
    return items.dup if prefix.nil? or prefix.empty?
    pd = prefix.downcase
    scored = []
    items.each_with_index do |it, i|
      tier = match_tier(it[:text], prefix, pd)
      next if tier.nil?
      scored << [[-tier, i], it]
    end
    scored.sort_by! { |x| x[0] }
    return scored.map { |x| x[1] }
  end
end

class VSourceView < GtkSource::View
  AUTOCP_ROW_HEIGHT = 26

  def autocp_init
    @autocp_active = false
    @autocp_items = []
    @autocp_selected = 0
    @autocp_prefix = nil
    @autocp_word_start = nil
    @autocp_cursor_pos = nil
    @autocp_gen = 0
    @autocp_lsp_items = []
    @autocp_idle_pending = false
    @autocp_manual = false
    @acwin = nil
    @ac_list = nil
    @ac_sw = nil
  end

  # Texts of the current candidate list (used by tests)
  def autocp_texts
    @autocp_items.map { |x| x[:text] }
  end

  def hide_completions
    @acwin.popdown if @acwin and @acwin.visible?
    @autocp_active = false
    @autocp_manual = false
    @autocp_items = []
    @autocp_lsp_items = []
    @autocp_prefix = nil
    @autocp_word_start = nil
    @autocp_cursor_pos = nil
    @autocp_gen += 1 # invalidate pending LSP callbacks
  end

  def autocp_select
    return if !@autocp_active
    item = @autocp_items[@autocp_selected]
    hide_completions
    # dup: word-hash keys are frozen, insert_txt_at calls force_encoding
    bufo.complete_current_word(item[:text].dup) if item
    grab_focus
  end

  def autocp_select_next
    return if !@autocp_active
    autocp_set_selected(@autocp_selected + 1) if @autocp_selected < @autocp_items.size - 1
  end

  def autocp_select_previous
    return if !@autocp_active
    autocp_set_selected(@autocp_selected - 1) if @autocp_selected > 0
  end

  def autocp_manual_trigger
    return unless cnf.autocomplete.enabled?
    @autocp_manual = true
    autocp_refresh(request_lsp: true)
  end

  # Called from Buffer#insert_txt while in insert mode (covers both the key
  # binding path and the Wayland IM insert-text path).
  def autocp_on_insert(c)
    return unless cnf.autocomplete.enabled?
    if c.nil? or c.empty? or c[-1] !~ /\w/
      hide_completions if @autocp_active
      return
    end
    if @autocp_active or cnf.autocomplete.auto_trigger? != false
      autocp_schedule_refresh
    end
  end

  # Called from Buffer#delete while in insert mode (backspace etc.)
  def autocp_on_delete
    autocp_schedule_refresh if @autocp_active
  end

  # Called from Buffer#set_pos: dismiss if the cursor moved anywhere we
  # don't expect (mouse click, arrows, jumps). One backspace between
  # refreshes is tolerated; delete() calls set_pos before autocp_on_delete.
  def autocp_check_pos(new_pos)
    return if !@autocp_active or @autocp_cursor_pos.nil?
    if new_pos != @autocp_cursor_pos and new_pos != @autocp_cursor_pos - 1
      hide_completions
    end
  end

  # Coalesce refreshes into one idle callback per batch of edits. Running as
  # idle also guarantees handle_deltas has synced the GTK buffer before we
  # compute popup coordinates.
  def autocp_schedule_refresh
    return if @autocp_idle_pending
    @autocp_idle_pending = true
    GLib::Idle.add do
      @autocp_idle_pending = false
      autocp_refresh
      false
    end
  end

  def autocp_refresh(request_lsp: false)
    bu = @bufo
    return if bu.nil?
    p = bu.pos - 1
    if !bu.is_legal_pos(p) or bu[p] !~ /\w/
      hide_completions if @autocp_active
      return
    end
    (prefix, range) = bu.get_word_in_pos(p, boundary: :word)
    min_chars = cnf.autocomplete.min_chars! || 2
    if prefix.nil? or prefix !~ /\A\w+\z/ or (!@autocp_manual and prefix.size < min_chars)
      hide_completions if @autocp_active
      return
    end

    if range.begin != @autocp_word_start
      # Word start changed: LSP results for the old word are stale
      @autocp_lsp_items = []
      @autocp_gen += 1
      request_lsp = true if @autocp_active or cnf.autocomplete.auto_trigger? != false
    end
    @autocp_word_start = range.begin
    @autocp_prefix = prefix
    @autocp_cursor_pos = bu.pos

    autocp_request_lsp if request_lsp
    Autocomplete.refresh_current(bu)
    autocp_render
  end

  # Merge LSP items (server order within match tiers) with buffer words,
  # dedupe by completion text, and show the popup.
  def autocp_render
    prefix = @autocp_prefix
    return if prefix.nil?
    max = cnf.autocomplete.max_items! || 50
    items = []
    seen = {}
    Autocomplete.filter_lsp_items(@autocp_lsp_items, prefix).each do |it|
      next if seen[it[:text]] or it[:text] == prefix
      seen[it[:text]] = true
      items << it
    end
    Autocomplete.matching_words(prefix, max: max).each do |w|
      next if seen[w]
      seen[w] = true
      items << { text: w, kind: nil, detail: nil, source: :buffer }
    end
    items = items[0...max]
    if items.empty?
      hide_completions if @autocp_active
      return
    end
    @autocp_active = true
    @autocp_items = items
    autocp_update_list(items)
    (x, y) = pos_to_coord(@autocp_word_start)
    @acwin.set_pointing_to(Gdk::Rectangle.new(x, y + 8, 10, 10))
    @acwin.popup if !@acwin.visible?
    autocp_set_selected(0)
    grab_focus
  end

  # Request completions from the LSP server (async; the callback is
  # marshaled to the GTK thread by LangSrv). Debounced per word start.
  def autocp_request_lsp
    return if cnf.autocomplete.lsp.enabled? == false
    bu = @bufo
    lsp = bu.lsp
    return if lsp.nil? or !lsp.completion_supported or bu.fname.nil?
    gen = @autocp_gen
    debounce = ((cnf.autocomplete.lsp.debounce! || 0.15) * 1000).to_i
    debounce = 1 if @autocp_manual
    GLib::Timeout.add(debounce) do
      if gen == @autocp_gen
        lsp.request_completion(bu.fname, bu.lpos, bu.cpos) do |items|
          # Discard if the word or popup state changed while waiting
          if gen == @autocp_gen and !items.empty?
            @autocp_lsp_items = items
            autocp_render
          end
        end
      end
      false
    end
  end

  private

  def autocp_ensure_win
    return @acwin if @acwin
    win = Gtk::Popover.new
    win.parent = self
    win.has_arrow = false
    win.autohide = false
    win.focusable = false
    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:never, :automatic)
    sw.propagate_natural_height = true
    sw.propagate_natural_width = true
    sw.max_content_height = (cnf.autocomplete.visible_items! || 10) * AUTOCP_ROW_HEIGHT
    list = Gtk::ListBox.new
    list.selection_mode = :browse
    list.focusable = false
    list.signal_connect("row-activated") do |_l, row|
      @autocp_selected = row.index
      autocp_select
    end
    sw.child = list
    win.set_child(sw)
    gui_remove_controllers(win) # don't let the popover steal key events
    @acwin = win
    @ac_sw = sw
    @ac_list = list
    return win
  end

  def autocp_update_list(items)
    autocp_ensure_win
    while (row = @ac_list.first_child)
      @ac_list.remove(row)
    end
    show_kind = items.any? { |x| x[:kind] }
    for it in items
      hbox = Gtk::Box.new(:horizontal, 8)
      if show_kind
        kl = Gtk::Label.new(it[:kind].to_s)
        kl.width_chars = 5
        kl.xalign = 0
        kl.add_css_class("dim-label")
        hbox.append(kl)
      end
      tl = Gtk::Label.new(it[:text])
      tl.xalign = 0
      hbox.append(tl)
      if it[:detail] and !it[:detail].empty?
        dl = Gtk::Label.new(it[:detail])
        dl.xalign = 0
        dl.ellipsize = :end
        dl.max_width_chars = 40
        dl.add_css_class("dim-label")
        hbox.append(dl)
      end
      @ac_list.append(hbox)
    end
  end

  def autocp_set_selected(i)
    @autocp_selected = i
    row = @ac_list.get_row_at_index(i)
    return if row.nil?
    @ac_list.select_row(row)
    # Keep the selection visible; allocation is valid only once mapped
    GLib::Idle.add do
      r = @ac_list.get_row_at_index(@autocp_selected)
      if r and @ac_sw
        a = r.allocation
        @ac_sw.vadjustment.clamp_page(a.y, a.y + a.height)
      end
      false
    end
  end
end
end # module Vimamsa
