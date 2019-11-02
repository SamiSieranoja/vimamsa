
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


#include "highlighter.h"
#include "selectwindow.h"
#include "buf_overlay.h"
#include "buffer_widget.h"
#include "constants.h"


void cpp_init_qt(); 

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

int render_text(VALUE textbuf, int cursor_pos,int selection_start,int reset_buffer);

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

#endif // TEXTEDIT_H
