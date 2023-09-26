def gui_select_update_window(item_list, jump_keys, select_callback, update_callback, opt = {})
  $selup = SelectUpdateWindow.new(nil, item_list, jump_keys, select_callback, update_callback, opt)
  $selup.run
  # opt fields:
  # :title
  # :desc
end

class SelectUpdateWindow
  COLUMN_JUMP_KEY = 0
  COLUMN_DESCRIPTION = 1

  def update_item_list(item_list)
    # debug item_list.inspect
    @model.clear
    for item in item_list
      iter = @model.append
      if !@opt[:columns].nil?
        v = item
      else
        v = ["", item[0]]
      end
      debug v.inspect
      iter.set_values(v)
    end

    set_selected_row(0)
  end

  def set_selected_row(rownum)
    rownum = 0 if rownum < 0
    @selected_row = rownum

    if @model.count > 0
      path = Gtk::TreePath.new(@selected_row.to_s)
      iter = @model.get_iter(path)
      @tv.selection.select_iter(iter)
    end
  end

  def initialize(main_window, item_list, jump_keys, select_callback, update_callback, opt = {})
    @window = Gtk::Window.new()
    # @window.screen = main_window.screen
    @window.title = ""
    if !opt[:title].nil?
      @window.title = opt[:title]
    end

    @selected_row = 0
    @opt = opt

    debug item_list.inspect
    @update_callback = method(update_callback)
    @select_callback = method(select_callback)
    # debug @update_callback_m.call("").inspect

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin_bottom = 8
    vbox.margin_top = 8

    @window.add(vbox)

    @entry = Gtk::SearchEntry.new
    @entry.width_chars = 45
    container = Gtk::Box.new(:horizontal, 10)
    # container.halign = :start
    container.halign = :center
    container.pack_start(@entry,
                         :expand => false, :fill => false, :padding => 0)

    # create tree view
    @model = Gtk::ListStore.new(String, String)
    treeview = Gtk::TreeView.new(@model)
    treeview.search_column = COLUMN_DESCRIPTION
    @tv = treeview
    # item_list = @update_callback.call("")
    update_item_list(item_list)

    # @window.signal_connect("key-press-event") do |_widget, event| #TODO:gtk4
    # debug "KEYPRESS 1"
    # @entry.handle_event(event)
    # end

    press = Gtk::EventControllerKey.new
    press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)

    @entry.add_controller(press)
    # @window.add_controller(press)
    press.signal_connect "key-pressed" do |gesture, keyval, keycode, y|
      name = Gdk::Keyval.to_name(keyval)
      uki = Gdk::Keyval.to_unicode(keyval)
      keystr = uki.chr("UTF-8")
      debug "keyval=#{keyval}"

      if keyval == Gdk::Keyval::KEY_Down
        debug "DOWN"
        set_selected_row(@selected_row + 1)
        true
      elsif keyval == Gdk::Keyval::KEY_Up
        set_selected_row(@selected_row - 1)
        debug "UP"
        true
      elsif keyval == Gdk::Keyval::KEY_Return
        path = Gtk::TreePath.new(@selected_row.to_s)
        iter = @model.get_iter(path)
        ret = iter[1]
        @select_callback.call(ret, @selected_row)
        @window.destroy
        # debug iter[1].inspect
        true
      elsif keyval == Gdk::Keyval::KEY_Escape
        @window.destroy
        true
      else
        false
      end
    end

    @entry.signal_connect("search-changed") do |widget|
      debug "search changed: #{widget.text || ""}"
      item_list = @update_callback.call(widget.text)

      update_item_list(item_list)
      # label.text = widget.text || ""
    end
    @entry.signal_connect("changed") { debug "[changed] " }
    @entry.signal_connect("next-match") { debug "[next-match] " }

    if !opt[:desc].nil?
      descl = Gtk::Label.new(opt[:desc])
      vbox.pack_start(descl, :expand => false, :fill => false, :padding => 0)
    end

    # label = Gtk::Label.new(<<-EOF)
    # Search:
    # EOF

    # label = Gtk::Label.new("Input:")
    # vbox.pack_start(label, :expand => false, :fill => false, :padding => 0)

    vbox.pack_start(container, :expand => false, :fill => false, :padding => 0)
    sw = Gtk::ScrolledWindow.new(nil, nil)
    # sw.shadow_type = :etched_in #TODO:gtk4
    sw.set_policy(:never, :automatic)
    vbox.pack_end(sw, :expand => true, :fill => true, :padding => 0)

    # sw.add(treeview) #TODO:gtk4
    sw.set_child(treeview)

    if !opt[:columns].nil?
      for col in opt[:columns]
        renderer = Gtk::CellRendererText.new
        column = Gtk::TreeViewColumn.new(col[:title],
                                         renderer,
                                         "text" => col[:id])
        column.sort_column_id = col[:id]
        treeview.append_column(column)
      end
    else
      renderer = Gtk::CellRendererText.new
      column = Gtk::TreeViewColumn.new("JMP",
                                       renderer,
                                       "text" => COLUMN_JUMP_KEY)
      column.sort_column_id = COLUMN_JUMP_KEY
      treeview.append_column(column)

      renderer = Gtk::CellRendererText.new
      column = Gtk::TreeViewColumn.new("Description",
                                       renderer,
                                       "text" => COLUMN_DESCRIPTION)
      column.sort_column_id = COLUMN_DESCRIPTION
      treeview.append_column(column)
    end

    @window.set_default_size(280, 500)
    debug "SelectUpdateWindow"
  end

  def run
    if !@window.visible?
      @window.show
      # add_spinner
    else
      @window.destroy
      # GLib::Source.remove(@tiemout) unless @timeout.zero?
      @timeout = 0
    end
    @window
  end
end
