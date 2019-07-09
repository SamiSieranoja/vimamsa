#include <iostream>
#include <QtCore>
#include <QtConcurrent>
#include <QAction>
#include <QApplication>
#include <QClipboard>
#include <QComboBox>
#include <QFontComboBox>
#include <QFileDialog>
#include <QFileInfo>
#include <QFontDatabase>
#include <QMenu>
#include <QMenuBar>
#include <QTextEdit>
#include <QToolBar>
#include <QTextCursor>
#include <QtDebug>
#include <QCloseEvent>
#include <QMessageBox>
#include <QMimeData>
#include <QThread>
#include <QVBoxLayout>
#include <QScrollBar>
#include <QStyleFactory>
#include <QDesktopServices>
#include <QUrl>
#ifndef QT_NO_PRINTER
#include <QPrintDialog>
#include <QPrinter>
#include <QPrintPreviewDialog>
#endif

#include <QtWidgets>

#include <ruby.h>
#include <ruby/encoding.h>

#include "main_window.h"

using namespace std;
SEditor *c_te;
SEditor *miniEditor;

QApplication *app;
extern int *_argc;
extern char **_argv;

int cursor_pos = 0;
int selection_start = -1;
int reset_buffer = 0;

int file_opened = 0;
QString file_contents;
QString new_file_name;

int cpos, lpos;
char *bufstr;

QKeyEvent *e1;
QString *stext;
QString *window_title;
VALUE textbuf;
int _quit = 0;

Editor *g_editor;

void cpp_init_qt_thread() { Q_INIT_RESOURCE(vimamsa); }

char *qstring_to_cstr(QString qstr) {
  // Remember to free memory after use

  QByteArray ba;
  char *c_str2;
  ba = qstr.toUtf8();
  c_str2 = ba.data();
  char *c_str = malloc(strlen(c_str2) * sizeof(char *));
  strcpy(c_str, c_str2);
  return c_str;
}

VALUE qstring_to_ruby(QString qstr) {
  char *c_str = qstring_to_cstr(qstr);
  VALUE ret = rb_str_new2(c_str);
  free(c_str);
  return ret;
}

void qt_set_stylesheet_cpp(VALUE css) {
  printf("qt_set_stylesheet_cpp:%s\n", StringValueCStr(css));
  c_te->setStyleSheet(StringValueCStr(css));
}

void qt_add_font_style_cpp(VALUE sty) {
  printf("qt_add_font_style_cpp\n");
  QPalette p = c_te->palette();
  p.setColor(QPalette::Base, QColor("#003300"));
  c_te->setPalette(p);
  c_te->setFrameStyle(QFrame::NoFrame);
  // c_te->setStyleSheet(" QTextEdit {color: #00ff22; background-color: #003311; }");
  // Changing backround color does not work via setPalette
  // if setStyleSheet has been applied for parent widget
  // Might be ralated to bug https://bugreports.qt.io/browse/QTBUG-71716

  // c_te->update();
}

#include "ruby_ext.c"

#include "buf_overlay.h"


SEditor::SEditor(QWidget *parent) {

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

  //  connect(this, SIGNAL(blockCountChanged(int)), this, SLOT(updateLineNumberAreaWidth(int)));
  //  connect(this, SIGNAL(updateRequest(QRect, int)), this, SLOT(updateLineNumberArea(QRect,
  //  int)));

}


int SEditor::loadTheme() {
qDebug() << "SEditor::loadTheme\n";
}

int SEditor::lineNumberAreaWidth() {
  int digits = 5;
  //    while (max >= 10) {
  //        max /= 10;
  //        ++digits;
  //    }
  //
  //    int space = 3 + fontMetrics().horizontalAdvance(QLatin1Char('9')) * digits;

  qDebug() << "SEditor::lineNumberAreaWidth()\n";
  int space = 50;
  return space;
}

// void SEditor::updateLineNumberArea(const QRect &rect, int dy) {
void SEditor::updateLineNumberArea() {
  //    lineNumberArea->update(0, 0, lineNumberArea->width(), 400);
  lineNumberArea->repaint();
  //  lineNumberAreaPaintEvent(NULL);
  //  lineNumberArea->update(0, 0, 10, 400);

  qDebug() << "SEditor::updateLineNumberArea(const QRect &rect, int dy)\n";
  //  if (dy)
  //    lineNumberArea->scroll(0, dy);
  //  else
  //    lineNumberArea->update(0, rect.y(), lineNumberArea->width(), rect.height());
  //
  //  if (rect.contains(viewport()->rect()))
  //    updateLineNumberAreaWidth(0);
}

// void LineNumberArea::paintEvent(QPaintEvent *event) {
//  qDebug() << "LineNumberArea::paintEvent" << endl;
//
//  QPainter p(this);
//
//  QString number = QString::number(55);
//  p.setPen(Qt::white);
//
//  p.setPen(QColor("#ffff2222"));
//  QFont font = p.font();
//  font.setPointSize(10);
//  font.setWeight(QFont::DemiBold);
//  QFontMetrics fm(font);
//  p.setFont(font);
//  p.fillRect(0, 0, 50, 50, QColor("#ee0000"));
//
//  p.fillRect(50, 50, 10, 10, QColor("#ee0000"));
//
//
//}
//

void SEditor::contextMenuEvent(QContextMenuEvent *event) {
  //    QMenu *menu = createStandardContextMenu();
  QMenu *menu = new QMenu(this);

  menu->addAction(tr("TODO"));
  //  menu->addAction(g_editor->actionSave);
  menu->exec(event->globalPos());
  delete menu;
}

void SEditor::lineNumberAreaPaintEvent(QPaintEvent *event) {
  //  qDebug() << "SEditor::lineNumberAreaPaintEvent(QPaintEvent *event) \n";
  QPainter p(lineNumberArea);
  p.fillRect(event->rect(), QColor("#000000"));

  QString number = QString::number(55);
  p.setPen(Qt::white);

  //  qDebug() << "SEditor::lineNumberAreaPaintEvent " << lineNumberArea->width()
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

void SEditor::updateLineNumberAreaWidth(int /* newBlockCount */) {
  setViewportMargins(lineNumberAreaWidth(), 0, 0, 0);
}

// Use QTextEdit standard functionality to draw cursor when possible.
// Use Overlay class when not.
void SEditor::drawTextCursor() {

  QList<QTextEdit::ExtraSelection> extraSelections;
  QTextEdit::ExtraSelection selection;
  QTextEdit::ExtraSelection selection2;

  // Draw line highlight
  // QColor lineColor = QColor("#073642");
  VALUE linehl_color = rb_eval_string("$theme.default[:lineHighlight]");
  // QColor lineColor = QColor("#353030");
  QColor lineColor = QColor(StringValueCStr(linehl_color));


  
  // Draw line highlight
  selection.format.setBackground(lineColor);
  selection.format.setProperty(QTextFormat::FullWidthSelection, true);
  selection.cursor = textCursor();
  extraSelections.append(selection);
  setExtraSelections(extraSelections);


   at_line_end = 0;
  // if (selection.cursor.atBlockEnd()) {
    // at_line_end = 1;
  // } else {
    // at_line_end = 0;
  // }


  setCursorWidth(0);
  overlay_paint_cursor = 0;

  //  Not at line end and Command mode
  //  if(!at_line_end && is_command_mode > 0) {
  // TODO: visual or command mode


  VALUE ivtmp = rb_eval_string("$kbd.is_visual_mode()");
  if (!at_line_end && (NUM2INT(ivtmp) == 1 || is_command_mode)) {
    qDebug() << "Draw cursor";
    
    selection2.cursor = textCursor();
    selection2.cursor.clearSelection();
    selection2.format.setBackground(QColor("#839496"));
    selection2.format.setForeground(QColor("#002b36"));
    
    selection2.cursor.setPosition(cursor_pos);
    selection2.cursor.setPosition(cursor_pos + 1, QTextCursor::KeepAnchor);
    extraSelections.append(selection2);
    setExtraSelections(extraSelections);
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

  QRect r = cursorRect();
  cursor_x = r.x();
  cursor_y = r.y();
  cursor_height = r.height();
}









