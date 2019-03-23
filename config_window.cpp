
#include "config_window.h"
#include "editor.h"

ConfigWindow::ConfigWindow(QWidget *parent, int use_filter) : QWidget(parent) {

  saveButton = new QPushButton(tr("&Save"));
  cancelButton = new QPushButton(tr("&Cancel"));
  connect(cancelButton, SIGNAL(clicked()), this, SLOT(close()));
  connect(saveButton, SIGNAL(clicked()), this, SLOT(saveSettings()));

  // QVBoxLayout *layout = new QVBoxLayout;
  QFormLayout *layout = new QFormLayout;

  setLayout(layout);

  setWindowTitle(tr("Settings"));

  // // VALUE keys = rb_funcall(hash, rb_intern("keys"), 0)

  Qt::WindowFlags flags = 0;
  flags = Qt::Popup;
  flags = Qt::Window;
  // flags |= Qt::FramelessWindowHint;
  QWidget::setWindowFlags(flags);

  // QLabel *theme_label = new QLabel(this);
  // theme_label->setText("Select theme:");
  theme_select = new QComboBox(this);
  theme_select->setObjectName("theme_select");
  // theme_select->setEditable(true);

  VALUE optselected = rb_eval_string("$opt['theme']['selected']");
  VALUE optlist = rb_eval_string("$opt['theme']['items']");
  for (int i = 0; i < RARRAY_LEN(optlist); i++) {
    VALUE p = rb_ary_entry(optlist, i);
    printf("Theme:%s\n", StringValueCStr(p));
    theme_select->addItem(QString(StringValueCStr(p)));
  }
  theme_select->setCurrentIndex(NUM2INT(optselected));

  // connect(theme_select, SIGNAL(activated(QString)), this, SLOT(textSize(QString)));
  // theme_select->setCurrentIndex(
  // theme_select->findText(QString::number(QApplication::font().pointSize())));

  layout->addRow(new QLabel(tr("Settings")), new QLabel(tr("")));
  layout->addRow(new QLabel(tr("Theme:")), theme_select);
  layout->addRow(new QLabel(tr("Font:")), new QComboBox);
  layout->addRow(new QLabel(tr("Font size:")), new QComboBox);
  layout->addRow(saveButton);
  layout->addRow(cancelButton);

  // https://doc.qt.io/qt-5/qtwidgets-layouts-basiclayouts-example.html
}

bool ConfigWindow::handleReturn() { qDebug() << "ConfigWindow: returnPressed"; }

void ConfigWindow::handleKeyEvent(QKeyEvent *e) { qDebug() << "ConfigWindow: SET NEW KEYPRESS"; }

void ConfigWindow::saveSettings() {
  qDebug() << "ConfigWindow: Save settings";
  printf("Current theme:%d\n", theme_select->currentIndex());
  VALUE themeh = rb_eval_string("$opt['theme']");
  rb_hash_aset(themeh,rb_str_new2("selected"),INT2NUM(theme_select->currentIndex()));
  rb_eval_string("handle_conf_change");
}
