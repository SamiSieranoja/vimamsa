
#include "buffer_widget.h"
#include "globals.h"

#include <QtWidgets>

void BufferWidget::keyReleaseEvent(QKeyEvent *e) {
  handleKeyEvent(e);
  return;
}

void BufferWidget::dragEnterEvent(QDragEnterEvent *event) {
  // qDebug() << "dragEnterEvent:"
  // << "\n";
  // qDebug() << event << "\n";

  event->accept();
}

void BufferWidget::dragMoveEvent(QDragMoveEvent *event) {
  // qDebug() << "dragEnterEvent:"
  // << "\n";
  // qDebug() << event << "\n";

  event->accept();
}

void BufferWidget::dropEvent(QDropEvent *event) {

  qDebug() << "dropEvent:"
           << "\n";
  qDebug() << event << "\n";

  if (event->mimeData()->hasFormat("text/uri-list")) {
    QList<QUrl> urls = event->mimeData()->urls();
    qDebug() << urls << "\n";

    if (!urls.isEmpty()) {
      // QString fileName = urls.first().toLocalFile();
      QString fileName = urls.first().toLocalFile();
      VALUE rbfname = qstring_to_ruby(fileName);
      rb_funcall(NULL, rb_intern("handle_drag_and_drop"), 1, rbfname);
    }
  }
}

void BufferWidget::mouseMoveEvent(QMouseEvent *event) {

  if (event->buttons() & Qt::LeftButton) {
    QTextCursor cursor = this->cursorForPosition(event->pos());
    qDebug() << "move event:" << event << "\n";
    cursor_pos = cursor.position();
    rb_funcall(NULL, rb_intern("set_cursor_pos"), 1, INT2NUM(cursor_pos));
    rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("mouse_leftbtn_move"), rb_str_new2(""));
    drawTextCursor();
  }
}

void BufferWidget::mouseReleaseEvent(QMouseEvent *event) {

  if (event->buttons() & Qt::LeftButton) {
    QTextCursor cursor = this->cursorForPosition(event->pos());

    cursor_pos = cursor.position();
    rb_funcall(NULL, rb_intern("set_cursor_pos"), 1, INT2NUM(cursor_pos));
    rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("mouse_leftbtn_release"), rb_str_new2(""));
    drawTextCursor();
    update(); // TODO: needed?
  }
}

void BufferWidget::mousePressEvent(QMouseEvent *event) {

  if (event->buttons() & Qt::RightButton) {
  }

  if (event->buttons() & Qt::LeftButton) {
    QTextCursor cursor = this->cursorForPosition(event->pos());
    // qDebug() << "New pos:" << cursor.position() << "\n";

    cursor_pos = cursor.position();
    rb_funcall(NULL, rb_intern("set_cursor_pos"), 1, INT2NUM(cursor_pos));
    rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("mouse_leftbtn_press"), rb_str_new2(""));
    drawTextCursor();
    update(); // TODO: needed?
  }
}

#ifdef DISABLED
void BufferWidget::paintEvent(QPaintEvent *e) {

  // Q_D(QTextEdit);
  // QPainter p(d->viewport);
  // d->paint(&p, e);
  // TODO: gives error if trying to draw after calling superclass paintEvent
  // return;
  QTextEdit::paintEvent(e);
  QRect r = cursorRect();
  cursor_x = r.x();
  cursor_y = r.y();
  cursor_height = r.height();

  // TODO:
  if (lineNumberArea) {
    lineNumberArea->repaint();
  }
}
#endif

void BufferWidget::handleKeyEvent(QKeyEvent *e) { processKeyEvent(e); }

int BufferWidget::runHighlightBatch() {
  int i = 0;
  // c_te->hl->rehighlightBlock(curblock);
  while (curblock != endblock && curblock.isValid()) {
    continue_hl_batch = 1;
    c_te->hl->rehighlightBlock(curblock);
    curblock = curblock.next();
    i++;
    if (i > 30) {
      break;
    }
  }
  if (curblock == endblock || !curblock.isValid()) {
    continue_hl_batch = 0;
    // Reached the end
    // curblock = 0;
  }
  c_te->hl->rb_highlight = NULL;

  return i;
}

int BufferWidget::processHighlights() {

  if (c_te->hl == NULL) {
    return;
  }
  // If buffer syntax parsing is happening in separate thread,
  // wait til it has finnished
  if (RTEST(rb_eval_string("$buffer.is_parsing_syntax"))) {
    continue_hl_batch = 0;
    return;
  }

  if (RTEST(rb_eval_string("$buffer.qt_reset_highlight"))) {
    rb_eval_string("$buffer.qt_reset_highlight=false");
    continue_hl_batch = 0;
  }

  c_te->hl->rb_highlight = rb_eval_string("$buffer.highlights");
  // Continuing from previous batch
  if (continue_hl_batch) {
    runHighlightBatch();
    return;
  }

  while (RTEST(rb_eval_string("$cnf[:syntax_highlight]")) &&
         RTEST(rb_eval_string("!$buffer.hl_queue.empty?"))) {
    int startpos = NUM2INT(rb_eval_string("$buffer.hl_queue[0][0]"));
    int endpos = NUM2INT(rb_eval_string("$buffer.hl_queue[0][1]"));
    printf("HLqueue not empty:%d %d\n", startpos, endpos);
    rb_eval_string("$buffer.hl_queue.delete_at(0)");

    // QTextBlock startblock = c_te->document()->findBlock(startpos);
    // QTextBlock endblock = c_te->document()->findBlock(endpos);
    // QTextBlock curblock = startblock;
    startblock = c_te->document()->findBlock(startpos);
    endblock = c_te->document()->findBlock(endpos);
    curblock = startblock;
    runHighlightBatch();
    // c_te->hl->rehighlightBlock(startblock);
    // while (curblock != endblock && curblock.isValid()) {
    // curblock = curblock.next();
    // c_te->hl->rehighlightBlock(curblock);
    // }
  }
}

void BufferWidget::processKeyEvent(QKeyEvent *e) {

  QByteArray ba;
  const char *c_str2;

  VALUE rb_event;
  VALUE handle_key_event = rb_intern("handle_key_event");

  // qDebug() << "nativeScanCode:" << e->nativeScanCode() << endl;
  // qDebug() << "nativeVirtualKey:" << e->nativeVirtualKey() << endl;

  QString event_text = e->text();
  ba = e->text().toLocal8Bit();
  c_str2 = ba.data();

  rb_event = rb_ary_new3(5, INT2NUM(e->key()), INT2NUM(e->type()), rb_str_new2(c_str2),
                         rb_str_new2(c_str2), INT2NUM(e->modifiers()));

  rb_funcall(NULL, handle_key_event, 1, rb_event);
  drawTextCursor();
}

void BufferWidget::cursorPositionChanged() { /*qDebug() << "Cursor pos changed"; */
}

void BufferWidget::keyPressEvent(QKeyEvent *e) {

  handleKeyEvent(e);
  return;
}

void BufferWidget::focusOutEvent(QFocusEvent *event) {
  // qDebug() << "StE:Focus OUT";

  rb_funcall(NULL, rb_intern("focus_out"), 0);
  // qDebug() << "StE FOCUS OUT: END";
}

///////////////////////////

BufferWidget::BufferWidget(QWidget *parent) {

  cursorpos = 0;
  at_line_end = 0;
  overlay_paint_cursor = 0;
  overlay = 0;
  fnt = QFont("Ubuntu Mono", 12);
  setFont(fnt);

  lineNumberArea = NULL;
  if (0) {
    lineNumberArea = new LineNumberArea(this);
    lineNumberArea->setGeometry(QRect(0, 0, 40, 400));
    connect(this, SIGNAL(textChanged()), this, SLOT(updateLineNumberArea()));
    updateLineNumberAreaWidth(0);
  }

  // TODO: make as option
  setWordWrapMode(QTextOption::WrapAnywhere);

  setAcceptDrops(true);

  //  connect(this, SIGNAL(blockCountChanged(int)), this, SLOT(updateLineNumberAreaWidth(int)));
  //  connect(this, SIGNAL(updateRequest(QRect, int)), this, SLOT(updateLineNumberArea(QRect,
  //  int)));
}

int BufferWidget::loadTheme() { qDebug() << "BufferWidget::loadTheme\n"; }

int BufferWidget::lineNumberAreaWidth() {
  int digits = 5;
  //    while (max >= 10) {
  //        max /= 10;
  //        ++digits;
  //    }
  //
  //    int space = 3 + fontMetrics().horizontalAdvance(QLatin1Char('9')) * digits;

  qDebug() << "BufferWidget::lineNumberAreaWidth()\n";
  int space = 50;
  return space;
}

// void BufferWidget::updateLineNumberArea(const QRect &rect, int dy) {
void BufferWidget::updateLineNumberArea() {
  //    lineNumberArea->update(0, 0, lineNumberArea->width(), 400);
  lineNumberArea->repaint();
  //  lineNumberAreaPaintEvent(NULL);
  //  lineNumberArea->update(0, 0, 10, 400);

  qDebug() << "BufferWidget::updateLineNumberArea(const QRect &rect, int dy)\n";
  //  if (dy)
  //    lineNumberArea->scroll(0, dy);
  //  else
  //    lineNumberArea->update(0, rect.y(), lineNumberArea->width(), rect.height());
  //
  //  if (rect.contains(viewport()->rect()))
  //    updateLineNumberAreaWidth(0);
}

void BufferWidget::handleContextMenu(QAction *act) {
  ID menu_callback = rb_intern_str(rb_str_new2("context_menu_callback"));
  int act_id = act->data().toInt();
  rb_funcall(INT2NUM(0), menu_callback, 1, INT2NUM(act_id));

  // printf("=== handleContextMenu id:%d===\n", act_id);
}

void BufferWidget::contextMenuEvent(QContextMenuEvent *event) {
  //    QMenu *menu = createStandardContextMenu();
  QMenu *menu = new QMenu(this);

  QAction *menuEntry;

  ID cm_fun = rb_intern_str(rb_str_new2("generate_context_menu"));
  VALUE menu_list = rb_funcall(INT2NUM(0), cm_fun, 0);

  for (int i = 0; i < RARRAY_LEN(menu_list); i++) {
    VALUE d = rb_ary_entry(menu_list, i);
    VALUE c0 = rb_ary_entry(d, 0);
    VALUE c1 = rb_ary_entry(d, 3);

    menuEntry = new QAction(tr(StringValueCStr(c0)), this);
    menuEntry->setData(NUM2INT(c1));
    menu->addAction(menuEntry);
  }

  connect(menu, SIGNAL(triggered(QAction *)), this, SLOT(handleContextMenu(QAction *)));

  menu->exec(event->globalPos());
  delete menu;
}

void BufferWidget::lineNumberAreaPaintEvent(QPaintEvent *event) {
  //  qDebug() << "BufferWidget::lineNumberAreaPaintEvent(QPaintEvent *event) \n";
  QPainter p(lineNumberArea);
  p.fillRect(event->rect(), QColor("#000000"));

  QString number = QString::number(55);
  p.setPen(Qt::white);

  //  qDebug() << "BufferWidget::lineNumberAreaPaintEvent " << lineNumberArea->width()
  //           << fontMetrics().height() << endl;

  int top = 20;
  //  painter.drawText(0, top, lineNumberArea->width(), fontMetrics().height(), Qt::AlignRight,
  //  number);
  //  painter.drawText(0, top, lineNumberArea->width(), fontMetrics().height(), Qt::AlignLeft,
  //  number);

  //  QPainter p =;
  p.setPen(QColor("#ffff2222"));
  QFont font = p.font();
  font.setPointSize(10);
  font.setWeight(QFont::DemiBold);
  QFontMetrics fm(font);
  p.setFont(font);
  //  p.fillRect(0, 0, 50, 50, QColor("#ee0000"));

  //  p.fillRect(50, 50, 10, 10, QColor("#ee0000"));

  //    p.drawText(x + x_align, y + y_align + font_height, text);
  p.drawText(5, 30, number);
  p.drawText(5, 130, number);

  //    QTextBlock block = firstVisibleBlock();
  //    int blockNumber = block.blockNumber();
  //    int top = (int) blockBoundingGeometry(block).translated(contentOffset()).top();
  //    int bottom = top + (int) blockBoundingRect(block).height();
  //
  //    while (block.isValid() && top <= event->rect().bottom()) {
  //        if (block.isVisible() && bottom >= event->rect().top()) {
  //            QString number = QString::number(blockNumber + 1);
  //            painter.setPen(Qt::black);
  //            painter.drawText(0, top, lineNumberArea->width(), fontMetrics().height(),
  //                             Qt::AlignRight, number);
  //        }
  //
  //        block = block.next();
  //        top = bottom;
  //        bottom = top + (int) blockBoundingRect(block).height();
  //        ++blockNumber;
  //    }
}

void BufferWidget::updateLineNumberAreaWidth(int /* newBlockCount */) {
  setViewportMargins(lineNumberAreaWidth(), 0, 0, 0);
}

// Use QTextEdit standard functionality to draw cursor when possible.
// Use Overlay class when not.
void BufferWidget::drawTextCursor() {

  QList<QTextEdit::ExtraSelection> extraSelections;
  QList<QTextEdit::ExtraSelection> extraSelections2;
  QTextEdit::ExtraSelection selection;
  QTextEdit::ExtraSelection selection2;

  at_line_end = 0;
  // if (selection.cursor.atBlockEnd()) {
  // at_line_end = 1;
  // } else {
  // at_line_end = 0;
  // }

  // Draw line highlight
  // Disable. Triggers segfault occasionally.
  if (0) {
    VALUE linehl_color = rb_eval_string("$theme.default[:lineHighlight]");
    QColor lineColor = QColor(StringValueCStr(linehl_color));

    selection.format.setBackground(lineColor);
    selection.format.setProperty(QTextFormat::FullWidthSelection, true);
    selection.cursor = textCursor();
    selection.cursor.clearSelection();
    extraSelections.append(selection);
  }

  setCursorWidth(0);
  overlay_paint_cursor = 0;

  //  Not at line end and Command mode
  //  if(!at_line_end && is_command_mode > 0) {
  // TODO: visual or command mode

  QTextCursor tc = textCursor();
  // int cursor_pos = c_te->cursor_pos;

  VALUE ivtmp = rb_eval_string("buf.visual_mode?");
  
  int selection_start = NUM2INT(rb_eval_string("buf.selection_start()"));
  
  qDebug() << "sel start:" << selection_start << "\n";

  if (RTEST(ivtmp) && selection_start >= 0) {
    if (cursor_pos < selection_start) {
      tc.setPosition(selection_start + 1);
      tc.setPosition(cursor_pos, QTextCursor::KeepAnchor);
    } else {
      tc.setPosition(selection_start);
      tc.setPosition(cursor_pos, QTextCursor::KeepAnchor);
    }
  } else {
    tc.setPosition(cursor_pos);
  }

  c_te->setTextCursor(tc);
 

  if (1) {
    if (!at_line_end && (RTEST(ivtmp) || is_command_mode)) {
      // qDebug() << "Draw cursor";

      selection2.cursor = textCursor();
      selection2.cursor.clearSelection();
      selection2.format.setBackground(QColor("#839496"));
      selection2.format.setForeground(QColor("#002b36"));

      selection2.cursor.setPosition(cursor_pos);
      selection2.cursor.setPosition(cursor_pos + 1, QTextCursor::KeepAnchor);
      extraSelections.append(selection2);
    }
    // Command mode at line end
    else if (is_command_mode > 0) {
      overlay_paint_cursor = 1;
      cursor_width = 7;
      // setCursorWidth(10);
    } else { // Insert (or visual) mode
      overlay_paint_cursor = 1;
      cursor_width = 1;
    }
  }

  setExtraSelections(extraSelections);

  QRect r = cursorRect();
  cursor_x = r.x();
  cursor_y = r.y();
  cursor_height = r.height();
}
