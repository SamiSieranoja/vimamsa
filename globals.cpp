
#include <QApplication>

#include "buffer_widget.h"
#include "buf_overlay.h"
#include "editor.h"
#include "highlighter.h"
#include "main_window.h"
#include "selectwindow.h"

QApplication *app;
BufferWidget *c_te;
BufferWidget *miniEditor;
Editor *g_editor;
int *_argc;
char **_argv;
SelectWindow *select_w;

