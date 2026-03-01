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

      section[:settings].each_with_index do |s, row|
        label = Gtk::Label.new(s[:label])
        label.halign = :start
        label.hexpand = true

        widget = make_widget(s)
        @widgets[s[:key]] = { :widget => widget, :type => s[:type] }

        grid.attach(label, 0, row, 1, 1)
        grid.attach(widget, 1, row, 1, 1)
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
    end
  end

  def save_and_close
    @widgets.each do |key, info|
      val = case info[:type]
            when :bool   then info[:widget].active?
            when :int    then info[:widget].value.to_i
            when :float  then info[:widget].value.to_f
            when :string then info[:widget].text
            end
      set(key, val)
    end
    save_settings_to_file
    gui_refresh_font
    @window.destroy
  end

  def run
    @window.show
  end
end

def show_settings_dialog
  SettingsDialog.new.run
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
