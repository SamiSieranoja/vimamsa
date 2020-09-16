

#ifndef PREVIEWWINDOW_H
#define PREVIEWWINDOW_H
#include <QWidget>
#include <QtWidgets>
#include <QObject>
#include "buffer_widget.h"

extern "C" {
#include <ruby.h>
}

QT_BEGIN_NAMESPACE
class QPushButton;
class QTreeWidget;
QT_END_NAMESPACE

class SelectWindow : public QWidget
{
    Q_OBJECT

public:
    SelectWindow(QWidget *parent,int use_filter);
    SelectWindow(QWidget *parent,VALUE params);
    void setItems(VALUE item_list, VALUE jump_keys);
    ID callback;
    ID update_callback;
    ID select_callback;
    int selected_row;

private:
    QPushButton *cancelButton;
    QPushButton *qt_button1;
    QPushButton *qt_button2;
    QTreeView *proxyView;
    QStandardItemModel *model;
    QLineEdit* filterEdit;
    QLineEdit* input1_lineedit;
    QLineEdit* input2_lineedit;
    int use_filter;
    int num_inputs;
    void handleKeyEvent(QKeyEvent*);
    bool eventFilter(QObject *object, QEvent *event);
    bool handleReturn();
    

public slots:
    void runCallback();
    void selectItem(QModelIndex index);
    void filterChanged();
    void updateItemList(VALUE item_list); 

};

#endif
