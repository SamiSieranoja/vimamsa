#ifndef GLOBALS_H
#define GLOBALS_H

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

#include "buffer_widget.h"
#include "editor.h"
#include "main_window.h"


extern QApplication *app;
extern BufferWidget *c_te;
extern BufferWidget *miniEditor;
extern Editor *g_editor;
extern int *_argc;
extern char **_argv;
extern SelectWindow *select_w;


#endif // GLOBALS_H


