module Vimamsa
  class Menu
    def add_to_menu(_mpath, x)
      mpath = _mpath.split(".")
      curnfo = @nfo
      for y in mpath
        debug(curnfo.inspect)
        if y.equal?(mpath.last)
          curnfo[y] = x
        elsif curnfo[y].nil?
          curnfo[y] = { :label => y, :items => {} }
        end
        curnfo[y][:items] = {} if curnfo[y][:items].class != Hash
        curnfo = curnfo[y][:items]
      end #end for
    end

    def add_menu_items()
      add_to_menu "File.Save", { :label => "Save", :action => :buf_save }
      add_to_menu "File.Save as", { :label => "Save As...", :action => :buf_save_as }
      add_to_menu "File.Open", { :label => "Open", :action => :open_file_dialog }

      add_to_menu "File.New", { :label => "New file", :action => :buf_new }
      add_to_menu "File.Revert", { :label => "Reload file from disk", :action => :buf_revert }
      add_to_menu "File.List", { :label => "List open files", :action => :start_buf_manager }

      add_to_menu "File.Quit", { :label => "Quit", :action => :quit }

      add_to_menu "Edit.Undo", { :label => "Undo edit", :action => :edit_undo }
      add_to_menu "Edit.Redo", { :label => "Redo edit", :action => :edit_redo }
      add_to_menu "Edit.SearchReplace", { :label => "Search and replace", :action => :gui_search_replace }
      add_to_menu "Edit.Find", { :label => "Find", :action => :find_in_buffer }

      add_to_menu "Actions.SearchForActions", { :label => "Search for Actions", :action => :search_actions }

      add_to_menu "Actions.Grep", { :label => "Grep lines", :action => :invoke_grep_search }

      add_to_menu "Actions.FileHistoryFinder", { :label => "Search files in history", :action => :gui_file_history_finder }

      add_to_menu "Actions.experimental.Diff", { :label => "Show Diff of\nunsaved changes", :action => :diff_buffer }

      add_to_menu "Actions.EncryptFile", { :label => "Encrypt file", :action => :encrypt_file }

      #TODO: :auto_indent_buffer

      # add_to_menu "Actions.Ack", { :label => "source code search (Ack)", :action => :ack_search }

    end

    def initialize(menubar)
      # nfo["file"] = { :items => {}, :label => "File" }
      # nfo["actions"] = { :items => {}, :label => "Actions" }
      # nfo["help"] = { :items => {}, :label => "Help" }

      @nfo = {}

      add_menu_items

      # add_to_menu("help.extra.keybindings", { :label => "Show keybindings" })
      # add_to_menu("help.extra.nfo.keybindings", { :label => "Show keybindings" })
      # add_to_menu("help.keybindings", { :label => "Show keybindings <span foreground='#888888'  >C ? k</span>" }) #font='12' weight='ultrabold'

      for k, v in @nfo
        build_menu(v, menubar)
      end
    end

    def build_menu(nfo, parent)
      menu = Gtk::Menu.new
      if nfo[:action]
        kbd_str = ""
        for mode_str in ["C", "V"]
          c_kbd = vma.kbd.act_bindings[mode_str][nfo[:action]]
          if c_kbd.class == String
            kbd_str = "   <span foreground='#888888'><span weight='bold'>[#{mode_str}]</span> #{c_kbd}</span>"
            break
          end
        end

        label_str = nfo[:label] + kbd_str
        menuitem = Gtk::MenuItem.new(:label => label_str)
        menuitem.children[0].set_markup(label_str)

        menuitem.signal_connect("activate") do
          call_action(nfo[:action])
        end
      else
        menuitem = Gtk::MenuItem.new(:label => nfo[:label])
        menuitem.children[0].set_markup(nfo[:label])
      end

      if !nfo[:items].nil? and !nfo[:items].empty?
        for k2, item in nfo[:items]
          build_menu(item, menu)
        end
        menuitem.submenu = menu
      end
      parent.append(menuitem)
    end
  end #end class
end
