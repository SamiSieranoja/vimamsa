
#ifndef TEXTEDIT_H
#define TEXTEDIT_H

#include <QMainWindow>
#include <QMap>
#include <QPointer>
#include <QTextEdit>
#include <QThread>

#include <QPainter>
#include <QWidget>

#include <QApplication>
#include <QPushButton>
#include <QHBoxLayout>
#include <QLabel>
#include <QFrame>

#ifdef Q_OS_MAC
const QString rsrcPath = ":/images/mac";
#else
const QString rsrcPath = ":/images/default";
#endif

class LineNumberArea;
class SEditor;
class QPaintEvent;

#include "highlighter.h"
#include "selectwindow.h"
#include "buf_overlay.h"
#include "constants.h"


extern "C" {
#include <ruby.h>
#include <ruby/re.h>
VALUE method_render_text(VALUE self, VALUE text, VALUE _lpos, VALUE _cpos, VALUE _reset);
VALUE method_scan_indexes(VALUE self, VALUE str, VALUE pat);
VALUE method_qt_quit(VALUE self);
VALUE method_main_loop(VALUE self);
VALUE method_open_file_dialog(VALUE self, VALUE path);
VALUE method_set_window_title(VALUE self, VALUE new_title);
void _init_ruby(int argc, char *argv[]);

} // END extern "C"

int render_text();
int cpp_render_text(); // TODO: ?
char *qstring_to_cstr(QString qstr);
VALUE qstring_to_ruby(QString qstr);

QT_BEGIN_NAMESPACE
class QAction;
class QComboBox;
class QFontComboBox;
class QEditor;
class QPushButton;
class QTextCharFormat;
class QMenu;
class QPrinter;
QT_END_NAMESPACE

class VThread : public QThread {
  Q_OBJECT
private:
  void run();
};


class SEditor : public QTextEdit {
  Q_OBJECT
public:
  SEditor(QWidget *parent = 0);
  int cursor_x;
  int cursor_y;
  int cursor_height;
  int cursor_width;
  int at_line_end;
  int overlay_paint_cursor;
  int is_command_mode;
  Overlay *overlay;
  Highlighter *hl;
  QFont fnt;

  void drawTextCursor();
  void processKeyEvent(QKeyEvent *e);
  void contextMenuEvent(QContextMenuEvent *event);

public:
  void lineNumberAreaPaintEvent(QPaintEvent *event);
  int lineNumberAreaWidth();
  int loadTheme();
  int processHighlights(); 
//  void updateLineNumberArea(const QRect &, int);

  /*~Editor();*/

protected:
  void keyPressEvent(QKeyEvent *e);
  void keyReleaseEvent(QKeyEvent *e);
  void mouseReleaseEvent(QMouseEvent *e);
  void cursorPositionChanged();
  void focusOutEvent(QFocusEvent *event);
  void paintEvent(QPaintEvent *e);

private:
  void handleKeyEvent(QKeyEvent *e);
  int cursorpos = 0;

private slots:
  void updateLineNumberAreaWidth(int newBlockCount);
//  void updateLineNumberArea(const QRect &, int);
  void updateLineNumberArea();

private:
  QWidget *lineNumberArea;
};




#endif // TEXTEDIT_H
