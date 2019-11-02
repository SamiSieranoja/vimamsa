#include <iostream>
#include <QtCore>
#include <QtConcurrent>
#include <QCoreApplication>
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

#include "editor.h"
#include "main_window.h"
#include "buffer_widget.h"
#include "globals.h"

using namespace std;

int file_opened = 0;
QString file_contents;
QString new_file_name;

int cpos, lpos;
char *bufstr;

QKeyEvent *e1;
QString *stext;
QString *window_title;
int _quit = 0;

void cpp_init_qt() {
  Q_INIT_RESOURCE(vimamsa);

  app = new QApplication(*_argc, _argv);
  app->setWindowIcon(QIcon("./images/icon.png"));

  g_editor = new Editor();
  g_editor->resize(700, 800);
  g_editor->show();
}

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
