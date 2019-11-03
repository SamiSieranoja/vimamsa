
#include <QtWidgets>

#include "selectwindow.h"
#include "editor.h"
#include "globals.h"

SelectWindow::SelectWindow(QWidget *parent, int use_filter) : QWidget(parent) {

  this->use_filter = use_filter;
  this->selected_row = 0;

  cancelButton = new QPushButton(tr("&Cancel"));
  connect(cancelButton, SIGNAL(clicked()), this, SLOT(close()));

  QVBoxLayout *layout = new QVBoxLayout;

  setLayout(layout);

  // setWindowTitle(tr("Test"));

  Qt::WindowFlags flags = 0;
  // flags = Qt::Popup;
  flags = Qt::Window;
  flags |= Qt::FramelessWindowHint;
  flags |= Qt::WindowStaysOnTopHint;
  QWidget::setWindowFlags(flags);

  if (use_filter) {
    filterEdit = new QLineEdit;
    connect(filterEdit, SIGNAL(textEdited(const QString &)), this, SLOT(filterChanged()));
    connect(filterEdit, SIGNAL(returnPressed()), this, SLOT(returnPressed()));
    filterEdit->installEventFilter(this);
  }

  proxyView = new QTreeView;
  proxyView->setAlternatingRowColors(true);
  proxyView->setSortingEnabled(true);
  // proxyView->setTextElideMode(Qt::ElideLeft);
  proxyView->setTextElideMode(Qt::ElideMiddle);

  connect(proxyView, SIGNAL(clicked(const QModelIndex &)), SLOT(selectItem(QModelIndex)));
  model = new QStandardItemModel(0, 3, parent);
  model->setHeaderData(0, Qt::Horizontal, QObject::tr("jmp"));
  model->setHeaderData(1, Qt::Horizontal, QObject::tr("Filename"));
  model->setHeaderData(2, Qt::Horizontal, QObject::tr("Path"));
  // model->setHeaderData(3, Qt::Horizontal, QObject::tr("Modified"));
  proxyView->setModel(model);

  QLabel *action_nfo = new QLabel(this);
  action_nfo->setText("Action");
  layout->addWidget(action_nfo);

  if (use_filter) {
    layout->addWidget(filterEdit);
  }

  layout->addWidget(proxyView);
  layout->addWidget(cancelButton);

  proxyView->installEventFilter(this);
  // proxyView->setStyleSheet( "QTreeView::item:first{color: red; font:bold;}
  // QTreeView::item:selected{color: red; font:bold;  background: #a8a8a8;}");
  proxyView->setStyleSheet("QTreeView::item:first{color: red; font:bold;} "
                           "QTreeView::item:selected:first{color: red; font:bold;}");
  // proxyView->setColumnWidth(0, this->width()/2); //TODO
  proxyView->setColumnWidth(1, 400); // TODO
  proxyView->setColumnWidth(0, 45);  // TODO
}

SelectWindow::SelectWindow(QWidget *parent, VALUE params) : QWidget(parent) {

  cancelButton = new QPushButton(tr("&Cancel"));
  connect(cancelButton, SIGNAL(clicked()), this, SLOT(close()));
  cancelButton->installEventFilter(this);

  // QVBoxLayout *layout = new QVBoxLayout;
  QFormLayout *layout = new QFormLayout;

  setLayout(layout);

  Qt::WindowFlags flags = 0;
  // flags = Qt::Popup;
  flags = Qt::Window;
  flags |= Qt::FramelessWindowHint;
  flags |= Qt::WindowStaysOnTopHint;
  QWidget::setWindowFlags(flags);

  QLabel *action_nfo = new QLabel(this);
  VALUE title = rb_hash_lookup(params, rb_str_new2("title"));
  if (title != Qnil) {
    action_nfo->setText(StringValueCStr(title));
    layout->addRow(action_nfo);
  }

  VALUE input1 = rb_hash_lookup(params, rb_str_new2("input1"));
  VALUE input1_label = rb_hash_lookup(params, rb_str_new2("input1_label"));
  VALUE input2 = rb_hash_lookup(params, rb_str_new2("input2"));
  VALUE input2_label = rb_hash_lookup(params, rb_str_new2("input2_label"));

  VALUE button1 = rb_hash_lookup(params, rb_str_new2("button1"));

  QLabel *input1_qt_label = new QLabel(this);
  QLabel *input2_qt_label = new QLabel(this);
  if (input1 != Qnil) {
    input1_lineedit = new QLineEdit;
    input1_qt_label->setText(StringValueCStr(input1_label));
    input1_lineedit->installEventFilter(this);
    layout->addRow(input1_qt_label, input1_lineedit);
    num_inputs = 1;
  }
  if (input2 != Qnil) {
    input2_qt_label->setText(StringValueCStr(input2_label));
    input2_lineedit = new QLineEdit;
    layout->addRow(input2_qt_label, input2_lineedit);
    input2_lineedit->installEventFilter(this);
    num_inputs = 2;
  }

  if (button1 != Qnil) {
    qt_button1 = new QPushButton(StringValueCStr(button1));
    layout->addRow(qt_button1);
    qt_button1->installEventFilter(this);
    connect(qt_button1, SIGNAL(clicked()), this, SLOT(runCallback()));
  }

  callback = Qnil;
  VALUE r_callback = rb_hash_lookup(params, rb_str_new2("callback"));
  callback = rb_hash_lookup(params, rb_str_new2("callback"));

  layout->addRow(cancelButton);
}

void SelectWindow::filterChanged() {
  VALUE item_list;
  qDebug() << "SelectWindow: FILTER STRING CHANGED";
  qDebug() << filterEdit->text();
  item_list = rb_funcall(INT2NUM(0), update_callback, 1, qstring_to_ruby(filterEdit->text()));

  model->removeRows(0, model->rowCount());
  // model->clear();
  model->setHeaderData(0, Qt::Horizontal, QObject::tr("jmp"));
  model->setHeaderData(1, Qt::Horizontal, QObject::tr("File"));

  for (int i = 0; i < RARRAY_LEN(item_list); i++) {
    VALUE d = rb_ary_entry(item_list, i);
    model->insertRow(i);
    VALUE c0 = rb_ary_entry(d, 0);
    VALUE c1 = rb_ary_entry(d, 1);
    model->setData(model->index(i, 1), StringValueCStr(c0));
    // model->item(0)->setEditable(false);
  }
  if (RARRAY_LEN(item_list) > this->selected_row) {
    proxyView->setCurrentIndex(model->index(this->selected_row, 0));
    // QModelIndex indx = proxyView->currentIndex();
    // printf("ROW=%d\n", indx.row());
  }
}

bool SelectWindow::handleReturn() { qDebug() << "SelectWindow: returnPressed"; }

void SelectWindow::handleKeyEvent(QKeyEvent *e) { qDebug() << "SelectWindow: SET NEW KEYPRESS"; }

bool SelectWindow::eventFilter(QObject *obj, QEvent *event) {

  QKeyEvent *key;
  if (event->type() == QEvent::KeyPress) {
    key = static_cast<QKeyEvent *>(event);
  }

  if (event->type() == QEvent::KeyPress) {
    // qDebug() << "eventFilter: got key press";
    if (key->key() == Qt::Key_Escape) {
      // qDebug() << "eventFilter: got ESC";
      close();
      return true;
    }
    // return false;
  }

  if (event->type() == QEvent::KeyPress && obj == cancelButton) {
    if ((key->key() == Qt::Key_Enter) || (key->key() == Qt::Key_Return)) {
      close();
      return true;
    }
  }
  if (obj == cancelButton) {
    return false;
  }

  // TODO: pass events to ruby event handler
  if (obj == filterEdit && event->type() == QEvent::KeyPress) {

    // QKeyEvent *key = static_cast<QKeyEvent *>(event);
    if ((key->key() == Qt::Key_Enter) || (key->key() == Qt::Key_Return)) {
      // qDebug() << "eventFilter: got ENTER";
      close();
      rb_funcall(INT2NUM(0), select_callback, 2, qstring_to_ruby(filterEdit->text()),
                 INT2NUM(this->selected_row));
      return true;
    }
    if (key->key() == Qt::Key_Escape) {
      // qDebug() << "eventFilter: got ESC";
      close();
      return true;
    }
    if (key->key() == Qt::Key_Down) {
      this->selected_row += 1;
      proxyView->setCurrentIndex(model->index(this->selected_row, 0));
      return true;
    }
    if (key->key() == Qt::Key_Up) {
      this->selected_row -= 1;
      if (this->selected_row < 0) {
        this->selected_row = 0;
      }
      proxyView->setCurrentIndex(model->index(this->selected_row, 0));
      return true;
    }

    return false;
  }

  if (event->type() == QEvent::KeyPress && obj == qt_button1) {
    if ((key->key() == Qt::Key_Enter) || (key->key() == Qt::Key_Return)) {
      // qDebug() << "qt_button1: ENTER!!";
      runCallback();
      return true;
    }
    return false;
  }

  else if (event->type() == QEvent::KeyPress && obj == input2_lineedit) {
    if ((key->key() == Qt::Key_Enter) || (key->key() == Qt::Key_Return)) {
      // qDebug() << "input2_lineedit: ENTER!!";
      runCallback();
      return true;
    }
    return false;
  } else if (event->type() == QEvent::KeyPress && obj == input1_lineedit) {
    if ((key->key() == Qt::Key_Enter) || (key->key() == Qt::Key_Return)) {
      // qDebug() << "input1_lineedit: ENTER!!";
      runCallback();
      return true;
    }
    return false;
  }

  else if (event->type() == QEvent::KeyPress) {
    // Process event with ruby
    ((BufferWidget *)parent())->processKeyEvent((QKeyEvent *)event);
    return true;
  }

  return false;
}

void SelectWindow::runCallback() {
  // TODO: make this more flexible
  if (num_inputs == 1 && callback != Qnil) {
    rb_funcall(callback, rb_intern("call"), 1, qstring_to_ruby(input1_lineedit->text()));
  } else if (num_inputs == 2) {
    rb_funcall(callback, rb_intern("call"), 2, qstring_to_ruby(input1_lineedit->text()), qstring_to_ruby(input2_lineedit->text())  );

    // rb_funcall(NULL, callback, 2, qstring_to_ruby(input1_lineedit->text()),
    // qstring_to_ruby(input2_lineedit->text()));
  }
  close();
  rb_eval_string("render_buffer($buffer)"); // HACK
}

SelectWindow::setItems(VALUE item_list, VALUE jump_keys) {

  for (int i = 0; i < RARRAY_LEN(item_list); i++) {
    VALUE d = rb_ary_entry(item_list, i);
    model->insertRow(0);
    VALUE c0 = rb_ary_entry(d, 0);
    VALUE c1 = rb_ary_entry(d, 1);
    VALUE c2 = rb_ary_entry(d, 2);
    VALUE key = rb_ary_entry(jump_keys, i);
    model->setData(model->index(0, 0), StringValueCStr(key));
    model->setData(model->index(0, 1), StringValueCStr(c0));
    model->setData(model->index(0, 2), StringValueCStr(c1));
    model->item(0)->setEditable(false);
  }
}

void SelectWindow::selectItem(QModelIndex index) {
  this->selected_row = index.row();
  // printf("ITEM %d CLICKED\n", index.row());
  // TODO: When double clicked:
  // rb_funcall(NULL, rb_intern("gui_select_buffer_callback"), 1, INT2NUM(index.row()));
  // close();
}
