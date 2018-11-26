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

#include "editor.h"
#include "selectwindow.h"
#include "srn_dst.h"

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
Editor *mw;

void cpp_init_qt_thread() { Q_INIT_RESOURCE(viwbaw); }

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

#include "ruby_ext.c"

#ifdef Q_OS_MAC
const QString rsrcPath = ":/images/mac";
#else
const QString rsrcPath = ":/images/win";
#endif

void Overlay::paintEvent(QPaintEvent *e) {
  int jm_x = 0;
  int jm_y = 0;

  QTextCursor cursor = c_te->textCursor();
  QRect r = c_te->cursorRect(cursor);
  jm_x = r.x() - 6;
  jm_y = r.y() - 7;
  // int cursor_height = r.height();

  if (c_te->cursor_y < 0)
    return;
  // TODO: when outside of viewport

  QSize parentsize = c_te->frameSize();

  int draw_width = c_te->cursor_x + c_te->cursor_width;
  int draw_height = c_te->cursor_y + c_te->cursor_height;
  resize(parentsize); // TODO: resize to parent widget when change
  QPainter p(this);
  // resize(draw_width, draw_height); //TODO: resize to parent widget when change

  p.eraseRect(0, 0, parentsize.rwidth(), parentsize.rheight());
  // p.eraseRect(0,0,draw_width,draw_height);

  if (c_te->overlay_paint_cursor) {
    // printf("Overlay:paintEvent x=%d y=%d w=%d h=%d\n",c_te->cursor_x, c_te->cursor_y,
    // c_te->cursor_width,c_te->cursor_height);
    QColor cursor_color = new QColor("#839496");
    p.fillRect(c_te->cursor_x, c_te->cursor_y, c_te->cursor_width, c_te->cursor_height,
               QColor("#839496"));
  } else {
    // printf("Overlay:paintEvent. overlay_paint_cursor=false\n");
  }

  VALUE paint_stack = rb_eval_string("$paint_stack");
  while (RARRAY_LEN(paint_stack) > 0) {
    VALUE p = rb_ary_shift(paint_stack);
    int draw_type = NUM2INT(rb_ary_entry(p, 0));
    int x_coord = NUM2INT(rb_ary_entry(p, 1));
    int y_coord = NUM2INT(rb_ary_entry(p, 2));
    VALUE c = rb_ary_entry(p, 3);
    // qDebug() << "Paint item: " << " " << NUM2INT(rb_ary_entry(p,0)) << " " <<
    // NUM2INT(rb_ary_entry(p,1)) << " " << NUM2INT(rb_ary_entry(p,2)) << "\n";
    draw_text(x_coord, y_coord, StringValueCStr(c));
  }
}

int Overlay::draw_text(int x, int y, char *text) {

  QPainter p(this);
  p.setPen(QColor("#ffff2222"));
  QFont font = p.font();
  // font.setPointSize (10);
  font.setPointSize(10);
  font.setWeight(QFont::DemiBold);
  QFontMetrics fm(font);
  p.setFont(font);
  // QRect qr =  fm.tightBoundingRect(text);
  // QRect qr =  fm.tightBoundingRect("X");
  QRect qr = fm.tightBoundingRect(text);
  int padding = 2;
  int y_align = -0;
  int x_align = -2;
  // int font_height = fm.xHeight();
  int font_height = qr.height();
  p.fillRect(x + x_align - padding, y + y_align - padding, qr.width() + 2 * padding,
             font_height + 2 * padding, QColor("#77000000"));
  p.drawText(x + x_align, y + y_align + font_height, text);

  // QPen myPen(Qt::red);
  // myPen.setWidth(3);
  // p.setPen(myPen);
  // p.setBrush(Qt::NoBrush); // should not be necessary, but doesn't hurt
  // p.drawPoint(x,y);
}

SEditor::SEditor(QWidget *parent)
//: QEditor(parent)
{

  cursorpos = 0;
  at_line_end = 0;
  overlay_paint_cursor = 0;
  overlay = 0;
  fnt = QFont("Ubuntu Mono", 12);
  setFont(fnt);
  QPalette p = palette();
  p.setColor(QPalette::Base, QColor("#002b36"));
  p.setColor(QPalette::Text, QColor("#839496"));
  setPalette(p);

  setFrameStyle(QFrame::NoFrame);

  // base03    #002b36  8/4 brblack  234 #1c1c1c
  // base02    #073642  0/4 black    235 #262626
  // base01    #586e75 10/7 brgreen  240 #4e4e4e
  // base00    #657b83 11/7 bryellow 241 #585858
  // base0     #839496 12/6 brblue   244 #808080
  // base1     #93a1a1 14/4 brcyan   245 #8a8a8a
  // base2     #eee8d5  7/7 white    254 #d7d7af
  // base3     #fdf6e3 15/7 brwhite  230 #ffffd7
  // yellow    #b58900  3/3 yellow   136 #af8700
  // orange    #cb4b16  9/3 brred    166 #d75f00
  // red       #dc322f  1/1 red      160 #d70000
  // magenta   #d33682  5/5 magenta  125 #af005f
  // violet    #6c71c4 13/5 brmagenta 61 #5f5faf
  // blue      #268bd2  4/4 blue      33 #0087ff
  // cyan      #2aa198  6/6 cyan      37 #00afaf
  // green     #859900  2/2 green     64 #5f8700
}

// Use QTextEdit standard functionality to draw cursor when possible.
// Use Overlay class when not.
void SEditor::drawTextCursor() {

  QList<QTextEdit::ExtraSelection> extraSelections;
  QTextEdit::ExtraSelection selection;

  // Draw line highlight
  QColor lineColor = QColor("#073642");
  selection.format.setBackground(lineColor);
  selection.format.setProperty(QTextFormat::FullWidthSelection, true);
  selection.cursor = textCursor();
  extraSelections.append(selection);
  setExtraSelections(extraSelections);

  if (selection.cursor.atBlockEnd()) {
    at_line_end = 1;
  } else {
    at_line_end = 0;
  }

  setCursorWidth(0);
  overlay_paint_cursor = 0;

  //  Not at line end and Command mode
  //  if(!at_line_end && is_command_mode > 0) {
  // TODO: visual or command mode

  VALUE ivtmp = rb_eval_string("$at.is_visual_mode()");
  if (!at_line_end && (NUM2INT(ivtmp) == 1 || is_command_mode)) {
    qDebug() << "Draw cursor";
    selection.cursor.clearSelection();
    selection.format.setBackground(QColor("#839496"));
    selection.format.setForeground(QColor("#002b36"));

    selection.cursor.setPosition(cursor_pos);
    selection.cursor.setPosition(cursor_pos + 1, QTextCursor::KeepAnchor);
    extraSelections.append(selection);
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

int Editor::setQtStyle(int style_id) {
  if (style_id == 1) { // Dark fusion
    QApplication::setStyle(QStyleFactory::create("Fusion"));

    // From: https://gist.github.com/QuantumCD/6245215
    QPalette darkPalette;

    darkPalette.setColor(QPalette::Window, QColor(53, 53, 53));
    darkPalette.setColor(QPalette::WindowText, Qt::white);
    darkPalette.setColor(QPalette::Base, QColor(25, 25, 25));
    darkPalette.setColor(QPalette::AlternateBase, QColor(53, 53, 53));
    darkPalette.setColor(QPalette::ToolTipBase, Qt::white);
    darkPalette.setColor(QPalette::ToolTipText, Qt::white);
    darkPalette.setColor(QPalette::Text, Qt::white);
    darkPalette.setColor(QPalette::Button, QColor(53, 53, 53));
    darkPalette.setColor(QPalette::ButtonText, Qt::white);
    darkPalette.setColor(QPalette::BrightText, Qt::red);
    darkPalette.setColor(QPalette::Link, QColor(42, 130, 218));

    darkPalette.setColor(QPalette::Highlight, QColor(42, 130, 218));
    darkPalette.setColor(QPalette::HighlightedText, Qt::black);

    app->setPalette(darkPalette);

    app->setStyleSheet(
        "QToolTip { color: #ffffff; background-color: #2a82da; border: 1px solid white; }");

    // setToolButtonStyle(Qt::ToolButtonFollowStyle); //TODO: segfaults, why?
  } else if (style_id == 2) {
    QApplication::setStyle(QStyleFactory::create("GTK+"));
  } else if (style_id == 3) {
    QApplication::setStyle(QStyleFactory::create("Fusion"));
  } else if (style_id == 4) {
    QApplication::setStyle(QStyleFactory::create("Windows"));
  }
}

Editor::Editor(QWidget *parent) : QMainWindow(parent) {

  initActions();

  // QStringList styles = QStyleFactory::keys();
  // cout << "List of valid styles:" << endl;
  // for (int i = 0; i < styles.size(); ++i)
  // cout << styles.at(i).toLocal8Bit().constData() << endl;

  {
    QMenu *helpMenu = new QMenu(tr("Help"), this);
    menuBar()->addMenu(helpMenu);
    helpMenu->addAction(tr("About"), this, SLOT(about()));
  }

  textEdit = new SEditor(this);
  c_te = textEdit;
  c_te->setFont(QFont("Ubuntu Mono", 12));
  c_te->overlay = new Overlay(c_te);
  c_te->hl = new Highlighter(c_te->document());

  QFrame *frame = new QFrame;
  QVBoxLayout *layout = new QVBoxLayout(frame);
  layout->setSpacing(1);
  layout->setContentsMargins(0, 0, 0, 0);
  miniEditor = new SEditor(this);
  miniEditor->setMaximumSize(4000, 30); // TODO: resize dynamically
  layout->addWidget(textEdit);
  layout->addWidget(miniEditor);
  setCentralWidget(frame);

  connect(textEdit->document(), SIGNAL(modificationChanged(bool)), actionSave,
          SLOT(setEnabled(bool)));
  connect(textEdit->document(), SIGNAL(modificationChanged(bool)), this,
          SLOT(setWindowModified(bool)));

  setWindowModified(textEdit->document()->isModified());
  actionSave->setEnabled(textEdit->document()->isModified());

  connect(QApplication::clipboard(), SIGNAL(dataChanged()), this, SLOT(clipboardDataChanged()));

  textEdit->setFocus();
}

void SEditor::keyReleaseEvent(QKeyEvent *e) {
  handleKeyEvent(e);
  return;
}

void SEditor::mouseReleaseEvent(QMouseEvent *event) {
  qDebug() << "QT: Mouse release";

  QTextCursor cursor = this->textCursor();
  qDebug() << "Editor:Cursor pos changed\n";
  qDebug() << "New pos:" << cursor.position() << "\n";

  rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("mouse_release"), rb_str_new2(""));

  cursor_pos = cursor.position();
  rb_funcall(NULL, rb_intern("set_cursor_pos"), 1, INT2NUM(cursor_pos));
  drawTextCursor();
  update(); // TODO: needed?
}

void SEditor::paintEvent(QPaintEvent *e) {

  // Q_D(QTextEdit);
  // QPainter p(d->viewport);
  // d->paint(&p, e);
  // TODO: gives error if trying to draw after calling superclass paintEvent
  // return;
  QTextEdit::paintEvent(e);
  QRect r = cursorRect();
  cursor_x = r.x();
  cursor_y = r.y();
  cursor_height = r.height();
}

void SEditor::handleKeyEvent(QKeyEvent *e) { processKeyEvent(e); }

void SEditor::processKeyEvent(QKeyEvent *e) {

  // QString str; str.sprintf("POS:%i",cursorpos);
  // QTextCursor tc = textCursor();
  QByteArray ba;
  const char *c_str2;

  VALUE rb_event;
  VALUE handle_key_event = rb_intern("handle_key_event");

  qDebug() << "nativeScanCode:" << e->nativeScanCode() << endl;
  qDebug() << "nativeVirtualKey:" << e->nativeVirtualKey() << endl;

  // qDebug() << "keyPressEvent thread:" << thread()->currentThreadId();
  // qDebug() << "SET NEW KEYPRESS";

  QString event_text = e->text();
  ba = e->text().toLocal8Bit();
  c_str2 = ba.data();
  rb_event = rb_ary_new3(5, INT2NUM(e->key()), INT2NUM(e->type()), rb_str_new2(c_str2),
                         rb_str_new2(c_str2), INT2NUM(e->modifiers())

  );

  rb_funcall(NULL, handle_key_event, 1, rb_event);

  QTextCharFormat charFormat;
  QTextCharFormat defaultCharFormat;
  charFormat.setFontWeight(QFont::Black);

  if (RTEST(rb_eval_string("$update_highlight"))   && RTEST(rb_eval_string("$cnf[:syntax_highlight]")) 
  ) {
    c_te->hl->rehighlight();
    rb_eval_string("$update_highlight=false");
  }
}

void SEditor::cursorPositionChanged() { qDebug() << "Cursor pos changed"; }

void SEditor::keyPressEvent(QKeyEvent *e) {

  handleKeyEvent(e);
  return;
}

void SEditor::focusOutEvent(QFocusEvent *event) {
  qDebug() << "StE:Focus OUT";

  rb_funcall(NULL, rb_intern("focus_out"), 0);
  qDebug() << "StE FOCUS OUT: END";
}

void Editor::closeEvent(QCloseEvent *e) {
  // TODO
}

void Editor::initActions() {
  QToolBar *tb = new QToolBar(this);
  tb->setWindowTitle(tr("File Actions"));
  addToolBar(tb);

  QMenu *menu = new QMenu(tr("File"), this);
  menuBar()->addMenu(menu);

  QAction *a;

  QIcon newIcon = QIcon::fromTheme("document-new", QIcon(rsrcPath + "/filenew.png"));
  a = new QAction(newIcon, tr("&New"), this);
  a->setPriority(QAction::LowPriority);
  // a->setShortcut(QKeySequence::New);
  connect(a, SIGNAL(triggered()), this, SLOT(fileNew()));
  tb->addAction(a);
  menu->addAction(a);

  a = new QAction(QIcon::fromTheme("document-open", QIcon(rsrcPath + "/fileopen.png")),
                  tr("&Open..."), this);
  // a->setShortcut(QKeySequence::Open);
  connect(a, SIGNAL(triggered()), this, SLOT(fileOpen()));
  tb->addAction(a);
  menu->addAction(a);

  menu->addSeparator();

  actionSave = a = new QAction(QIcon::fromTheme("document-save", QIcon(rsrcPath + "/filesave.png")),
                               tr("&Save"), this);
  // a->setShortcut(QKeySequence::Save);
  connect(a, SIGNAL(triggered()), this, SLOT(fileSave()));
  a->setEnabled(false);
  tb->addAction(a);
  menu->addAction(a);

  a = new QAction(tr("Save &As..."), this);
  a->setPriority(QAction::LowPriority);
  connect(a, SIGNAL(triggered()), this, SLOT(fileSaveAs()));
  menu->addAction(a);
  menu->addSeparator();

  a = new QAction(QIcon::fromTheme("document-print", QIcon(rsrcPath + "/fileprint.png")),
                  tr("&Print..."), this);
  a->setPriority(QAction::LowPriority);
  connect(a, SIGNAL(triggered()), this, SLOT(filePrint()));
  menu->addAction(a);

  a = new QAction(QIcon::fromTheme("fileprint", QIcon(rsrcPath + "/fileprint.png")),
                  tr("Print Preview..."), this);
  connect(a, SIGNAL(triggered()), this, SLOT(filePrintPreview()));
  menu->addAction(a);

  a = new QAction(QIcon::fromTheme("exportpdf", QIcon(rsrcPath + "/exportpdf.png")),
                  tr("&Export PDF..."), this);
  a->setPriority(QAction::LowPriority);
  connect(a, SIGNAL(triggered()), this, SLOT(filePrintPdf()));
  menu->addAction(a);

  menu->addSeparator();

  a = new QAction(tr("&Quit"), this);
  connect(a, SIGNAL(triggered()), this, SLOT(quit()));
  menu->addAction(a);

  comboFont = new QFontComboBox(tb);
  tb->addWidget(comboFont);
  connect(comboFont, SIGNAL(activated(QString)), this, SLOT(textFamily(QString)));

  comboSize = new QComboBox(tb);
  comboSize->setObjectName("comboSize");
  tb->addWidget(comboSize);
  comboSize->setEditable(true);

  QFontDatabase db;
  foreach (int size, db.standardSizes())
    comboSize->addItem(QString::number(size));

  connect(comboSize, SIGNAL(activated(QString)), this, SLOT(textSize(QString)));
  comboSize->setCurrentIndex(
      comboSize->findText(QString::number(QApplication::font().pointSize())));
}

void Editor::setCurrentFileName(const QString &fileName) {
  this->fileName = fileName;
  textEdit->document()->setModified(false);

  QString shownName;
  if (fileName.isEmpty())
    shownName = "untitled.txt";
  else
    shownName = QFileInfo(fileName).fileName();

  setWindowTitle(tr("%1[*] - %2").arg(shownName).arg(tr("Viwbaw")));
  setWindowModified(false);
}

void Editor::fileNew() {
  qDebug() << "QT: fileNew";
  rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("filenew"), rb_str_new2(""));
}

void Editor::fileOpen() {
  qDebug() << "QT:FILE OPEN";
  QString fn = QFileDialog::getOpenFileName(this, tr("Open File..."), QString(),
                                            tr("HTML-Files (* *.htm *.html *.txt);;All Files (*)"));

  if (!fn.isEmpty()) {
    rb_funcall(NULL, rb_intern("new_file_opened"), 2, rb_str_new2(qstring_to_cstr(fn)),
               rb_str_new2(""));
  }

  qDebug() << "QT:FILE OPEN END";
}

bool Editor::quit() {
  qDebug() << "QT: quit";
  rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("quit"), rb_str_new2(""));
}

bool Editor::fileSave() {

  qDebug() << "QT: fileSave";
  rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("save"), rb_str_new2(""));

  return 1;
}

bool Editor::fileSaveAs() {

  QString fn = QFileDialog::getSaveFileName(this, tr("Save as..."), QString(), tr("All Files (*)"));

  if (fn.isEmpty())
    return false;

  qDebug() << "QT: fileSaveAs";
  rb_funcall(NULL, rb_intern("qt_signal"), 2, rb_str_new2("saveas"),
             rb_str_new2(qstring_to_cstr(fn)));
  return 1;
}

void Editor::filePrint() {
#ifndef QT_NO_PRINTER
  QPrinter printer(QPrinter::HighResolution);
  QPrintDialog *dlg = new QPrintDialog(&printer, this);
  if (textEdit->textCursor().hasSelection())
    dlg->addEnabledOption(QAbstractPrintDialog::PrintSelection);
  dlg->setWindowTitle(tr("Print Document"));
  if (dlg->exec() == QDialog::Accepted)
    textEdit->print(&printer);
  delete dlg;
#endif
}

void Editor::filePrintPreview() {
#ifndef QT_NO_PRINTER
  QPrinter printer(QPrinter::HighResolution);
  QPrintPreviewDialog preview(&printer, this);
  connect(&preview, SIGNAL(paintRequested(QPrinter *)), SLOT(printPreview(QPrinter *)));
  preview.exec();
#endif
}

void Editor::printPreview(QPrinter *printer) {
#ifdef QT_NO_PRINTER
  Q_UNUSED(printer);
#else
  textEdit->print(printer);
#endif
}

void Editor::filePrintPdf() {
#ifndef QT_NO_PRINTER
  //! [0]
  QString fileName = QFileDialog::getSaveFileName(this, "Export PDF", QString(), "*.pdf");
  if (!fileName.isEmpty()) {
    if (QFileInfo(fileName).suffix().isEmpty())
      fileName.append(".pdf");
    QPrinter printer(QPrinter::HighResolution);
    printer.setOutputFormat(QPrinter::PdfFormat);
    printer.setOutputFileName(fileName);
    textEdit->document()->print(&printer);
  }
//! [0]
#endif
}

void Editor::textFamily(const QString &f) {
  qDebug() << "Font family:" << f << endl;
  c_te->fnt.setFamily(f);
  c_te->setFont(c_te->fnt);
}

void Editor::textSize(const QString &p) {
  qDebug() << "Font size:" << p << endl;
  qreal pointSize = p.toFloat();
  if (p.toFloat() > 0) {
    c_te->fnt.setPointSize(pointSize);
    c_te->setFont(c_te->fnt);
  }
}

void Editor::currentCharFormatChanged(const QTextCharFormat &format) {}

void Editor::focusOutEvent(QFocusEvent *event) { qDebug() << "TE:Focus OUT\n"; }

void Editor::cursorPositionChanged() {
  // TODO:delete
}

void Editor::clipboardDataChanged() {
  // http://doc.qt.io/qt-5/qclipboard.html
  printf("DEBUG: Clipboard data changed\n");
  // const QMimeData *md = QApplication::clipboard()->mimeData();
  if (const QMimeData *md = QApplication::clipboard()->mimeData()) {
    if (md->hasText()) {
      //   char* clipboard_str = qstring_to_cstr(md->text());

      QString text22 = md->text();
      char *clipboard_str = qstring_to_cstr(text22);

      rb_funcall(NULL, rb_intern("system_clipboard_changed"), 1, rb_str_new2(clipboard_str));
      free(clipboard_str);
    }
  }
}

void Editor::about() { QMessageBox::about(this, tr("About"), tr("TODO:about")); }

void Editor::mergeFormatOnWordOrSelection(const QTextCharFormat &format) {
  QTextCursor cursor = textEdit->textCursor();
  if (!cursor.hasSelection())
    cursor.select(QTextCursor::WordUnderCursor);
  cursor.mergeCharFormat(format);
  textEdit->mergeCurrentCharFormat(format);
}

void Editor::fontChanged(const QFont &f) {
  comboFont->setCurrentIndex(comboFont->findText(QFontInfo(f).family()));
  comboSize->setCurrentIndex(comboSize->findText(QString::number(f.pointSize())));
}

void Editor::colorChanged(const QColor &c) { return; }
