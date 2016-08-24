

#ifndef PREVIEWWINDOW_H
#define PREVIEWWINDOW_H
#include <QWidget>
#include <QtWidgets>
#include <QObject>

extern "C" {
#include <ruby.h>
}

QT_BEGIN_NAMESPACE
class QPushButton;
/*class QLineEdit;*/
class QTreeWidget;
QT_END_NAMESPACE

class SelectWindow : public QWidget
{
    Q_OBJECT

public:
    SelectWindow(QWidget *parent,int use_filter);
    setItems(VALUE item_list, VALUE jump_keys);
    ID callback;
    ID update_callback;
    ID select_callback;

private:
    QPushButton *cancelButton;
    QTreeView *proxyView;
    QStandardItemModel *model;
    QLineEdit* filterEdit;
    int use_filter;
    void SelectWindow::handleKeyEvent(QKeyEvent*);
    bool SelectWindow::eventFilter(QObject *object, QEvent *event);
    bool SelectWindow::handleReturn();

public slots:
    void selectItem(QModelIndex index);
    void filterChanged();


};

#endif
