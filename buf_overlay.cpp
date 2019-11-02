
#include "editor.h"
#include "globals.h"

extern BufferWidget *c_te;

void Overlay::paintEvent(QPaintEvent *e) {
  int jm_x = 0;
  int jm_y = 0;

  QTextCursor cursor = c_te->textCursor();
  QRect r = c_te->cursorRect(cursor);
  jm_x = r.x() - 6;
  jm_y = r.y() - 7;
  // int cursor_height = r.height();

  if (c_te->cursor_y < 0)
    return;
  // TODO: when outside of viewport

  QSize parentsize = c_te->frameSize();

  int draw_width = c_te->cursor_x + c_te->cursor_width;
  int draw_height = c_te->cursor_y + c_te->cursor_height;
  resize(parentsize); // TODO: resize to parent widget when change
  QPainter p(this);
  // resize(draw_width, draw_height); //TODO: resize to parent widget when change

  p.eraseRect(0, 0, parentsize.rwidth(), parentsize.rheight());
  // p.eraseRect(0,0,draw_width,draw_height);

  if (c_te->overlay_paint_cursor) {
    // printf("Overlay:paintEvent x=%d y=%d w=%d h=%d\n",c_te->cursor_x, c_te->cursor_y,
    // c_te->cursor_width,c_te->cursor_height);
    QColor cursor_color = new QColor("#839496");
    p.fillRect(c_te->cursor_x, c_te->cursor_y, c_te->cursor_width, c_te->cursor_height,
               QColor("#839496"));
  } else {
    // printf("Overlay:paintEvent. overlay_paint_cursor=false\n");
  }

  VALUE paint_stack = rb_eval_string("vma.paint_stack");
  
  for (int i=0; i< RARRAY_LEN(paint_stack); i++) {
    //TODO: Cache drawing so don't need to redo?
    // VALUE p = rb_ary_shift(paint_stack);
    VALUE p = rb_ary_entry(paint_stack,i);
    
    int draw_type = NUM2INT(rb_ary_entry(p, 0));
    int x_coord = NUM2INT(rb_ary_entry(p, 1));
    int y_coord = NUM2INT(rb_ary_entry(p, 2));
    VALUE c = rb_ary_entry(p, 3);
    draw_text(x_coord, y_coord, StringValueCStr(c));
  }

  
}

int Overlay::draw_text(int x, int y, char *text) {

  QPainter p(this);
  p.setPen(QColor("#ffff2222"));
  QFont font = p.font();
  font.setPointSize(c_te->fnt.pointSize()-1);
  font.setWeight(QFont::DemiBold);
  QFontMetrics fm(font);
  p.setFont(font);
  QRect qr = fm.tightBoundingRect(text);
  int padding = 2;
  int y_align = -0;
  int x_align = -2;
  // int font_height = fm.xHeight();
  int font_height = qr.height();
  p.fillRect(x + x_align - padding, y + y_align - padding, qr.width() + 2 * padding,
             font_height + 2 * padding, QColor("#77000000"));
  p.drawText(x + x_align, y + y_align + font_height, text);
}

Overlay::Overlay(QWidget *parent = 0) : QFrame(parent)
   {
    setAttribute(Qt::WA_TransparentForMouseEvents);
    setFrameStyle(QFrame::NoFrame);
    // Autofill with transparent color
    setAutoFillBackground(true);
    setStyleSheet("background-color: rgba(255, 255, 255, 0);");
    // 2DEBUG: setStyleSheet("background-color: rgba(255, 255, 255, 10);");
  }





