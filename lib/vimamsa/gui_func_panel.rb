class FuncPanel
  COL_NAME = 0
  COL_LINE = 1  # 1-based line number; 0 = placeholder row (not clickable)

  def initialize
    @store = Gtk::ListStore.new(String, Integer)
    @tree = Gtk::TreeView.new(@store)
    @tree.headers_visible = false
    @tree.activate_on_single_click = true

    renderer = Gtk::CellRendererText.new
    renderer.ellipsize = Pango::EllipsizeMode::END
    col = Gtk::TreeViewColumn.new("", renderer, text: COL_NAME)
    col.expand = true
    @tree.append_column(col)

    @tree.signal_connect("row-activated") do |_tv, path, _col|
      iter = @store.get_iter(path)
      next if iter.nil?
      line = iter[COL_LINE]
      next if line <= 0
      vma.buf.jump_to_line(line)
    end

    @sw = Gtk::ScrolledWindow.new
    @sw.set_policy(:never, :automatic)
    @sw.set_child(@tree)
    @sw.set_size_request(160, -1)
    @sw.vexpand = true
  end

  def widget
    @sw
  end

  def refresh
    buf = vma.buf
    unless buf&.fname
      set_placeholder("(no file)")
      return
    end
    lsp = LangSrv.get(buf.lang)
    unless lsp
      set_placeholder("(no LSP)")
      return
    end
    fpath = buf.fname
    Thread.new {
      funcs = lsp.document_functions(fpath)
      GLib::Idle.add {
        @store.clear
        if funcs.nil? || funcs.empty?
          set_placeholder("(no functions)")
        else
          funcs.each do |f|
            iter = @store.append
            iter[COL_NAME] = f[:name]
            iter[COL_LINE] = f[:line]
          end
        end
        false
      }
    }
  end

  private

  def set_placeholder(text)
    @store.clear
    iter = @store.append
    iter[COL_NAME] = text
    iter[COL_LINE] = 0
  end
end
