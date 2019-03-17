#ifndef MAIN_WINDOW_H
#define MAIN_WINDOW_H

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
#include <QMainWindow>
#ifndef QT_NO_PRINTER
#include <QPrintDialog>
#include <QPrinter>
#include <QPrintPreviewDialog>
#endif

#include "editor.h"
#include "buf_overlay.h"
#include "selectwindow.h"
#include "fuzzy_string_dist.h"


class Editor : public QMainWindow {
  Q_OBJECT

public:
  Editor(QWidget *parent = 0);
  // Editor(QWidget *parent);
  int setQtStyle(int style_id);
  
  QAction *actionSave;

protected:
  virtual void closeEvent(QCloseEvent *e);

private:
  void initActions();
  void setCurrentFileName(const QString &fileName);
public slots:
  void fileOpen();
  bool fileSaveAs();
private slots:
  void fileNew();
  bool fileSave();
  bool quit();
  void filePrint();
  void filePrintPreview();
  void filePrintPdf();

  void textFamily(const QString &f);
  void textSize(const QString &p);

  void currentCharFormatChanged(const QTextCharFormat &format);
  void cursorPositionChanged();

  void clipboardDataChanged();
  void about();
  void printPreview(QPrinter *);

protected:
  void focusOutEvent(QFocusEvent *event);

private:
  void mergeFormatOnWordOrSelection(const QTextCharFormat &format);
  void fontChanged(const QFont &f);
  void colorChanged(const QColor &c);
  Overlay overlay;


  QComboBox *comboStyle;
  QFontComboBox *comboFont;
  QComboBox *comboSize;

  QToolBar *tb;
  QString fileName;
  SEditor *textEdit;
  Highlighter *highlighter;
  SelectWindow *select_w;
};

// From http://doc.qt.io/qt-5/qtwidgets-widgets-codeeditor-codeeditor-h.html
class LineNumberArea : public QWidget {
public:
  LineNumberArea(SEditor *editor) : QWidget(editor) { codeEditor = editor; }

  QSize sizeHint() const override { return QSize(codeEditor->lineNumberAreaWidth(), 0); }

protected:
  void paintEvent(QPaintEvent *event) override { codeEditor->lineNumberAreaPaintEvent(event); }
//  void paintEvent(QPaintEvent *event);

private:
  SEditor *codeEditor;
};

#endif
