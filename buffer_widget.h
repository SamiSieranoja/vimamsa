#ifndef BUFFER_WIDGET_H
#define BUFFER_WIDGET_H

#include <QMainWindow>
#include <QWidget>
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
#include <QMainWindow>


#include "highlighter.h"
#include "selectwindow.h"
// #include "main_window.h"
#include "buf_overlay.h"
#include "constants.h"

class LineNumberArea;
class BufferWidget;
class QPaintEvent;



class BufferWidget : public QTextEdit {
  Q_OBJECT
public:
  BufferWidget(QWidget *parent = 0);
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
  
  QTextBlock startblock;
  QTextBlock endblock;
  QTextBlock curblock;
  int continue_hl_batch;
  int runHighlightBatch();


  void drawTextCursor();
  void processKeyEvent(QKeyEvent *e);
  void contextMenuEvent(QContextMenuEvent *event);

public:
  void lineNumberAreaPaintEvent(QPaintEvent *event);
  int lineNumberAreaWidth();
  int loadTheme();
  int processHighlights(); 
  int cursor_pos; 
  int selection_start; 
//  void updateLineNumberArea(const QRect &, int);

  /*~Editor();*/

protected:
  void keyPressEvent(QKeyEvent *e);
  void keyReleaseEvent(QKeyEvent *e);
  void mouseReleaseEvent(QMouseEvent *e);
  void mousePressEvent(QMouseEvent *e);
  void cursorPositionChanged();
  void focusOutEvent(QFocusEvent *event);
  // void paintEvent(QPaintEvent *e);

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

class LineNumberArea : public QWidget {
public:
  LineNumberArea(BufferWidget *editor) : QWidget(editor) { codeEditor = editor; }

  QSize sizeHint() const override { return QSize(codeEditor->lineNumberAreaWidth(), 0); }

protected:
  // TODO?: void paintEvent(QPaintEvent *event) override { codeEditor->lineNumberAreaPaintEvent(event); }
//  void paintEvent(QPaintEvent *event);

private:
  BufferWidget *codeEditor;
};


#endif
