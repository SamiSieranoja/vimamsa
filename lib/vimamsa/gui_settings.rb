SETTINGS_DEFS = [
  {
    :label => "Tab / Indent",
    :settings => [
      { :key => [:tab, :width], :label => "Tab width", :type => :int, :min => 1, :max => 16, :step => 1 },
      { :key => [:tab, :to_spaces_default], :label => "Use spaces instead of tabs (default)", :type => :bool },
      { :key => [:indent_based_on_last_line], :label => "Auto-indent based on last line", :type => :bool },
    ],
  },
  {
    :label => "Font",
    :settings => [
      { :key => [:font, :family], :label => "Font family", :type => :string },
      { :key => [:font, :size], :label => "Font size (pt)", :type => :int, :min => 4, :max => 72, :step => 1 },
    ],
  },
  {
    :label => "Appearance",
    :settings => [
      { :key => [:match, :highlight, :color], :label => "Search highlight color", :type => :string },
      { :key => [:kbd, :show_prev_action], :label => "Show previous action in toolbar", :type => :bool },
    ],
  },
  {
    :label => "Behavior",
    :settings => [
      { :key => [:lsp, :enabled], :label => "Enable LSP (Language Server)", :type => :bool },
      { :key => [:experimental], :label => "Enable experimental features", :type => :bool },
      { :key => [:macro, :animation_delay], :label => "Macro animation delay (sec)", :type => :float, :min => 0.0, :max => 2.0, :step => 0.0001 },
      { :key => [:paste, :cursor_at_start], :label => "Leave cursor at start of pasted text", :type => :bool },
      { :key => [:style_scheme], :label => "Color scheme", :type => :select,
        :options => proc {
          ssm = GtkSource::StyleSchemeManager.new
          ssm.set_search_path(ssm.search_path << ppath("styles/"))
          ssm.scheme_ids.reject { |id| id == VIMAMSA_OVERLAY_SCHEME_ID }.sort
        } },
    ],
  },
  {
    :label => "Files",
    :settings => [
      { :key => ["search_dirs"], :label => "Search directories (one per line)", :type => :string_list },
    ],
  },
]

class SettingsDialog
  def initialize
    @widgets = {}
    @window = Gtk::Window.new
    @window.set_transient_for($vmag.window) if $vmag&.window
    @window.modal = true
    @window.title = "Preferences"
    @window.default_width = 500

    outer = Gtk::Box.new(:vertical, 12)
    # outer.margin = 16
    @window.set_child(outer)

    notebook = Gtk::Notebook.new
    outer.append(notebook)

    SETTINGS_DEFS.each do |section|
      grid = Gtk::Grid.new
      grid.row_spacing = 10
      grid.column_spacing = 16
      grid.margin_top = 12
      grid.margin_bottom = 12
      grid.margin_start = 12
      grid.margin_end = 12

      grid_row = 0
      section[:settings].each do |s|
        label = Gtk::Label.new(s[:label])
        label.halign = :start
        label.hexpand = true

        if s[:type] == :string_list
          # Label spans both columns; editor on the next row spanning both columns
          grid.attach(label, 0, grid_row, 2, 1)
          grid_row += 1
          cur = get(s[:key])
          container, get_value = build_string_list_editor(cur.is_a?(Array) ? cur : [])
          @widgets[s[:key]] = { :widget => container, :type => s[:type], :get_value => get_value }
          grid.attach(container, 0, grid_row, 2, 1)
        else
          widget = make_widget(s)
          @widgets[s[:key]] = { :widget => widget, :type => s[:type] }
          grid.attach(label, 0, grid_row, 1, 1)
          grid.attach(widget, 1, grid_row, 1, 1)
        end
        grid_row += 1
      end

      notebook.append_page(grid, Gtk::Label.new(section[:label]))
    end

    hbox = Gtk::Box.new(:horizontal, 8)
    hbox.halign = :end

    cancel_btn = Gtk::Button.new(:label => "Cancel")
    save_btn = Gtk::Button.new(:label => "Save")
    cancel_btn.signal_connect("clicked") { @window.destroy }
    save_btn.signal_connect("clicked") { save_and_close }

    hbox.append(cancel_btn)
    hbox.append(save_btn)
    outer.append(hbox)

    press = Gtk::EventControllerKey.new
    press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
    @window.add_controller(press)
    press.signal_connect("key-pressed") do |_g, keyval, _kc, _y|
      if keyval == Gdk::Keyval::KEY_Escape
        @window.destroy
        true
      else
        false
      end
    end
  end

  def make_widget(s)
    cur = get(s[:key])
    case s[:type]
    when :bool
      w = Gtk::Switch.new
      w.active = cur == true
      w.valign = :center
      w
    when :int
      adj = Gtk::Adjustment.new(cur.to_f, s[:min].to_f, s[:max].to_f, s[:step].to_f, s[:step].to_f * 5, 0.0)
      Gtk::SpinButton.new(adj, s[:step].to_f, 0)
    when :float
      adj = Gtk::Adjustment.new(cur.to_f, s[:min].to_f, s[:max].to_f, s[:step].to_f, s[:step].to_f * 5, 0.0)
      digits = s[:step].to_s.split(".").last.to_s.length
      digits = 2 if digits < 2
      Gtk::SpinButton.new(adj, s[:step].to_f, digits)
    when :string
      w = Gtk::Entry.new
      w.text = cur.to_s
      w
    when :select
      options = s[:options].is_a?(Proc) ? s[:options].call : s[:options]
      cur = cnf_get(s[:key]).to_s
      string_list = Gtk::StringList.new(options)
      w = Gtk::DropDown.new(string_list, nil)
      w.selected = [options.index(cur) || 0, 0].max
      w
    end
  end

  def build_string_list_editor(paths)
    store = Gtk::ListStore.new(String)
    paths.each { |p| store.append[0] = p }

    tv = Gtk::TreeView.new(store)
    tv.headers_visible = false
    renderer = Gtk::CellRendererText.new
    renderer.ellipsize = Pango::EllipsizeMode::START
    col = Gtk::TreeViewColumn.new("", renderer, text: 0)
    col.expand = true
    tv.append_column(col)

    sw = Gtk::ScrolledWindow.new
    sw.set_policy(:automatic, :automatic)
    sw.set_child(tv)
    sw.set_size_request(-1, 120)
    sw.vexpand = true

    add_btn = Gtk::Button.new(label: "Add…")
    add_btn.signal_connect("clicked") do
      chooser = Gtk::FileChooserDialog.new(
        :title => "Select directory",
        :action => :select_folder,
        :buttons => [["Select", :accept], ["Cancel", :cancel]],
      )
      chooser.set_transient_for(@window)
      chooser.modal = true
      chooser.signal_connect("response") do |dlg, resp|
        if resp == Gtk::ResponseType::ACCEPT
          iter = store.append
          iter[0] = dlg.file.path
        end
        dlg.destroy
      end
      chooser.show
    end

    remove_btn = Gtk::Button.new(label: "Remove")
    remove_btn.signal_connect("clicked") do
      sel = tv.selection.selected
      store.remove(sel) if sel
    end

    btn_box = Gtk::Box.new(:horizontal, 6)
    btn_box.append(add_btn)
    btn_box.append(remove_btn)

    container = Gtk::Box.new(:vertical, 4)
    container.vexpand = true
    container.append(sw)
    container.append(btn_box)

    get_value = proc {
      result = []
      store.each { |_m, _path, iter| result << iter[0] }
      result
    }

    [container, get_value]
  end

  def save_and_close
    @widgets.each do |key, info|
      val = case info[:type]
            when :bool        then info[:widget].active?
            when :int         then info[:widget].value.to_i
            when :float       then info[:widget].value.to_f
            when :string      then info[:widget].text
            when :string_list then info[:get_value].call
            when :select      then info[:widget].selected_item&.string
            end
      cnf_set(key, val)
    end
    save_settings_to_file
    gui_refresh_font
    gui_refresh_style_scheme
    @window.destroy
  end

  def run
    @window.show
  end
end

def show_settings_dialog
  SettingsDialog.new.run
end

VIMAMSA_OVERLAY_SCHEME_ID = "vimamsa_overlay"

# Generate a GtkSourceView style scheme that inherits from base_scheme_id and
# overlays Vimamsa-specific styles (headings, hyperlinks, bold) on top.
# Written to styles/_vimamsa_overlay.xml and reloaded on each call.
def generate_vimamsa_overlay(base_scheme_id)
  xml = <<~XML
    <?xml version="1.0"?>
    <style-scheme id="#{VIMAMSA_OVERLAY_SCHEME_ID}" name="#{VIMAMSA_OVERLAY_SCHEME_ID}" version="1.0" parent-scheme="#{base_scheme_id}">
      <style name="def:title"     scale="2.0"   bold="true"/>
      <style name="def:hyperlink" foreground="#4FC3F7" bold="true"/>
      <style name="def:heading0"  scale="2.0"   bold="true"/>
      <style name="def:heading1"  scale="1.75"  bold="true"/>
      <style name="def:heading2"  scale="1.5"   bold="true"/>
      <style name="def:heading3"  scale="1.25"  bold="true"/>
      <style name="def:heading4"  scale="1.175" bold="true"/>
      <style name="def:heading5"  scale="1.1"   bold="true"/>
      <style name="def:heading6"  scale="1.0"   bold="true"/>
      <style name="def:bold"      bold="true"/>
    </style-scheme>
  XML
  IO.write(ppath("styles/_vimamsa_overlay.xml"), xml)
end

# Build a StyleSchemeManager with the project styles dir appended,
# apply the overlay on top of the user's chosen base scheme,
# and return the overlay scheme object.
def load_vimamsa_scheme
  base_id = cnf.style_scheme! || "molokai_edit"
  generate_vimamsa_overlay(base_id)
  ssm = GtkSource::StyleSchemeManager.new
  ssm.set_search_path(ssm.search_path << ppath("styles/"))
  ssm.get_scheme(VIMAMSA_OVERLAY_SCHEME_ID)
end

# Returns true if the given GtkSource::StyleScheme has a light background.
# Reads the background color of the "text" style and computes relative luminance.
def scheme_is_light?(sty)
  text_style = sty.get_style("text")
  return false if text_style.nil?
  bg = text_style.background
  return false if bg.nil? || !bg.start_with?("#")
  hex = bg.delete("#")
  hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3
  return false unless hex.length == 6
  r = hex[0, 2].to_i(16) / 255.0
  g = hex[2, 2].to_i(16) / 255.0
  b = hex[4, 2].to_i(16) / 255.0
  luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
  luminance > 0.5
end

# Apply dark/light GTK preference to match the given style scheme.
def gui_apply_color_mode(sty)
  Gtk::Settings.default.gtk_application_prefer_dark_theme = !scheme_is_light?(sty)
end

def gui_refresh_style_scheme
  return unless $vmag
  sty = load_vimamsa_scheme
  return if sty.nil?
  gui_apply_color_mode(sty)
  for _k, view in $vmag.buffers
    view.buffer.style_scheme = sty
  end
end

def gui_refresh_font
  return unless $vmag
  provider = Gtk::CssProvider.new
  provider.load(data: "textview { font-family: #{get(cnf.font.family)}; font-size: #{get(cnf.font.size)}pt; }")
  for _k, window in $vmag.windows
    view = window[:sw].child
    next if view.nil?
    view.style_context.add_provider(provider)
  end
end
