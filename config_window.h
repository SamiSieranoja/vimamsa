

#ifndef CONFIG_WINDOW_H
#define CONFIG_WINDOW_H
#include <QWidget>
#include <QtWidgets>
#include <QObject>
#include <QComboBox>
#include "config_window.h"

extern "C" {
#include <ruby.h>
}

QT_BEGIN_NAMESPACE
class QPushButton;
/*class QLineEdit;*/
class QTreeWidget;
QT_END_NAMESPACE

class ConfigWindow : public QWidget
{
    Q_OBJECT

public:
    ConfigWindow(QWidget *parent,int use_filter);

private:
    QPushButton *cancelButton;
    QPushButton *saveButton;
    
    QTreeView *proxyView;
    QStandardItemModel *model;
    QLineEdit* filterEdit;
    int use_filter;
    void ConfigWindow::handleKeyEvent(QKeyEvent*);
    // bool ConfigWindow::eventFilter(QObject *object, QEvent *event);
    bool ConfigWindow::handleReturn();
    QComboBox *theme_select;

public slots:
    void saveSettings();

};

#endif

