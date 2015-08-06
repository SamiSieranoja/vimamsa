QT += widgets
QT += concurrent
qtHaveModule(printsupport): QT += printsupport
QMAKE_CXXFLAGS = -fpermissive

TEMPLATE = app
TARGET = viwbaw

HEADERS = editor.h
SOURCES = editor.cpp main.cpp ruby_ext.c

RESOURCES += viwbaw.qrc
build_all:!build_pass {
    CONFIG -= build_all
    CONFIG += release
}
CONFIG += debug
CONFIG -= release

unix:LIBS += -L/usr/local/lib -lruby -lpthread -lrt -ldl -lcrypt -lm
unix:INCLUDEPATH += /usr/local/include/ruby-2.0.0/x86_64-linux /usr/local/include/ruby-2.0.0  


