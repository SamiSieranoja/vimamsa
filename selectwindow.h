

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
    SelectWindow(QWidget *parent = 0);
    setItems(VALUE item_list, VALUE jump_keys);
    VALUE callback;

private:
    QPushButton *cancelButton;
    QTreeView *proxyView;
    QStandardItemModel *model;
    void SelectWindow::handleKeyEvent(QKeyEvent*);
    bool SelectWindow::eventFilter(QObject *object, QEvent *event);

public slots:
    void selectItem(QModelIndex index);


};

#endif
