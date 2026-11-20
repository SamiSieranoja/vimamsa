module Vimamsa
  class Menu
    def add_to_menu(_mpath, x)
      # If no menu label provided, take from the action definition
      if !x[:action].nil? and x[:label].nil?
        x[:label] = vma.actions[x[:action]].method_name
      end

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
      add_to_menu "File.Close", { :label => "Close file", :action => :close_current_buffer }

      add_to_menu "File.Restart", { :label => "Restart (reload config and files)", :action => "app.restart" }
      add_to_menu "File.Quit", { :label => "Quit", :action => "app.quit" }

      add_to_menu "Edit.Undo", { :label => "Undo edit", :action => "undo.last" }
      add_to_menu "Edit.Redo", { :label => "Redo edit", :action => "undo.redo" }
      add_to_menu "Edit.SearchReplace", { :label => "Search and replace", :action => "search.replace" }
      add_to_menu "Edit.Find", { :label => "Find", :action => "search.buf" }
      add_to_menu "Edit.ToggleAutocomplete", { :label => "Toggle autocomplete", :action => "edit.complete.toggle" }

      # add_to_menu "Edit.StartCompletion", { :label => "StartCompletion", :action => :start_autocomplete }
      # add_to_menu "Edit.ShowCompletion", { :label => "ShowCompletion", :action => :show_autocomplete }

      add_to_menu "Settings.Preferences", { :label => "Preferences...", :action => "app.settings" }
      add_to_menu "Settings.Customize", { :action => "app.customrb.edit" }
      add_to_menu "Settings.ReloadCustom", { :action => "app.customrb.reload" }

      add_to_menu "Actions.SearchForActions", { :label => "Search for Actions", :action => "search.actions" }

      add_to_menu "Actions.Grep", { :label => "Grep lines", :action => "grep.buf" }

      add_to_menu "Actions.FileHistoryFinder", { :label => "Search files in history", :action => :gui_file_history_finder }

      add_to_menu "Actions.experimental.Diff", { :label => "Show Diff of\nunsaved changes", :action => :diff_buffer }
      add_to_menu "Actions.experimental.GitDiff", { :label => "Show git diff", :action => :git_diff_buffer }
      add_to_menu "Actions.experimental.GitDiffW", { :label => "Show git diff -w (repo)", :action => :git_diff_w }

      add_to_menu "Actions.experimental.PrintBufferAccessList", { :label => "Print buffers by access time", :action => "debug.buf.access" }
      add_to_menu "Actions.experimental.EnableDebug", { :label => "Enable debug", :action => "debug.on" }
      add_to_menu "Actions.experimental.DisableDebug", { :label => "Disable debug", :action => "debug.off" }
      add_to_menu "Actions.experimental.ShowImages", { :label => "Show images ⟦img:path⟧", :action => :show_images }
      
      add_to_menu "Actions.experimental.ShowImages", { :action => "debug.eval.sel" }
      

      add_to_menu "Actions.debug.dumpkbd", { :label => "Dump kbd state", :action => "debug.kbd" }
      add_to_menu "Actions.debug.ToggleKbdPassthrough", { :label => "Toggle kbd event passthrough", :action => "mode.passthrough.toggle" }

      add_to_menu "View.BufferManager", { :label => "Show open files", :action => :start_buf_manager }
      add_to_menu "View.Bookmarks", { :label => "Show bookmarks", :action => :bookmark_list }
      add_to_menu "Edit.AddBookmark", { :label => "Add bookmark", :action => :bookmark_add }
      add_to_menu "View.SelectLanguage", { :label => "Set buffer language...", :action => :select_buffer_language }
      add_to_menu "View.TwoColumn", { :label => "Toggle two column mode", :action => :toggle_two_column }
      add_to_menu "View.FilePanel", { :label => "Toggle file panel", :action => :toggle_file_panel }
      add_to_menu "View.FuncPanel", { :label => "Toggle function panel (LSP)", :action => :toggle_func_panel }
      add_to_menu "View.KeyLog", { :label => "Toggle key log panel", :action => :toggle_keylog_panel }
      add_to_menu "View.MsgHistory", { :label => "Message history", :action => "help.messages" }

      add_to_menu "Actions.EncryptFile", { :label => "Encrypt file", :action => :encrypt_file }
      add_to_menu "Actions.LspRestart", { :label => "Restart LSP server", :action => :lsp_restart }
      add_to_menu "Help.KeyBindings", { :label => "Show key bindings", :action => "help.keys" }
      add_to_menu "Help.VimConflicts", { :label => "Vim keys that differ in vimlike", :action => "help.vim_conflicts" }
      add_to_menu "Help.InstallDemo", { :action => "app.demo" }

      #TODO: "edit.indent.buf"

      # add_to_menu "Actions.Ack", { :label => "source code search (Ack)", :action => "ack.search" }

    end

    def initialize(menubar, _app)
      @app = _app
      @nfo = {}
      @menubar = menubar
      # Gio::Menu for the "Modules" top-level menu, created on first use.
      @module_menu = nil
      # Ordered list of action symbols in @module_menu, used to find removal positions.
      @module_actions = []

      add_menu_items

      for k, v in @nfo
        build_menu(v, menubar)
      end
    end

    # Markup hint (e.g. "   [C] , d") showing the key binding for an action,
    # or "" if the action is unbound. Shared by regular and module menu items.
    def kbd_hint(action)
      for mode_str in ["C", "V"]
        c_kbd = vma.kbd.act_bindings[mode_str][action]
        if c_kbd.class == String
          return "   <span foreground='#888888'><span weight='bold'>[#{mode_str}]</span> #{c_kbd}</span>"
        end
      end
      return ""
    end

    # Add a menu item under the top-level "Modules" menu.
    # Creates the Modules menu the first time it is called.
    def add_module_action(action, label)
      if @module_menu.nil?
        @module_menu = Gio::Menu.new
        modules_item = Gio::MenuItem.new("Modules", nil)
        modules_item.submenu = @module_menu
        @menubar.append_item(modules_item)
      end

      act = Gio::SimpleAction.new(action.to_s)
      @app.add_action(act)
      act.signal_connect("activate") { call_action(action) }

      item = Gio::MenuItem.new(label + kbd_hint(action), "app.#{action}")
      item.set_attribute_value("use-markup", "true")
      @module_menu.append_item(item)
      @module_actions << action
    end

    # Remove a previously added module menu item.
    def remove_module_action(action)
      idx = @module_actions.index(action)
      return if idx.nil?
      @module_menu.remove(idx)
      @module_actions.delete_at(idx)
      @app.remove_action(action.to_s)
    end

    # Return true if action was added via add_module_action and not yet removed.
    def module_action?(action)
      @module_actions.include?(action)
    end

    def build_menu(nfo, parent)
      menu = Gio::Menu.new
      if nfo[:action]
        label_str = nfo[:label] + kbd_hint(nfo[:action])
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
