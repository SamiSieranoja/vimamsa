
module Vimamsa
class FileTreePanel
  COL_LABEL = 0   # Pango markup
  COL_BUF_ID = 1  # 0 = folder row (not selectable)
  COL_CLOSE = 2   # close button markup; nil on folder rows
  COL_MARK = 3    # mark char on mark rows; "" on the "Marks" header; nil otherwise

  CLOSE_GLYPH = "×"

  def initialize
    @store = Gtk::TreeStore.new(String, Integer, String, String)
    @tree, @sw = build_list_tree(@store, ellipsize: Pango::EllipsizeMode::START,
                                 text_col: COL_LABEL, markup: true) do |iter|
      mark = iter[COL_MARK]
      if mark && !mark.empty?
        vma.buf.jump_to_mark(mark)
        next
      end
      buf_id = iter[COL_BUF_ID]
      next if buf_id.nil? || buf_id == 0
      next if @close_click # this click belonged to the close button
      vma.buffers.set_current_buffer(buf_id)
    end
    @tree.level_indentation = 7

    # Small close (x) button directly in front of each file name: a glyph cell
    # packed first into the name column, so it follows the row indentation.
    # Its hover/pressed tint is a Pango span background, so it covers only the
    # button (a cell background would also fill the indentation).
    @close_renderer = Gtk::CellRendererText.new
    col = @tree.get_column(0)
    col.pack_start(@close_renderer, false)
    col.reorder(@close_renderer, 0)
    col.add_attribute(@close_renderer, "markup", COL_CLOSE)

    # Paths are ellipsized at the start (keep the file name visible); mark
    # rows at the end, so the mark char and line number stay visible.
    text_renderer = col.cells.find { |c| !c.equal?(@close_renderer) }
    col.set_cell_data_func(text_renderer) do |_col, r, _model, iter|
      r.ellipsize = iter[COL_MARK].nil? ? Pango::EllipsizeMode::START : Pango::EllipsizeMode::END
    end
    init_close_button_events

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

  # { buf_id => label markup } for the file rows (tests / introspection).
  def row_labels
    file_rows.transform_values { |iter| iter[COL_LABEL] }
  end

  def file_rows
    h = {}
    @store.each do |_model, _path, iter|
      next if iter[COL_BUF_ID] == 0
      h[iter[COL_BUF_ID]] = iter
    end
    h
  end

  # Button-like feedback for the close icon: tinted on hover, darker while
  # pressed; the file closes on release over the same button (dragging off
  # cancels, like a real button).
  def init_close_button_events
    @close_hover = nil
    @close_pressed = nil

    click = Gtk::GestureClick.new
    click.button = 1
    # Capture phase + claim: the tree's own click handling (select/activate
    # row) must not see presses on the close button.
    click.propagation_phase = :capture
    @tree.add_controller(click)
    click.signal_connect("pressed") do |gesture, _n, x, y|
      id = close_hit(x, y)
      @close_click = !id.nil?
      next unless id
      gesture.set_state(:claimed)
      close_press(id)
    end
    click.signal_connect("released") do |_g, _n, x, y|
      close_release(close_hit(x, y))
    end
    click.signal_connect("stopped") { close_release(nil) if @close_pressed }

    motion = Gtk::EventControllerMotion.new
    @tree.add_controller(motion)
    motion.signal_connect("motion") { |_c, x, y| set_close_hover(close_hit(x, y)) }
    motion.signal_connect("leave") { set_close_hover(nil) }
  end

  # buf_id of the file row whose close button is at widget coords (x, y), else nil.
  def close_hit(x, y)
    bx, by = @tree.convert_widget_to_bin_window_coords(x.to_i, y.to_i)
    path, col, = @tree.get_path_at_pos(bx, by)
    return nil unless path && col
    iter = @store.get_iter(path)
    return nil unless iter && iter[COL_BUF_ID].to_i != 0
    area = @tree.get_cell_area(path, col)
    (bx >= area.x && bx < area.x + close_w) ? iter[COL_BUF_ID] : nil
  end

  # Width of the close button cell, px (its natural width: the glyph + padding).
  def close_w
    @close_renderer.markup = close_markup(nil)
    @close_renderer.get_preferred_width(@tree)[1]
  end

  # Widget coords of the center of a file row's close button (tests).
  def close_button_center(buf_id)
    path = file_rows[buf_id]&.path
    return nil unless path
    area = @tree.get_cell_area(path, @tree.get_column(0))
    @tree.convert_bin_window_to_widget_coords(area.x + close_w / 2, area.y + area.height / 2)
  end

  def close_press(buf_id)
    @close_pressed = buf_id
    update_close_bg
  end

  # Release over buf_id's close button (nil = elsewhere): closes the file only
  # if it is the one that was pressed.
  def close_release(buf_id)
    pressed = @close_pressed
    @close_pressed = nil
    update_close_bg
    # @close_click suppresses the row activation of this same click; clear it
    # once the click's other handlers have run.
    GLib::Idle.add { @close_click = false; false }
    close_buffer_from_panel(pressed) if pressed && pressed == buf_id
  end

  def set_close_hover(buf_id)
    return if buf_id == @close_hover
    @close_hover = buf_id
    update_close_bg
  end

  # :pressed, :hover or :normal
  def close_state(buf_id)
    if buf_id == @close_pressed
      :pressed
    elsif buf_id == @close_hover && @close_pressed.nil?
      :hover
    else
      :normal
    end
  end

  def close_markup(buf_id)
    case close_state(buf_id)
    when :pressed
      "<span background=\"#{panel_color(:file_panel_close_pressed_bg)}\" weight=\"bold\"> #{CLOSE_GLYPH} </span>"
    when :hover
      "<span background=\"#{panel_color(:file_panel_close_hover_bg)}\"> #{CLOSE_GLYPH} </span>"
    else
      "<span fgalpha=\"55%\"> #{CLOSE_GLYPH} </span>"
    end
  end

  def update_close_bg
    file_rows.each do |id, iter|
      m = close_markup(id)
      iter[COL_CLOSE] = m if iter[COL_CLOSE] != m
    end
  end

  # Deferred: closing refreshes (clears) the store, which must not happen
  # inside the tree's own row-activated emission. A non-current file is
  # closed in the background so the current file stays in view.
  def close_buffer_from_panel(buf_id)
    GLib::Idle.add do
      if vma.buf&.id == buf_id
        vma.buffers.close_buffer(buf_id)
      else
        vma.buffers.close_other_buffer(buf_id)
      end
      false
    end
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
      iter[COL_LABEL] = "#{ej_label_markup(labels[i])} #{iter[COL_LABEL]}"
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

  def panel_color(name)
    cnf.theme.cyberpunk_glow? ? cyber_color(name) : theme_color(name)
  end

  # Current file: bold + brighter fg. Kept in the markup (not a cell-wide
  # attribute) so an easy-jump label span keeps its own color on this row.
  def current_markup(escaped)
    "<span foreground=\"#{panel_color(:file_panel_current_fg)}\" weight=\"bold\">#{escaped}</span>"
  end

  # Reddish bold label; a TreeView cell cannot do a CSS text-shadow, so the
  # "glow" is a translucent background tint around the label.
  def ej_label_markup(label)
    "<span foreground=\"#{panel_color(:file_panel_ej_label_fg)}\" weight=\"bold\" " \
      "background=\"#{panel_color(:file_panel_ej_label_glow)}\" bgalpha=\"30%\"> #{label} </span>"
  end

  # ── Marks of the current file (m <char>), shown above the files ──

  MARK_TEXT_MAX = 40 # chars of the marked line shown after the line number

  # { char => [lpos (0-based), line text] } of vma.buf's user marks, by char.
  def current_marks
    b = vma.buf
    return {} unless b
    b.user_marks.to_h do |c, pos|
      lpos = b.get_line_pos(pos)
      [c, [lpos, b.line(lpos).to_s.chomp.strip]]
    end
  end

  def mark_label(c, lpos, text)
    text = text[0, MARK_TEXT_MAX] + "…" if text.size > MARK_TEXT_MAX
    "<b>#{CGI.escapeHTML(c)}</b>  #{lpos + 1}: #{CGI.escapeHTML(text)}"
  end

  # { char => label markup } for the mark rows (tests / introspection).
  def mark_rows
    h = {}
    @store.each do |_m, _p, iter|
      m = iter[COL_MARK]
      h[m] = iter[COL_LABEL] if m && !m.empty?
    end
    h
  end

  # Rebuild only the marks section (first top-level row), leaving the file
  # rows and the scroll position alone.
  def refresh_marks
    first = @store.iter_first
    @store.remove(first) if first && first[COL_MARK] == ""
    marks = current_marks
    return if marks.empty?
    head = @store.insert(nil, 0)
    head[COL_LABEL] = CGI.escapeHTML("📌 Marks")
    head[COL_BUF_ID] = 0
    head[COL_MARK] = ""
    marks.each do |c, (lpos, text)|
      it = @store.append(head)
      it[COL_LABEL] = mark_label(c, lpos, text)
      it[COL_BUF_ID] = 0
      it[COL_MARK] = c
    end
    @tree.expand_row(head.path, true)
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
      dir_iter[COL_LABEL] = CGI.escapeHTML("📂 #{tilde_path(dname)}")
      dir_iter[COL_BUF_ID] = 0
      files.each do |bnfo|
        active_mark = bnfo[:buf].is_active? ? "● " : "  "
        current = bnfo[:buf].equal?(vma.buf) # Buffer < String: == compares text
        file_iter = @store.append(dir_iter)
        label = CGI.escapeHTML("#{active_mark}#{bnfo[:bname]}")
        file_iter[COL_LABEL] = current ? current_markup(label) : label
        file_iter[COL_BUF_ID] = bnfo[:buf].id
        file_iter[COL_CLOSE] = close_markup(bnfo[:buf].id)
      end
    end

    @tree.expand_all
    refresh_marks
  end
end
end # module Vimamsa
