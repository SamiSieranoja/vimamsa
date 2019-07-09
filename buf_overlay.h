
// Draw on top of qtextedit widget
// Mainly used for drawing easy jump marks.

#ifndef BUF_OVERLAY_H
#define BUF_OVERLAY_H

#include <QMainWindow>
#include <QMap>
#include <QPointer>
#include <QTextEdit>
#include <QThread>

#include <QPainter>
#include <QWidget>

#include <QApplication>
#include <QPushButton>
#include <QHBoxLayout>
#include <QLabel>
#include <QFrame>


class Overlay : public QFrame {
  Q_OBJECT
public:
  Overlay(QWidget *parent = 0);
  int draw_text(int x, int y, char *text);

protected:
  void paintEvent(QPaintEvent *e);
};

#endif