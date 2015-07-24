/****************************************************************************
**
** Copyright (C) 2012 Digia Plc and/or its subsidiary(-ies).
** Contact: http://www.qt-project.org/legal
**
** This file is part of the demonstration applications of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and Digia.  For licensing terms and
** conditions see http://qt.digia.com/licensing.  For further information
** use the contact form at http://qt.digia.com/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU Lesser General Public License version 2.1 requirements
** will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** In addition, as a special exception, Digia gives you certain additional
** rights.  These rights are described in the Digia Qt LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3.0 as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU General Public License version 3.0 requirements will be
** met: http://www.gnu.org/copyleft/gpl.html.
**
**
** $QT_END_LICENSE$
**
****************************************************************************/

#ifndef TEXTEDIT_H
#define TEXTEDIT_H

#include <QMainWindow>
#include <QMap>
#include <QPointer>
#include <QTextEdit>
#include <QThread>

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


}

int render_text();
int cpp_render_text(); //TODO: ?

QT_BEGIN_NAMESPACE
class QAction;
class QComboBox;
class QFontComboBox;
class QEditor;
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




class SEditor : public
 QTextEdit
{
   Q_OBJECT
    public:
    SEditor(QWidget *parent = 0);
   /*~Editor();*/

 protected:
    void keyPressEvent(QKeyEvent *e);
    void keyReleaseEvent(QKeyEvent *e);
    void mouseReleaseEvent(QMouseEvent *e);
    void cursorPositionChanged();
    void focusOutEvent(QFocusEvent *event);

 private:
    void handleKeyEvent(QKeyEvent *e);
    int cursorpos = 0;

};

class Editor : public QMainWindow
{
    Q_OBJECT

public:
    Editor(QWidget *parent = 0);

protected:
    virtual void closeEvent(QCloseEvent *e);

private:
    void initActions();
    void setCurrentFileName(const QString &fileName);
public slots:
    void fileOpen();
private slots:
    void fileNew();
    bool fileSave();
    bool quit();
    bool fileSaveAs();
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

    QAction *actionSave;

    QComboBox *comboStyle;
    QFontComboBox *comboFont;
    QComboBox *comboSize;

    QToolBar *tb;
    QString fileName;
    SEditor *textEdit;
};

#endif // TEXTEDIT_H
