# PopupFormGenerator.new().run
class PopupFormGenerator
  def submit()
    for id, entry in @vals
      @ret[id] = entry.text
    end
    if !@callback.nil?
      @callback.call(@ret)
    end
    @window.destroy
  end

  def initialize(params = nil)
    @ret = {}
    @window = Gtk::Window.new()
    # @window.screen = main_window.screen
    # @window.title = title
    # params = {}
    # params["inputs"] = {}
    # params["inputs"]["search"] = { :label => "Search", :type => :entry }
    # params["inputs"]["replace"] = { :label => "Replace", :type => :entry }
    # params["inputs"]["btn1"] = { :label => "Replace all", :type => :button }
    # params[:callback] = proc { |x| puts "====="; puts x.inspect; puts "=====" }

    @callback = params[:callback]
    @window.title = ""

    frame = Gtk::Frame.new()
    frame.margin_bottom = 8
    frame.margin_top = 8
    frame.margin_end = 8
    frame.margin_start = 8

    @window.set_child(frame)

    # @window.title = params["title"]

    # @callback = params["callback"]

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin_bottom = 8
    vbox.margin_top = 8
    vbox.margin_end = 8
    vbox.margin_start = 8

    frame.set_child(vbox)

    if params.has_key?("title")
      infolabel = Gtk::Label.new
      infolabel.markup = params["title"]
      #TODO:gtk4
      # vbox.pack_start(infolabel, :expand => false, :fill => false, :padding => 0)
      vbox.prepend(infolabel, :expand => false, :fill => false, :padding => 0)
    end

    hbox = Gtk::Box.new(:horizontal, 8)
    @vals = {}
    @default_button = nil

    for id, elem in params["inputs"]
      if elem[:type] == :button
        button = Gtk::Button.new(:label => elem[:label])
        hbox.pack_start(button, :expand => false, :fill => false, :padding => 0)
        if elem[:default_focus] == true
          @default_button = button
        end
        button.signal_connect "clicked" do
          @ret[id] = "submit"
          submit
        end
      elsif elem[:type] == :entry
        label = Gtk::Label.new(elem[:label])
        entry = Gtk::Entry.new
        if elem.has_key?(:initial_text)
          entry.text = elem[:initial_text]
        end
        hbox.pack_start(label, :expand => false, :fill => false, :padding => 0)
        hbox.pack_start(entry, :expand => false, :fill => false, :padding => 0)
        @vals[id] = entry

        press = Gtk::EventControllerKey.new
        press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
        entry.add_controller(press)
        press.signal_connect "key-pressed" do |gesture, keyval, keycode, y|
          if keyval == Gdk::Keyval::KEY_Return
            submit
            true
          elsif keyval == Gdk::Keyval::KEY_Escape
            @window.destroy
            true
          else
            false
          end
        end
      end
    end

    vbox.pack_start(hbox, :expand => false, :fill => false, :padding => 0)

    cancel_button = Gtk::Button.new(:label => "Cancel")
    cancel_button.signal_connect "clicked" do
      @window.destroy
    end
    hbox.pack_start(cancel_button, :expand => false, :fill => false, :padding => 0)
    @cancel_button = cancel_button
    return
  end

  def run
    if !@window.visible?
      @window.show
    else
      @window.destroy
    end
    if !@default_button.nil?
      # @default_button.grab_focus
      # @default_button.set_has_focus(true)
      # @default_button.has_focus = true
      @default_button.focus = true
    end
    @window.set_focus_visible(true)
    @window
  end
end
