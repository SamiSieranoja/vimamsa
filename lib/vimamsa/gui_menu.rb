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
      add_to_menu "File.Example", { :label => "<span foreground='#888888'>Action, [mode] key binding</span>", :action => nil }
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

      add_to_menu "Actions.experimental.EnableDebug", { :label => "Enable debug", :action => :enable_debug }
      add_to_menu "Actions.experimental.DisableDebug", { :label => "Disable debug", :action => :disable_debug }
      add_to_menu "Actions.experimental.ShowImages", { :label => "Show images ⟦img:path⟧", :action => :show_images }

      add_to_menu "Actions.EncryptFile", { :label => "Encrypt file", :action => :encrypt_file }
      add_to_menu "Help.KeyBindings", { :label => "Show key bindings", :action => :show_key_bindings }

      #TODO: :auto_indent_buffer

      # add_to_menu "Actions.Ack", { :label => "source code search (Ack)", :action => :ack_search }

    end

    def initialize(menubar, _app)
      @app = _app
      @nfo = {}

      add_menu_items

      for k, v in @nfo
        build_menu(v, menubar)
      end
    end

    def build_menu(nfo, parent)
      menu = Gio::Menu.new
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
        actkey = nfo[:action].to_s
        menuitem = Gio::MenuItem.new(label_str, "app.#{actkey}")
        
        # This worked in GTK3:
        # But seems there is no way to access the Label object in GTK4
        # menuitem.children[0].set_markup(label_str)

        act = Gio::SimpleAction.new(actkey)
        @app.add_action(act)
        act.signal_connect "activate" do |_simple_action, _parameter|
          call_action(nfo[:action])
        end
      else
        menuitem = Gio::MenuItem.new(nfo[:label], nil)
      end

      # Apparently requires Gtk 4.6 to work.
      # According to instructions in: https://discourse.gnome.org/t/gtk4-and-pango-markup-in-menu-items/16082
      # Boolean true here should work but doesn't yet in GTK 4.6. The string version does work.
      menuitem.set_attribute_value("use-markup", "true")
      # menuitem.set_attribute_value("use-markup", true)
      # This might change in the future(?), but the string version still works in gtk-4.13.0 (gtk/gtkmenutrackeritem.c)


      if !nfo[:items].nil? and !nfo[:items].empty?
        for k2, item in nfo[:items]
          build_menu(item, menu)
        end
        menuitem.submenu = menu
      end
      o = parent.append_item(menuitem)

    end
  end #end class
end
