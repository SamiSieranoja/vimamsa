
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

#include "highlighter.h"
#include "selectwindow.h"

#define RENDER_TEXT 1001
#define COMMAND  1
#define INSERT  2
#define BROWSE  3

#define NEXT_MARK  1001
#define PREVIOUS_MARK  1002
#define BACKWARD  1003
#define FORWARD  1004
#define BEFORE  1005
#define AFTER  1006

#define FORWARD_CHAR  2001
#define BACKWARD_CHAR  2002
#define FORWARD_LINE  2003
#define BACKWARD_LINE  2004
#define CURRENT_CHAR_FORWARD  2005
#define CURRENT_CHAR_BACKWARD  2006
#define START_OF_BUFFER  2007
#define END_OF_BUFFER  2008

#define DELETE  3001
#define REPLACE  3002


// Event types
#define CURSOR_POS_CHANGED 9001
#define KEY_PRESS 9002
#define KEY_RELEASE 9003
#define FILE_OPENED 9004
#define FOCUS_OUT 9005



extern "C" {
#include <ruby.h>
#include <ruby/re.h>
    VALUE method_render_text(VALUE self, VALUE text, VALUE _lpos, VALUE _cpos, VALUE _reset);
    VALUE method_scan_indexes(VALUE self, VALUE str, VALUE pat);
    VALUE method_qt_quit(VALUE self);
    VALUE method_main_loop(VALUE self);
    VALUE method_open_file_dialog(VALUE self);
    VALUE method_set_window_title(VALUE self,VALUE new_title);
    void _init_ruby(int argc, char *argv[]);


} // END extern "C"

int render_text();
int cpp_render_text(); //TODO: ?
char* qstring_to_cstr(QString qstr);
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

class HelloThread : public QThread
{
    Q_OBJECT
private:
    void run();
};

class Overlay : public
 QFrame
{
   Q_OBJECT
    public:
    Overlay(QWidget *parent = 0): QFrame(parent)  {
    setAttribute(Qt::WA_TransparentForMouseEvents);
    setFrameStyle(QFrame::NoFrame);
    // Autofill with transparent color
    setAutoFillBackground(true);
    setStyleSheet("background-color: rgba(255, 255, 255, 0);");
    //2DEBUG: setStyleSheet("background-color: rgba(255, 255, 255, 10);");
    }
    int draw_text(int x, int y, char* text);
   /*~Editor();*/

 protected:
   void paintEvent(QPaintEvent * e);

};



class SEditor : public
 QTextEdit
{
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
    Overlay* overlay;
    Highlighter* hl;
    QFont fnt;

    void drawTextCursor();
    void processKeyEvent(QKeyEvent * e);

   /*~Editor();*/

 protected:
    void keyPressEvent(QKeyEvent *e);
    void keyReleaseEvent(QKeyEvent *e);
    void mouseReleaseEvent(QMouseEvent *e);
    void cursorPositionChanged();
    void focusOutEvent(QFocusEvent *event);
    void paintEvent(QPaintEvent * e);


 private:
    void handleKeyEvent(QKeyEvent *e);
    int cursorpos = 0;

};

class Editor : public QMainWindow
{
    Q_OBJECT

public:
    Editor(QWidget *parent = 0);
    int setQtStyle(int style_id);

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

    QAction *actionSave;

    QComboBox *comboStyle;
    QFontComboBox *comboFont;
    QComboBox *comboSize;

    QToolBar *tb;
    QString fileName;
    SEditor *textEdit;
    Highlighter *highlighter;
    SelectWindow* select_w;

};

#endif // TEXTEDIT_H
