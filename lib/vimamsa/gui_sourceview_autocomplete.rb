# require "trie"
require "rambling-trie"

class Autocomplete
  @@trie = Rambling::Trie.create

  def self.init
    vma.hook.register(:file_saved, self.method("update_index"))
  end

  def self.update_index(bu)
    debug "self.update_index", 2
    add_words bu.scan_all_words
  end

  def self.update_dict
    for bu in vma.buffers.list
      for w in bu.scan_all_words
        trie << w
      end
    end
    @@trie = trie
  end

  def self.add_words(words)
    for w in words
      @@trie << w
    end
  end

  def self.word_list
    return @@dict.keys
  end

  def self.matching_words(beginning)
    return @@trie.scan(beginning)
  end
end

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

  def try_autocomplete
  end

  def show_completions
    hide_completions
    bu = vma.buf
    (w, range) = bu.get_word_in_pos(bu.pos - 1, boundary: :word)
    debug [w, range].to_s, 2
    matches = Autocomplete.matching_words w
    return if matches.empty?
    @autocp_active = true
    @cpl_list = cpl_list = matches
    win = Gtk::Popover.new()
    win.parent = self
    vbox = Gtk::Grid.new()
    win.set_child(vbox)

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
    (x, y) = cur_pos_xy
    rec = Gdk::Rectangle.new(x, y + 8, 10, 10)
    win.has_arrow = false
    win.set_pointing_to(rec)
    win.autohide = false
    win.popup
    gui_remove_controllers(win)
    @acwin = win
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
