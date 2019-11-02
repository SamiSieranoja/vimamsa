
#include <QtWidgets>

#include <ruby.h>
#include <ruby/encoding.h>

#include "editor.h"
#include "main_window.h"
#include "buffer_widget.h"


#include "buf_overlay.h"
#include "highlighter.h"
#include "config_window.h"
#include "globals.h"

int loadTheme();

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

// int Editor::addTextFormat(QString foregroundColor, QString backgroundColor, int fontStyle) {
int Editor::addTextFormat(QString foregroundColor, QString backgroundColor, int fontStyle,
                          float fontScale) {
  qDebug() << "foregC:" << foregroundColor << "fontStyle:" << fontStyle;
  printf("sty:%d\n", fontStyle);

  // float fontScale=1.2;
  QTextCharFormat *newfmt = new QTextCharFormat();

  if (fontScale != 1.0) {
    int pointSize = (int)(c_te->fnt.pointSize() * fontScale);
    newfmt->setFontPointSize(pointSize);
  }

  if (!foregroundColor.isEmpty()) {
    newfmt->setForeground(QColor(foregroundColor));
  }

  if (!backgroundColor.isEmpty()) {
    newfmt->setBackground(QColor(backgroundColor));
  }

  if (fontStyle == 1) {
    newfmt->setFontWeight(QFont::Bold);
  }

  textFormats.push_back(newfmt);
}

int Editor::clearTextFormats() {
  QTextCharFormat *fmt;
  qDebug() << "Clear TEXT FORMATS";
  for (int i = 0; i < textFormats.size(); i++) {
    fmt = textFormats[i];
    // free(fmt); //TODO: need to clear after sure no longer used by Qt rendering
  }
  textFormats.clear();
  printf("Clear text formats, size:%d\n", textFormats.size());
  fflush(stdout);
}

Editor::Editor(QWidget *parent = 0) : QMainWindow(parent) {

  initActions();

  // QStringList styles = QStyleFactory::keys();
  // cout << "List of valid styles:" << endl;
  // for (int i = 0; i < styles.size(); ++i)
  // cout << styles.at(i).toLocal8Bit().constData() << endl;

  {
    QMenu *helpMenu = new QMenu(tr("Help"), this);
    menuBar()->addMenu(helpMenu);
    helpMenu->addAction(tr("About"), this, SLOT(about()));
    helpMenu->addAction(tr("Settings"), this, SLOT(config()));
  }

  {
    QMenu *actionMenu = new QMenu(tr("Actions"), this);
    menuBar()->addMenu(actionMenu);
    actionMenu->addAction(tr("Search and Replace"), this, SLOT(SearchAndReplace()));
    actionMenu->addAction(tr("Search Actions"), this, SLOT(SearchActions()));
  }

  textEdit = new BufferWidget(this);
  c_te = textEdit;
  // c_te->fnt.setFamily(f);


  c_te->fnt.setPointSize(12);
  c_te->setFont(QFont("Ubuntu Mono", 12));
  c_te->overlay = new Overlay(c_te);
  c_te->hl = new Highlighter(c_te->document());
  c_te->hl->rb_highlight = rb_eval_string("false");
  c_te->continue_hl_batch = 0;

  QFrame *frame = new QFrame;
  // QVBoxLayout *layout = new QVBoxLayout(frame);
  layout = new QGridLayout(frame);
  layout->setSpacing(1);
  layout->setContentsMargins(0, 0, 0, 0);
  miniEditor = new BufferWidget(this);
  miniEditor->setMaximumSize(4000, 30); // TODO: resize dynamically
  layout->addWidget(textEdit, 1, 1);
  layout->addWidget(miniEditor, 2, 1);

  rightMiniBuffer = NULL;
  rightBuffer = NULL;
  // rightBuffer = new BufferWidget(this);
  // rightMiniBuffer = new BufferWidget(this);
  // rightMiniBuffer->setMaximumSize(4000, 30); // TODO: resize dynamically
  // layout->addWidget(rightBuffer, 1, 2);
  // layout->addWidget(rightMiniBuffer, 2, 2);
  // setNumColumns(2);
  setNumColumns(1);
  // setNumColumns(2);

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

int Editor::setNumColumns(int _numColumns) {
  numColumns = _numColumns;
  if (numColumns == 2) {
    rightBuffer = new BufferWidget(this);
    rightMiniBuffer = new BufferWidget(this);
    rightMiniBuffer->setMaximumSize(4000, 30); // TODO: resize dynamically
    layout->addWidget(rightBuffer, 1, 2);
    layout->addWidget(rightMiniBuffer, 2, 2);
  }
  if (numColumns == 1) {
    if (rightBuffer != NULL) {
      layout->removeWidget(rightBuffer);
      delete rightBuffer;
      rightBuffer = NULL;
    }
     if (rightMiniBuffer != NULL) {
      layout->removeWidget(rightMiniBuffer);
      delete rightMiniBuffer;
      rightMiniBuffer = NULL;
    }
   
  }
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
                  tr("&Open.."), this);
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

  menu->addAction(tr("Settings"), this, SLOT(config()));

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
  qDebug() << "QT:FILE OPEN(nopath)";
  fileOpen("");
}

void Editor::fileOpen(QString path) {
  qDebug() << "QT:FILE OPEN";
  QString fn = QFileDialog::getOpenFileName(this, tr("Open File..."), path,
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

bool Editor::fileSaveAs() { return fileSaveAs(""); }

bool Editor::fileSaveAs(QString path) {

  QString fn = QFileDialog::getSaveFileName(this, tr("Save as..."), path, tr("All Files (*)"));

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
  // printf("DEBUG: Clipboard data changed\n");
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

void Editor::config() {
  ConfigWindow *config_w = new ConfigWindow(this, 1);
  config_w->show();
}

void Editor::handleActionMenu() { qDebug() << "handleActionMenu"; }
void Editor::SearchAndReplace() { rb_eval_string("gui_search_replace"); }
void Editor::SearchActions() { rb_eval_string("search_actions"); }

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
