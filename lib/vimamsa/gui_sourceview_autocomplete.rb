
class VSourceView < GtkSource::View
  def hide_completions
    if @acwin.class == Gtk::Popover
      @acwin.hide
    end
    @autocp_active = false
  end

  def autocp_select
    return if !@autocp_active
    bufo.complete_current_word(@cpl_list[@autocp_selected])
    autocp_exit
  end

  def autocp_select_previous
    return if @autocp_selected <= 0
    autocp_hilight(@autocp_selected)
    autocp_unhilight(@autocp_selected)
    @autocp_selected -= 1
    autocp_hilight(@autocp_selected)
  end

  def autocp_hilight(id)
    l = @autocp_items[id]
    l.set_text("<span foreground='#00ff00' weight='ultrabold'>#{cpl_list[id]}</span>")
    l.use_markup = true
  end

  def autocp_unhilight(id)
    l = @autocp_items[id]
    l.set_text("<span>#{cpl_list[id]}</span>")
    l.use_markup = true
  end

  def autocp_select_next
    return if @autocp_selected >= cpl_list.size - 1
    debug "autocp_select_next", 2
    autocp_unhilight(@autocp_selected)
    @autocp_selected += 1
    autocp_hilight(@autocp_selected)
  end

  def autocp_exit
    @autocp_items = []
    @autocp_active = true
    hide_completions
  end

  def show_completions
    hide_completions
    @autocp_active = true
    @cpl_list = cpl_list = ["completion ", "Antidisestablishment", "buf", "gtk_source_view", "GTK_SOURCE_VIEW"]
    # win = Gtk::Window.new()
    win = Gtk::Popover.new()
    win.parent = self
    # win.decorated = false
    vbox = Gtk::Grid.new()
    win.set_child(vbox)
    # vpaned = Gtk::Paned.new(:vertical)

    i = 0
    @autocp_items = []
    @autocp_selected = 0
    for x in cpl_list
      l = Gtk::Label.new(x)
      @autocp_items << l
      # numbers: left, top, width, height
      vbox.attach(l, 0, i, 1, 1)
      i += 1
    end
    autocp_hilight(0)
    # win.show
    # win.set_position(Gtk::PositionType::TOP)
    # win.set_offset(10,100)
    (x, y) = cur_pos_xy
    rec = Gdk::Rectangle.new(x, y + 8, 10, 10)
    win.has_arrow = false
    win.set_pointing_to(rec)
    win.autohide = false
    win.popup
    gui_remove_controllers(win)
    @acwin = win

    debug cur_pos_xy.inspect, 2
    # buf = gtk_text_view_get_buffer (GTK_TEXT_VIEW (priv->view));

    # provider
  end

  def start_autocomplete
    return
    # Roughly following these examples:
    # https://stackoverflow.com/questions/52359721/howto-maintain-gtksourcecompletion-when-changing-buffers-in-a-gtksourceview
    # and gedit-plugins-41.0/plugins/wordcompletion/gedit-word-completion-plugin.c
    # .. but it doesn't work. So implementing using Popover.
    # Keeping this for reference

    cp = self.completion
    prov = GtkSource::CompletionWords.new("Autocomplete") # (name,icon)
    prov.register(self.buffer)
    cp.add_provider(prov)
    pp prov
    self.show_completion
  end
end

