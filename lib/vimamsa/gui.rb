$idle_scroll_to_mark = false

def gui_open_file_dialog(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Open file",
                                      :action => :open,
                                      :buttons => [[Gtk::Stock::OPEN, :accept],
                                                   [Gtk::Stock::CANCEL, :cancel]])
  dialog.set_current_folder(dirpath)

  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT
      open_new_file(dialog.filename)
      # puts "uri = #{dialog.uri}"
    end
    dialog.destroy
  end
  dialog.run
end

def gui_file_saveas(dirpath)
  dialog = Gtk::FileChooserDialog.new(:title => "Save as",
                                      :action => :save,
                                      :buttons => [[Gtk::Stock::SAVE, :accept],
                                                   [Gtk::Stock::CANCEL, :cancel]])
  dialog.set_current_folder(dirpath)
  dialog.signal_connect("response") do |dialog, response_id|
    if response_id == Gtk::ResponseType::ACCEPT
      file_saveas(dialog.filename)
    end
    dialog.destroy
  end

  dialog.run
end

def idle_func
  # puts "IDLEFUNC"
  if $idle_scroll_to_mark
    # Ripl.start :binding => binding
    # $view.get_visible_rect
    vr = $view.visible_rect

    # iter = b.get_iter_at(:offset => i)

    b = $view.buffer
    iter = b.get_iter_at(:offset => b.cursor_position)
    iterxy = $view.get_iter_location(iter)
    # puts "ITERXY" + iterxy.inspect
    # Ripl.start :binding => binding

    intr = iterxy.intersect(vr)
    if intr.nil?
      $view.set_cursor_pos($view.buffer.cursor_position)
    else
      $idle_scroll_to_mark = false
    end

    sleep(0.1)
  end
  sleep(0.01)
  return true
end

def center_on_current_line()
  b = $view.buffer
  iter = b.get_iter_at(:offset => b.cursor_position)
  within_margin = 0.0 #margin as a [0.0,0.5) fraction of screen size
  use_align = true
  xalign = 0.0 #0.0=top 1.0=bottom, 0.5=center
  yalign = 0.5
  $view.scroll_to_iter(iter, within_margin, use_align, xalign, yalign)
end

def get_visible_area()
  view = $view
  vr = view.visible_rect
  startpos = view.get_iter_at_position_raw(vr.x, vr.y)[1].offset
  endpos = view.get_iter_at_position_raw(vr.x + vr.width, vr.y + vr.height)[1].offset
  return [startpos, endpos]
end

def page_up
  $view.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), -1, false)
  return true
end

def page_down
  $view.signal_emit("move-cursor", Gtk::MovementStep.new(:PAGES), 1, false)
  return true
end

def paste_system_clipboard()
  # clipboard = $vmag.window.get_clipboard(Gdk::Selection::CLIPBOARD)
  utf8_string = Gdk::Atom.intern("UTF8_STRING")
  # x = clipboard.request_contents(utf8_string)

  widget = Gtk::Invisible.new
  clipboard = Gtk::Clipboard.get_default($vmag.window.display)
  received_text = ""

  target_string = Gdk::Selection::TARGET_STRING
  ti = clipboard.request_contents(target_string)

  # clipboard.request_contents(target_string) do |_clipboard, selection_data|
  # received_text = selection_data.text
  # puts "received_text=#{received_text}"
  # end
  if clipboard.wait_is_text_available?
    received_text = clipboard.wait_for_text
  end

  if received_text != "" and !received_text.nil?
    max_clipboard_items = 100
    if received_text != $clipboard[-1]
      #TODO: HACK
      $paste_lines = false
    end
    $clipboard << received_text
    # puts $clipboard[-1]
    $clipboard = $clipboard[-([$clipboard.size, max_clipboard_items].min)..-1]
  end
  return received_text
end

def set_system_clipboard(arg)
  # return if arg.class != String
  # return if s.size < 1
  # utf8_string = Gdk::Atom.intern("UTF8_STRING")
  widget = Gtk::Invisible.new
  clipboard = Gtk::Clipboard.get_default($vmag.window.display)
  clipboard.text = arg
end

def gui_create_buffer(id)
  puts "gui_create_buffer(#{id})"
  buf1 = GtkSource::Buffer.new()
  view = VSourceView.new()

  view.set_highlight_current_line(true)
  view.set_show_line_numbers(true)
  view.set_buffer(buf1)

  ssm = GtkSource::StyleSchemeManager.new
  ssm.set_search_path(ssm.search_path << ppath("styles/"))
  #  sty = ssm.get_scheme("dark")
  sty = ssm.get_scheme("molokai_edit")
  # puts ssm.scheme_ids

  view.buffer.highlight_matching_brackets = true
  view.buffer.style_scheme = sty

  provider = Gtk::CssProvider.new
  provider.load(data: "textview { font-family: Monospace; font-size: 11pt; }")
  # provider.load(data: "textview { font-family: Arial; font-size: 12pt; }")
  view.style_context.add_provider(provider)
  view.wrap_mode = :char

  $vmag.buffers[id] = view
end

def gui_set_file_lang(id, lname)
  view = $vmag.buffers[id]
  lm = GtkSource::LanguageManager.new
  lang = nil
  lm.set_search_path(lm.search_path << ppath("lang/"))
  lang = lm.get_language(lname)

  view.buffer.language = lang
  view.buffer.highlight_syntax = true
end

def gui_add_image(imgpath, pos)
end

# TODO:?
def gui_select_window_close(arg = nil)
end

# def set_window_title(str)
# unimplemented
# end

def gui_set_buffer_contents(id, txt)
  # $vbuf.set_text(txt)
  puts "gui_set_buffer_contents(#{id}, txt)"

  $vmag.buffers[id].buffer.set_text(txt)
end

def gui_set_cursor_pos(id, pos)
  $view.set_cursor_pos(pos)
  # Ripl.start :binding => binding
end

def gui_set_current_buffer(id)
  view = $vmag.buffers[id]
  puts "gui_set_current_buffer(#{id}), view=#{view}"
  buf1 = view.buffer
  $vmag.view = view
  $vmag.buf1 = buf1
  $view = view
  $vbuf = buf1

  $vmag.sw.remove($vmag.sw.child) if !$vmag.sw.child.nil?
  $vmag.sw.add(view)

  view.grab_focus
  #view.set_focus(10)
  view.set_cursor_visible(true)
  #view.move_cursor(1, 1, false)
  view.place_cursor_onscreen

  #TODO:
  # itr = view.buffer.get_iter_at(:offset => 0)
  # view.buffer.place_cursor(itr)

  # wtitle = ""
  # wtitle = buf.fname if !buf.fname.nil?
  $vmag.sw.show_all
end

def gui_set_window_title(wtitle, subtitle = "")
  $vmag.window.title = wtitle
  $vmag.window.titlebar.subtitle = subtitle
end


