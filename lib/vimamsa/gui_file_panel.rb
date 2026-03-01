class FileTreePanel
  COL_LABEL = 0
  COL_BUF_ID = 1  # 0 = folder row (not selectable)

  def initialize
    @store = Gtk::TreeStore.new(String, Integer)
    @tree = Gtk::TreeView.new(@store)
    @tree.headers_visible = false

    renderer = Gtk::CellRendererText.new
    renderer.ellipsize = Pango::EllipsizeMode::START
    col = Gtk::TreeViewColumn.new("", renderer, text: COL_LABEL)
    col.expand = true
    @tree.append_column(col)

    @tree.signal_connect("row-activated") do |tv, path, _col|
      iter = @store.get_iter(path)
      next if iter.nil?
      buf_id = iter[COL_BUF_ID]
      next if buf_id.nil? || buf_id == 0
      vma.buffers.set_current_buffer(buf_id)
    end

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

    @sw = Gtk::ScrolledWindow.new
    @sw.set_policy(:never, :automatic)
    @sw.set_child(@tree)
    @sw.set_size_request(180, -1)
    @sw.vexpand = true
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

  def refresh
    @store.clear
    bh = {}
    vma.buffers.list.each do |b|
      dname = b.fname ? File.dirname(b.fname) : "*"
      bname = b.fname ? File.basename(b.fname) : (b.list_str || "(untitled)")
      bh[dname] ||= []
      bh[dname] << { bname: bname, buf: b }
    end

    bh.keys.sort.each do |dname|
      dir_iter = @store.append(nil)
      dir_iter[COL_LABEL] = "📂 #{tilde_path(dname)}"
      dir_iter[COL_BUF_ID] = 0
      bh[dname].sort_by { |x| x[:bname] }.each do |bnfo|
        active_mark = bnfo[:buf].is_active? ? "● " : "  "
        file_iter = @store.append(dir_iter)
        file_iter[COL_LABEL] = "#{active_mark}#{bnfo[:bname]}"
        file_iter[COL_BUF_ID] = bnfo[:buf].id
      end
    end

    @tree.expand_all
  end
end
