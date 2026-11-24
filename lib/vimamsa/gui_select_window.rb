
module Vimamsa
def gui_select_update_window(item_list, jump_keys, select_callback, update_callback, opt = {})
  $selup = SelectUpdateWindow.new(nil, item_list, jump_keys, select_callback, update_callback, opt)
  $selup.run
  # opt fields:
  # :title
  # :desc
end

# A list filtered by a search field (action search, file finder, file
# history, macros, language). The field is edited through the key bindings in
# form mode (form_input.rb), so the typing shows in the key log and a demo can
# record it: up / down move the selection, enter picks, esc closes, delete
# deletes an item if the list allows it (opt[:delete_callback]).
class SelectUpdateWindow
  attr_reader :form, :selected_row

  COLUMN_JUMP_KEY = 0
  COLUMN_DESCRIPTION = 1

  def update_item_list(item_list)
    # debug item_list.inspect
    return if item_list.empty?

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
    count = @model.count
    return if count == 0
    rownum = 0 if rownum < 0
    rownum = count - 1 if rownum >= count
    @selected_row = rownum
    path = Gtk::TreePath.new(@selected_row.to_s)
    iter = @model.get_iter(path)
    @tv.selection.select_iter(iter)
  end

  def initialize(main_window, item_list, jump_keys, select_callback, update_callback, opt = {})
    # Modal: while it is up, its form takes the keys
    @window = make_modal_window(opt[:title] || "")

    @selected_row = 0
    @opt = opt

    debug item_list.inspect

    if select_callback.class == Method || select_callback.class == Proc
      @select_callback = select_callback
    else
      @select_callback = method(select_callback)
    end
    if update_callback.class == Method || update_callback.class == Proc
      @update_callback = update_callback
    else
      @update_callback = method(update_callback)
    end
    # debug @update_callback_m.call("").inspect

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin_bottom = 8
    vbox.margin_top = 8

    @window.set_child(vbox)

    if !opt[:desc].nil?
      descl = Gtk::Label.new(opt[:desc])
      descl.margin = 15
      # vbox.append(descl, :expand => false, :fill => false, :padding => 0)
      vbox.append(descl)
    end

    @entry = Gtk::SearchEntry.new
    @entry.width_chars = 45
    container = Gtk::Box.new(:horizontal, 10)
    # container.halign = :start
    container.halign = :center
    container.append(@entry)

    # create tree view
    # As many columns as opt[:columns] has (2 without)
    ncols = opt[:columns] ? opt[:columns].map { |c| c[:id] }.max + 1 : 2
    @model = Gtk::ListStore.new(*([String] * ncols))
    treeview = Gtk::TreeView.new(@model)
    treeview.search_column = COLUMN_DESCRIPTION
    @tv = treeview
    # item_list = @update_callback.call("")
    update_item_list(item_list)

    @form = FormInput.new(@window, submit: method(:select_current), cancel: method(:close))
    @field = @form.add_field(@entry)
    # The list follows the field, in an idle (typing stays quick with a slow
    # update callback); enter first applies a pending update
    @field.on_change = proc { |_t| schedule_update }
    @form.key_handlers = {
      up: proc { set_selected_row(@selected_row - 1) },
      down: proc { set_selected_row(@selected_row + 1) },
    }
    @form.key_handlers[:delete] = method(:delete_current) if @opt[:delete_callback]
    @window.signal_connect("close-request") { @form.deactivate; false }

    # label = Gtk::Label.new(<<-EOF)
    # Search:
    # EOF

    # label = Gtk::Label.new("Input:")
    # vbox.pack_start(label, :expand => false, :fill => false, :padding => 0)

    vbox.append(container)
    sw = Gtk::ScrolledWindow.new(nil, nil)
    sw.set_policy(:never, :automatic)
    vbox.append(sw)
    sw.vexpand = true
    sw.hexpand = true

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
    @window.show
    @form.activate
    @form.focus(0)
    @window
  end

  # The list for the field's text now
  def update_now
    remove_update
    item_list = run_dialog_callback("select update") { @update_callback.call(@field.text) }
    update_item_list(item_list) if item_list
  end

  # enter: the selected row to the callback
  def select_current
    update_now if @update_pending
    path = Gtk::TreePath.new(@selected_row.to_s)
    iter = @model.get_iter(path)
    @form.deactivate
    run_dialog_callback("select") { @select_callback.call(iter[1], @selected_row) } if iter
    close
  end

  def close
    remove_update
    @form.deactivate
    @window.destroy
  end

  private

  def schedule_update
    return if @update_pending
    @update_pending = GLib::Idle.add { @update_pending = nil; update_now; false }
  end

  def remove_update
    GLib::Source.remove(@update_pending) rescue nil if @update_pending
    @update_pending = nil
  end

  def delete_current
    path = Gtk::TreePath.new(@selected_row.to_s)
    iter = @model.get_iter(path)
    return if !iter
    name = iter[COLUMN_DESCRIPTION]
    refresh = proc {
      update_now
      @window.present
    }
    @opt[:delete_callback].call(name, refresh)
  end
end
end # module Vimamsa
