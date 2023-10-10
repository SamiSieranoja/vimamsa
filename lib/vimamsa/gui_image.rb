# Following this example:
# https://gabmus.org/posts/create_an_auto-resizing_image_widget_with_gtk3_and_python/
class ResizableImage < Gtk::DrawingArea
  attr_accessor :fpath, :pixbuf, :oldimg, :draw_image, :view

  def initialize(fpath, view)
    @fpath = fpath
    @pixbuf = GdkPixbuf::Pixbuf.new(:file => fpath)
    @oldimg = @pixbuf
    @draw_image = @pixbuf
    @view = view

    super()
  end

  # Scale to fit window width
  def scale_image()
    pb = @pixbuf
    view = @view
    if view.visible_rect.width > 0
      imglimit = view.visible_rect.width - 50
    else
      imglimit = 500
    end

    if @oldimg.width > imglimit or @oldimg.width < imglimit - 10
      nwidth = imglimit
      nwidth = pb.width if pb.width < imglimit
      nheight = (pb.height * (nwidth.to_f / pb.width)).to_i
      # Ripl.start :binding => binding

      pb = pb.scale_simple(nwidth, nheight, GdkPixbuf::InterpType::HYPER)
    else
      pb = @oldimg
    end
    @draw_image = pb
    @oldimg = pb
    #TODO: Should be better way to compensate for the gutter
    self.set_size_request(pb.width+@view.gutter_width, pb.height)
  end

  def do_draw(da, cr)
    # puts @fpath
    # Ripl.start :binding => binding

    cr.set_source_pixbuf(@draw_image, @view.gutter_width, 0)
    cr.paint
  end
end
