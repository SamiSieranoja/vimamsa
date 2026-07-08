
module Vimamsa
# PopupFormGenerator.new().run
class PopupFormGenerator
  # Modal popups are serialized: only one is visible at a time. Presenting two
  # transient modal windows together (e.g. the session-restore dialog and a
  # startup file's autosave dialog at startup) makes them grab input from each
  # other and get stuck, so queue any popup requested while another is active
  # and show it once the active one closes.
  @@popup_active = nil
  @@popup_queue = []

  # Present the next queued popup, if any. Called when the active popup closes.
  def self.advance_popup_queue
    @@popup_active = nil
    nxt = @@popup_queue.shift
    nxt&.present_now
  end

  # Test/utility hook: forget any queued/active popups.
  def self.reset_popup_queue
    @@popup_active = nil
    @@popup_queue = []
  end

  def self.popup_active? = !@@popup_active.nil?
  def self.popup_queue_size = @@popup_queue.size

  def submit()
    for id, entry in @vals
      @ret[id] = entry.text
    end
    if !@callback.nil?
      @callback.call(@ret)
    end
    close
  end

  # Close this popup and present the next queued one, if any. All close paths
  # (submit, cancel, escape, window close) route through here. GTK4 has no
  # widget "destroy" signal to hook, so the queue is advanced explicitly.
  def close
    @window.destroy
    PopupFormGenerator.advance_popup_queue if @@popup_active.equal?(self)
  end

  def initialize(params = nil)
    @ret = {}
    @window = Gtk::Window.new()
    @window.add_css_class("vma-dialog")
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
    @window.set_transient_for($vmag.window) if $vmag&.window
    @window.modal = true
    # Window manager close (title-bar X): advance the queue too, then let GTK
    # destroy the window (return false). Programmatic closes go through #close.
    @window.signal_connect("close-request") do
      PopupFormGenerator.advance_popup_queue if @@popup_active.equal?(self)
      false
    end

    frame = Gtk::Frame.new()
    frame.margin = 8

    @window.set_child(frame)

    # @window.title = params["title"]

    # @callback = params["callback"]

    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin = 8

    frame.set_child(vbox)

    if params.has_key?("title")
      infolabel = Gtk::Label.new
      infolabel.markup = params["title"]
      vbox.append(infolabel)
    end

    hbox = Gtk::Box.new(:horizontal, 8)
    @vals = {}
    @default_button = nil

    params["inputs"].each do |id, elem|
      if elem[:type] == :button
        button = Gtk::Button.new(:label => elem[:label])
        hbox.append(button)
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
        hbox.append(label)
        hbox.append(entry)
        @vals[id] = entry

        press = Gtk::EventControllerKey.new
        press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
        entry.add_controller(press)
        press.signal_connect "key-pressed" do |gesture, keyval, keycode, y|
          if keyval == Gdk::Keyval::KEY_Return
            submit
            true
          elsif keyval == Gdk::Keyval::KEY_Escape
            close
            true
          else
            false
          end
        end
      end
    end  # each

    vbox.append(hbox)

    cancel_button = Gtk::Button.new(:label => "Cancel")
    cancel_button.signal_connect "clicked" do
      close
    end
    hbox.append(cancel_button)
    @cancel_button = cancel_button
    return
  end

  def run
    # If another popup is already showing, queue this one; it is presented when
    # the active popup closes (see advance_popup_queue).
    if @@popup_active && !@@popup_active.instance_variable_get(:@window).destroyed?
      @@popup_queue << self
      return @window
    end
    present_now
  end

  # Actually show the window now and mark it as the active popup.
  def present_now
    @@popup_active = self
    @window.present
    if !@default_button.nil?
      @default_button.grab_focus
    end
    @window.set_focus_visible(true)
    @window
  end
end
end # module Vimamsa
