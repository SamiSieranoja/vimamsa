
module Vimamsa
class FileTreePanel
  COL_LABEL = 0
  COL_BUF_ID = 1  # 0 = folder row (not selectable)

  def initialize
    @store = Gtk::TreeStore.new(String, Integer)
    @tree, @sw = build_list_tree(@store, ellipsize: Pango::EllipsizeMode::START,
                                 text_col: COL_LABEL) do |iter|
      buf_id = iter[COL_BUF_ID]
      next if buf_id.nil? || buf_id == 0
      vma.buffers.set_current_buffer(buf_id)
    end
    @tree.level_indentation = 7

    @context_menu = nil
    rightclick = Gtk::GestureClick.new
    rightclick.button = 3
    @tree.add_controller(rightclick)
    rightclick.signal_connect("pressed") do |gesture, n_press, x, y|
      result = @tree.get_path_at_pos(x.to_i, y.to_i)
      next unless result
      iter = @store.get_iter(result[0])
      next unless iter
      buf_id = iter[COL_BUF_ID]
      next unless buf_id && buf_id != 0
      @context_buf_id = buf_id
      show_context_menu(x, y)
    end

    @sw.set_size_request(180, -1)
    @sw.vexpand = true
    @sw.add_css_class("side-panel")
  end

  def widget
    @sw
  end

  def init_context_menu
    act = Gio::SimpleAction.new("fp_close_buffer")
    vma.gui.app.add_action(act)
    act.signal_connect("activate") { vma.buffers.close_buffer(@context_buf_id) if @context_buf_id }
    @context_menu = Gtk::PopoverMenu.new
    @context_menu.set_parent(@tree)
    @context_menu.has_arrow = false
  end

  def show_context_menu(x, y)
    init_context_menu if @context_menu.nil?
    menu = Gio::Menu.new
    menu.append("Close file", "app.fp_close_buffer")
    @context_menu.set_menu_model(menu)
    @context_menu.set_pointing_to(Gdk::Rectangle.new(x.to_i, y.to_i, 1, 1))
    @context_menu.popup
  end

  # Buffers grouped by directory in the panel's display order:
  # [[dirname, [{bname:, buf:}, ...]], ...], dirs and files sorted by name.
  def grouped_buffers
    bh = {}
    vma.buffers.list.each do |b|
      dname = b.fname ? File.dirname(b.fname) : "*"
      bname = b.fname ? File.basename(b.fname) : (b.list_str || "(untitled)")
      bh[dname] ||= []
      bh[dname] << { bname: bname, buf: b }
    end
    bh.keys.sort.map { |dname| [dname, bh[dname].sort_by { |x| x[:bname] }] }
  end

  # Switch to the file `delta` rows away (±1) from the current buffer in the
  # panel's display order, wrapping at the ends.
  def select_adjacent(delta)
    ids = grouped_buffers.flat_map { |_, files| files.map { |x| x[:buf].id } }
    return if ids.empty?
    i = ids.index(vma.buf&.id)
    target = i.nil? ? ids.first : ids[(i + delta) % ids.size]
    vma.buffers.set_current_buffer(target)
  end

  # ── Easy jump: label file rows, switch to the file whose label is typed ──
  # Same mechanism as EasyJump (easy_jump.rb): a whole-keyboard override
  # captures label input; labels are rendered by prefixing the row text.

  EJ_CHARS = "ASDFJKLGHQWERUIOPTYZXCVBNM".split("")

  def easy_jump_active?
    !@ej_targets.nil?
  end

  # Single-char labels while they suffice, else all 2-char pairs — never mixed
  # lengths, so no label is a prefix of another.
  def ej_labels(n)
    return EJ_CHARS.first(n) if n <= EJ_CHARS.size
    EJ_CHARS.product(EJ_CHARS).map(&:join).first(n)
  end

  def easy_jump_start
    easy_jump_cancel if easy_jump_active?
    file_rows = grouped_buffers.flat_map { |_, files| files }
    return if file_rows.empty?

    labels = ej_labels(file_rows.size)
    @ej_targets = {}
    file_rows.each_with_index { |bnfo, i| @ej_targets[labels[i]] = bnfo[:buf].id }
    @ej_input = ""

    # Prefix each file row's label in the store; row order matches
    # grouped_buffers (refresh builds the store from it).
    i = 0
    @store.each do |_model, _path, iter|
      next if iter[COL_BUF_ID] == 0
      iter[COL_LABEL] = "#{labels[i]}  #{iter[COL_LABEL]}"
      i += 1
    end

    vma.kbd.set_keyhandling_override(self.method(:easy_jump_input_char))
  end

  def easy_jump_input_char(c, event_type)
    return true if event_type != :key_press
    # esc or any non-plain key (ctrl-x, alt-x, ...) aborts
    if c.size != 1
      easy_jump_cancel
      return true
    end

    @ej_input << c.upcase
    id = @ej_targets[@ej_input]
    if id
      target = id
      easy_jump_cancel        # remove override before switching; switch refreshes
      vma.buffers.set_current_buffer(target)
    elsif @ej_targets.keys.none? { |l| l.start_with?(@ej_input) }
      easy_jump_cancel
    end
    return true
  end

  def easy_jump_cancel
    vma.kbd.remove_keyhandling_override
    @ej_targets = nil
    refresh                    # rebuild rows without label prefixes
  end

  def refresh
    # A buffer-list change mid-pick must not leave a stale override installed
    # or labels pointing at rows that no longer exist.
    if easy_jump_active?
      vma.kbd.remove_keyhandling_override
      @ej_targets = nil
    end

    @store.clear
    grouped_buffers.each do |dname, files|
      dir_iter = @store.append(nil)
      dir_iter[COL_LABEL] = "📂 #{tilde_path(dname)}"
      dir_iter[COL_BUF_ID] = 0
      files.each do |bnfo|
        active_mark = bnfo[:buf].is_active? ? "● " : "  "
        file_iter = @store.append(dir_iter)
        file_iter[COL_LABEL] = "#{active_mark}#{bnfo[:bname]}"
        file_iter[COL_BUF_ID] = bnfo[:buf].id
      end
    end

    @tree.expand_all
  end
end
end # module Vimamsa
