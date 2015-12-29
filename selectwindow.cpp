

#include <QtWidgets>

#include "selectwindow.h"
#include "editor.h"

    SelectWindow::SelectWindow(QWidget *parent)
: QWidget(parent)
{

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
    
    QLineEdit *lineEdit = new QLineEdit;


    proxyView = new QTreeView;
    proxyView->setAlternatingRowColors(true);
    proxyView->setSortingEnabled(true);
    model = new QStandardItemModel(0, 3, parent);
    model->setHeaderData(0, Qt::Horizontal, QObject::tr("jmp"));
    model->setHeaderData(1, Qt::Horizontal, QObject::tr("Filename"));
    model->setHeaderData(2, Qt::Horizontal, QObject::tr("Path"));
    //model->setHeaderData(3, Qt::Horizontal, QObject::tr("Modified"));
    proxyView->setModel(model);
    layout->addWidget(lineEdit);

    layout->addWidget(proxyView);
    layout->addWidget(cancelButton);

    proxyView->installEventFilter(this);
    //proxyView->setStyleSheet( "QTreeView::item:first{color: red; font:bold;} QTreeView::item:selected{color: red; font:bold;  background: #a8a8a8;}");
    proxyView->setStyleSheet( "QTreeView::item:first{color: red; font:bold;} QTreeView::item:selected:first{color: red; font:bold;}");
}


void SelectWindow::handleKeyEvent(QKeyEvent *e) {
    qDebug() << "SelectWindow: SET NEW KEYPRESS";
}


bool SelectWindow::eventFilter(QObject *object, QEvent *event)
{
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

        connect(proxyView, SIGNAL(clicked(const QModelIndex &)), SLOT(selectItem(QModelIndex )));

}

void SelectWindow::selectItem(QModelIndex index) {
    printf("ITEM %d CLICKED\n",index.row());
    rb_funcall(NULL,rb_intern("gui_select_buffer_callback"),1,INT2NUM(index.row()));
    //close();

}

