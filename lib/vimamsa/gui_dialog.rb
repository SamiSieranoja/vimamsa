module Gui
  def self.confirm(title, callback)
    params = {}
    params["title"] = title
    params["inputs"] = {}
    params["inputs"]["yes_btn"] = { :label => "Yes", :type => :button, :default_focus => true }
    params[:callback] = callback
    PopupFormGenerator.new(params).run
  end
end

module Gtk
  class Frame
    def margin=(a)
      self.margin_bottom = a
      self.margin_top = a
      self.margin_end = a
      self.margin_start = a
    end
  end

  class Box
    def margin=(a)
      self.margin_bottom = a
      self.margin_top = a
      self.margin_end = a
      self.margin_start = a
    end
  end
end

def set_margin_all(widget, m)
  widget.margin_bottom = m
  widget.margin_top = m
  widget.margin_end = m
  widget.margin_start = m
end

class OneInputAction
  def initialize(main_window, title, field_label, button_title, callback, opt = {})
    @window = Gtk::Window.new()
    # @window.screen = main_window.screen
    # @window.title = title
    @window.title = ""

    frame = Gtk::Frame.new()
    # frame.margin = 20
    @window.set_child(frame)

    infolabel = Gtk::Label.new
    infolabel.markup = title

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin = 10
    frame.set_child(vbox)

    hbox = Gtk::Box.new(:horizontal, 8)
    # @window.add(hbox)
    vbox.pack_end(infolabel, :expand => false, :fill => false, :padding => 0)
    vbox.pack_end(hbox, :expand => false, :fill => false, :padding => 0)

    button = Gtk::Button.new(:label => button_title)
    cancel_button = Gtk::Button.new(:label => "Cancel")

    label = Gtk::Label.new(field_label)

    @entry1 = Gtk::Entry.new

    if opt[:hide]
      @entry1.visibility = false
    end

    button.signal_connect "clicked" do
      callback.call(@entry1.text)
      @window.destroy
    end

    cancel_button.signal_connect "clicked" do
      @window.destroy
    end

    press = Gtk::EventControllerKey.new
    press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
    @window.add_controller(press)
    press.signal_connect "key-pressed" do |gesture, keyval, keycode, y|
      if keyval == Gdk::Keyval::KEY_Return
        callback.call(@entry1.text)
        @window.destroy
        true
      elsif keyval == Gdk::Keyval::KEY_Escape
        @window.destroy
        true
      else
        false
      end
    end

    hbox.pack_end(label, :expand => false, :fill => false, :padding => 0)
    hbox.pack_end(@entry1, :expand => false, :fill => false, :padding => 0)
    hbox.pack_end(button, :expand => false, :fill => false, :padding => 0)
    hbox.pack_end(cancel_button, :expand => false, :fill => false, :padding => 0)
    return
  end

  def run
    if !@window.visible?
      @window.show
    else
      @window.destroy
    end
    @window
  end
end
