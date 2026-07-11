
module Vimamsa
module Gui
  def self.confirm(title, callback, param: nil)
    params = {}
    params["title"] = title
    params["inputs"] = {}
    params["inputs"]["yes_btn"] = { :label => "Yes", :type => :button, :default_focus => true }
    params[:callback] = callback
    PopupFormGenerator.new(params).run
  end
end

module ::Gtk
  class Widget
    def margin=(a)
      self.margin_bottom = a
      self.margin_top = a
      self.margin_end = a
      self.margin_start = a
    end
  end
end

# Create a popup Gtk::Window with the shared dialog setup: "vma-dialog" CSS
# class, transient for the main window, modal by default.
def make_modal_window(title = "", modal: true)
  w = Gtk::Window.new
  w.add_css_class("vma-dialog")
  w.set_transient_for($vmag.window) if $vmag&.window
  w.modal = modal
  w.title = title
  w
end

# Attach a CAPTURE-phase key controller to widget: Return calls submit,
# Escape calls escape (each only when given). Any other key is offered to the
# optional block with its keyval; a truthy result marks the key as handled.
def on_submit_escape(widget, submit: nil, escape: nil, &extra)
  press = Gtk::EventControllerKey.new
  press.set_propagation_phase(Gtk::PropagationPhase::CAPTURE)
  widget.add_controller(press)
  press.signal_connect "key-pressed" do |_gesture, keyval, _keycode, _state|
    if submit && keyval == Gdk::Keyval::KEY_Return
      submit.call
      true
    elsif escape && keyval == Gdk::Keyval::KEY_Escape
      escape.call
      true
    else
      (extra && extra.call(keyval)) ? true : false
    end
  end
  press
end

# Build the common list-panel widget pair: a headerless TreeView over store
# with a single ellipsized, expanding text column, inside a
# ScrolledWindow(hpolicy, :automatic). The optional block is invoked with the
# iter of an activated row. Returns [tree, scrolled_window].
def build_list_tree(store, ellipsize: Pango::EllipsizeMode::END, text_col: 0,
                    single_click: true, hpolicy: :never)
  tree = Gtk::TreeView.new(store)
  tree.headers_visible = false
  tree.activate_on_single_click = single_click
  renderer = Gtk::CellRendererText.new
  renderer.ellipsize = ellipsize
  col = Gtk::TreeViewColumn.new("", renderer, text: text_col)
  col.expand = true
  tree.append_column(col)
  if block_given?
    tree.signal_connect("row-activated") do |_tv, path, _col|
      iter = store.get_iter(path)
      yield(iter) if iter
    end
  end
  sw = Gtk::ScrolledWindow.new
  sw.set_policy(hpolicy, :automatic)
  sw.set_child(tree)
  [tree, sw]
end

# Shared #run for toggle-style popups: show the window if hidden, destroy it
# if already visible.
module PopupRun
  def run
    if !@window.visible?
      @window.show
    else
      @window.destroy
    end
    @window
  end
end

class OneInputAction
  include PopupRun

  def initialize(main_window, title, field_label, button_title, callback, opt = {})
    @window = make_modal_window()
    # @window.width_request = 800
    # @window.hexpand = false

    frame = Gtk::Frame.new()
    # frame.margin = 20
    @window.set_child(frame)

    infolabel = Gtk::Label.new
    infolabel.markup = title
    infolabel.wrap = true
    infolabel.max_width_chars = 80


    vbox = Gtk::Box.new(:vertical, 8)
    vbox.margin = 10
    frame.set_child(vbox)

    hbox = Gtk::Box.new(:horizontal, 8)
    vbox.append(infolabel)
    vbox.append(hbox)

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

    @cancel_button = cancel_button
    cancel_button.signal_connect "clicked" do
      @window.destroy
    end

    on_submit_escape(@window,
                     submit: proc {
                       callback.call(@entry1.text) if !@cancel_button.has_focus?
                       @window.destroy
                     },
                     escape: proc { @window.destroy })

    hbox.append(label)
    hbox.append(@entry1)
    hbox.append(button)
    hbox.append(cancel_button)
    return
  end
end
end # module Vimamsa
