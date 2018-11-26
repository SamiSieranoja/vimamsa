QT += widgets
QT += concurrent
qtHaveModule(printsupport): QT += printsupport
QMAKE_CXXFLAGS = -fpermissive

TEMPLATE = app
TARGET = viwbaw

HEADERS = editor.h highlighter.h selectwindow.h srn_dst.h
SOURCES = editor.cpp main.cpp ruby_ext.c highlighter.cpp selectwindow.cpp srn_dst.cpp

RESOURCES += viwbaw.qrc
build_all:!build_pass {
    CONFIG -= build_all
    CONFIG += release
}
CONFIG += debug
CONFIG -= release

#unix:LIBS += -L/usr/local/lib -lruby -lpthread -lrt -ldl -lcrypt -lm
#unix:INCLUDEPATH += /usr/local/include/ruby-2.0.0/x86_64-linux /usr/local/include/ruby-2.0.0  


#unix:LIBS += -lruby-2.3 -lpthread -lrt -ldl -lcrypt -lm
#unix:INCLUDEPATH += /usr/include/x86_64-linux-gnu/ruby-2.3.0/ /usr/include/ruby-2.3.0/  


unix:LIBS += -lruby-2.5 -lpthread -lrt -ldl -lcrypt -lm
unix:INCLUDEPATH += /usr/include/x86_64-linux-gnu/ruby-2.5.0/ /usr/include/ruby-2.5.0/  

