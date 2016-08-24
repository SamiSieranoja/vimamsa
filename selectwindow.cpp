

#include <QtWidgets>

#include "selectwindow.h"
#include "editor.h"

    SelectWindow::SelectWindow(QWidget *parent,int use_filter)
: QWidget(parent)
{

    this->use_filter=use_filter;

    cancelButton = new QPushButton(tr("&Cancel"));
    connect(cancelButton, SIGNAL(clicked()), this, SLOT(close()));

    QVBoxLayout *layout = new QVBoxLayout;

    setLayout(layout);

    //setWindowTitle(tr("Test"));

    Qt::WindowFlags flags = 0;
    //flags = Qt::Popup;
    flags = Qt::Window;
    flags |= Qt::FramelessWindowHint;
    QWidget::setWindowFlags(flags);

    if(use_filter) {
        filterEdit = new QLineEdit;
        connect(filterEdit, SIGNAL(textEdited(const QString &)), this, SLOT(filterChanged()));
        connect(filterEdit, SIGNAL(returnPressed()), this, SLOT(returnPressed()));
        filterEdit->installEventFilter(this);
    }


    proxyView = new QTreeView;
    proxyView->setAlternatingRowColors(true);
    proxyView->setSortingEnabled(true);
    connect(proxyView, SIGNAL(clicked(const QModelIndex &)), SLOT(selectItem(QModelIndex )));
    model = new QStandardItemModel(0, 3, parent);
    model->setHeaderData(0, Qt::Horizontal, QObject::tr("jmp"));
    model->setHeaderData(1, Qt::Horizontal, QObject::tr("Filename"));
    model->setHeaderData(2, Qt::Horizontal, QObject::tr("Path"));
    //model->setHeaderData(3, Qt::Horizontal, QObject::tr("Modified"));
    proxyView->setModel(model);
    if(use_filter) {
    layout->addWidget(filterEdit);
    }

    layout->addWidget(proxyView);
    layout->addWidget(cancelButton);

    proxyView->installEventFilter(this);
    //proxyView->setStyleSheet( "QTreeView::item:first{color: red; font:bold;} QTreeView::item:selected{color: red; font:bold;  background: #a8a8a8;}");
    proxyView->setStyleSheet( "QTreeView::item:first{color: red; font:bold;} QTreeView::item:selected:first{color: red; font:bold;}");
    //proxyView->setColumnWidth(0, this->width()/2); //TODO
    proxyView->setColumnWidth(1, 400); //TODO
    proxyView->setColumnWidth(0, 45); //TODO

}

void SelectWindow::filterChanged() {
    VALUE item_list;
    qDebug() << "SelectWindow: FILTER STRING CHANGED";
    qDebug() << filterEdit->text();
    item_list = rb_funcall(INT2NUM(0),update_callback, 1, qstring_to_ruby(filterEdit->text()));

    model->removeRows(0,model->rowCount());
    //model->clear();
    model->setHeaderData(0, Qt::Horizontal, QObject::tr("jmp"));
    model->setHeaderData(1, Qt::Horizontal, QObject::tr("File"));

    for(int i=0; i < RARRAY_LEN(item_list); i++) {
        VALUE d = rb_ary_entry(item_list,i);
            model->insertRow(i);
            VALUE c0 = rb_ary_entry(d,0);
            VALUE c1 = rb_ary_entry(d,1);
            //VALUE c1 = rb_ary_entry(d,1);
            //VALUE c2 = rb_ary_entry(d,2);
            //VALUE key = rb_ary_entry(jump_keys,i);
            //VALUE key = rb_ary_pop(jump_keys);
            //char* c0str = StringValueCStr( c0 );
            //model->setData(model->index(0, 0), StringValueCStr( key ));
            //model->setData(model->index(0, 0), StringValueCStr( c0 ));
            //model->setData(model->index(0, 1), StringValueCStr( c0 ));
            model->setData(model->index(i, 1), StringValueCStr( c0 ));
            //model->setData(model->index(0, 2), StringValueCStr( c1 ));
            //model->setData(model->index(0, 3), StringValueCStr( c2 ));
            //model->item(0)->setEditable(false);

    }
}

bool SelectWindow::handleReturn() {
    qDebug() << "SelectWindow: returnPressed";
}

void SelectWindow::handleKeyEvent(QKeyEvent *e) {
    qDebug() << "SelectWindow: SET NEW KEYPRESS";
}


bool SelectWindow::eventFilter(QObject *obj, QEvent *event)
{
    if (obj == filterEdit && event->type() == QEvent::KeyPress) {
        
        QKeyEvent* key = static_cast<QKeyEvent*>(event);
        //qDebug() << "eventFilter: filterEdit key event";
        if((key->key()==Qt::Key_Enter) || (key->key()==Qt::Key_Return)) {
          qDebug() << "eventFilter: got ENTER";
          // select_callback
          rb_funcall(INT2NUM(0),select_callback, 1, qstring_to_ruby(filterEdit->text()));
          return true;
        }
        return false;}
    if (event->type() == QEvent::KeyPress) {
        qDebug() << "SelectWindow: Filter Key event";
        //g_editor->processKeyEvent((QKeyEvent*) event);
        //SEditor* editor = (SEditor*)  parent();
        ((SEditor*) parent())->processKeyEvent((QKeyEvent*) event);

            //g_editor->processKeyEvent((QKeyEvent*) event);
        return true;
    }
    return false;
}

SelectWindow::setItems(VALUE item_list, VALUE jump_keys) {
    //model->insertRow(0);
    //model->setData(model->index(0, 0), "buffer.rb");
    //model->setData(model->index(0, 1), "~/foo/src");
    //model->setData(model->index(0, 2), "");


    //while(RARRAY_LEN(item_list) > 0) {
    for(int i=0; i < RARRAY_LEN(item_list); i++) {
        //VALUE d = rb_ary_shift(item_list);
        //VALUE d = rb_ary_pop(item_list);
        VALUE d = rb_ary_entry(item_list,i);
            model->insertRow(0);
            VALUE c0 = rb_ary_entry(d,0);
            VALUE c1 = rb_ary_entry(d,1);
            VALUE c2 = rb_ary_entry(d,2);
            VALUE key = rb_ary_entry(jump_keys,i);
            //VALUE key = rb_ary_pop(jump_keys);
            //char* c0str = StringValueCStr( c0 );
            model->setData(model->index(0, 0), StringValueCStr( key ));
            model->setData(model->index(0, 1), StringValueCStr( c0 ));
            model->setData(model->index(0, 2), StringValueCStr( c1 ));
            //model->setData(model->index(0, 3), StringValueCStr( c2 ));
            model->item(0)->setEditable(false);
                        //
            //model->setData(model->index(0, 0), StringValueCStr( rb_ary_entry(d,0) ));
    }
    //connect(proxyView, SIGNAL(itemClicked(QTreeWidgetItem *,int)), this, SLOT(close()));
    //connect(proxyView, SIGNAL(itemClicked(QTreeWidgetItem *,int)), SLOT(close()));

        // connect(proxyView, SIGNAL(clicked(const QModelIndex &)), SLOT(selectItem(QModelIndex )));

}

void SelectWindow::selectItem(QModelIndex index) {
    printf("ITEM %d CLICKED\n",index.row());
    rb_funcall(NULL,rb_intern("gui_select_buffer_callback"),1,INT2NUM(index.row()));
    //close();

}

