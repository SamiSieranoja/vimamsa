# Left-side panel that displays LSP-provided functions/methods for the current buffer,
# grouped by the class or module they belong to.
class FuncPanel
  COL_NAME = 0  # Tree column index: display name (class name or function name)
  COL_LINE = 1  # Tree column index: 1-based line number to jump to; 0 = not a jump target

  def initialize
    # @store is the data model: a tree (not flat list) so we can nest functions
    # under their parent class. Two columns: the display string and the line number.
    @store = Gtk::TreeStore.new(String, Integer)

    # @tree is the GTK widget that renders @store. It holds expand/collapse state
    # and handles row selection. Backed by @store — clearing @store clears the view.
    @tree = Gtk::TreeView.new(@store)
    @tree.headers_visible = false
    @tree.activate_on_single_click = true

    # Single text column; ellipsize at end so long names don't overflow the panel width.
    renderer = Gtk::CellRendererText.new
    renderer.ellipsize = Pango::EllipsizeMode::END
    col = Gtk::TreeViewColumn.new("", renderer, text: COL_NAME)
    col.expand = true
    @tree.append_column(col)

    # Jump to the function's line when a row is clicked.
    # Class header rows have COL_LINE = 0 and are skipped (no jump).
    @tree.signal_connect("row-activated") do |_tv, path, _col|
      iter = @store.get_iter(path)
      next if iter.nil?
      line = iter[COL_LINE]
      next if line <= 0
      vma.buf.jump_to_line(line)
    end

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:never, :automatic)
    sw.set_child(@tree)
    sw.vexpand = true

    header = Gtk::Label.new("<span weight='ultrabold'>Functions</span> (click to jump)")
    header.use_markup = true

    header.xalign = 0.0
    header.margin_start = 6
    header.margin_top = 4
    header.margin_bottom = 2

    # @box is the outermost widget: header label on top, scrollable tree below.
    @box = Gtk::Box.new(:vertical, 0)
    @box.set_size_request(160, -1)
    @box.append(header)
    @box.append(sw)
  end

  # Returns the outermost widget to embed in the paned layout.
  def widget
    @box
  end

  # Asynchronously fetch functions from the LSP server and repopulate @store.
  # The LSP call runs in a background thread; the GTK update is marshalled back
  # to the main thread via GLib::Idle.add to avoid threading issues.
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
      # groups: [{name:, line:, functions: [{name:, line:}, ...]}, ...]
      # name: nil means top-level functions with no enclosing class.
      groups = lsp.document_functions_grouped(fpath)
      GLib::Idle.add {
        @store.clear
        if groups.nil? || groups.empty?
          set_placeholder("(no functions)")
        else
          populate(groups)
        end
        false  # returning false removes this idle callback after one run
      }
    }
  end

  private

  # Fill @store from the grouped function list.
  # Named groups become collapsible parent rows; top-level functions are root rows.
  def populate(groups)
    groups.each do |g|
      if g[:name]
        # Class/module header: parent row with the class name (and its own line number
        # so clicking it jumps to the class definition when line > 0).
        header = @store.append(nil)
        header[COL_NAME] = g[:name]
        header[COL_LINE] = g[:line] || 0
        g[:functions].each do |f|
          child = @store.append(header)  # appended under the class header
          child[COL_NAME] = f[:name]
          child[COL_LINE] = f[:line]
        end
      else
        # Top-level functions (not inside any class): added as root rows directly.
        g[:functions].each do |f|
          row = @store.append(nil)
          row[COL_NAME] = f[:name]
          row[COL_LINE] = f[:line]
        end
      end
    end
    @tree.expand_all  # show all classes expanded by default
  end

  # Replace the entire store contents with a single non-clickable status message.
  def set_placeholder(text)
    @store.clear
    iter = @store.append(nil)
    iter[COL_NAME] = text
    iter[COL_LINE] = 0
  end
end
