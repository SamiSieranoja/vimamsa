class VmaTerminal < Gtk::Box
  def initialize(anchor_pos, bufo)
    super(:vertical, 0)
    @anchor_pos = anchor_pos
    @bufo = bufo

    @term = Vte::Terminal.new
    @term.hexpand = true
    @term.vexpand = true
    append(@term)

    bar = Gtk::Box.new(:horizontal, 4)
    bar.margin_start = 4
    btn = Gtk::Button.new(label: "Copy to buffer")
    btn.signal_connect("clicked") { copy_to_buffer }
    bar.append(btn)
    append(bar)

    spawn_shell
  end

  private

  def spawn_shell
    # @term.spawn_async(
      # Vte::PtyFlags::DEFAULT,
      # nil,
      # [ENV["SHELL"] || "/bin/bash"],
      # GLib::Spawn::DEFAULT,
      # # -1
    # )
    
        # @term.spawn_async(
      # Vte::PtyFlags::DEFAULT,
      # # [ENV["SHELL"] || "/bin/bash"],
      # "/bin/bash",
      # [],
      # [],
      @term.spawn
         # @term.spawn_async(
      # "/home/sjs/",
      # [],
      # [],
      # GLib::Spawn::DEFAULT,
      # )
      # [ENV["SHELL"] || "/bin/bash"],
      # "/bin/bash",
     
      
      # g_spawn_async (
  # const gchar* working_directory,
  # gchar** argv,
  # gchar** envp,
  # GSpawnFlags flags,
  # GSpawnChildSetupFunc child_setup,
  # gpointer user_data,
  # GPid* child_pid,
  # GError** error
# )

      # GLib::Spawn::DEFAULT,
      # -1
    # )

  end

  def copy_to_buffer
    rows = @term.row_count
    cols = @term.column_count
    text = @term.get_text_range(0, 0, rows - 1, cols - 1)
                .gsub(/\s+$/, "")
                .rstrip
    return if text.empty?

    insert_pos = @anchor_pos + 1
    @bufo.insert_txt_at("\n" + text + "\n", insert_pos)
    @bufo.view.handle_deltas
  end
end

def insert_terminal_in_buffer
  view = vma.gui.view
  bufo = vma.buf
  return if view.nil? || bufo.nil?

  pos = bufo.pos

  bufo.insert_txt_at("\uFFFC", pos)
  view.handle_deltas

  iter = view.buffer.get_iter_at(:offset => pos)
  if iter && iter.char == "\uFFFC"
    iter2 = view.buffer.get_iter_at(:offset => pos + 1)
    view.buffer.delete(iter, iter2)
    iter = view.buffer.get_iter_at(:offset => pos)
    anchor = view.buffer.create_child_anchor(iter)
    widget = VmaTerminal.new(pos, bufo)

    char_w = view.pango_context.get_metrics(nil, nil).approximate_char_width / Pango::SCALE
    columns = char_w > 0 ? (view.allocated_width / char_w) - 4 : 80
    # require "pry";binding.pry
    # widget.instance_variable_get(:@term).set_columns(columns)
    widget.instance_variable_get(:@term).set_size(columns,20)

    view.add_child_at_anchor(widget, anchor)
    widget.show
  end
end

def terminal_init
  require "vte4"
  reg_act(:insert_terminal, proc { insert_terminal_in_buffer }, "Insert embedded terminal at cursor")
  add_keys "terminal", { "C , t" => :insert_terminal }
  vma.gui.menu.add_module_action(:insert_terminal, "Insert Terminal")
end

def terminal_disable
  unreg_act(:insert_terminal)
  vma.gui.menu.remove_module_action(:insert_terminal)
end
