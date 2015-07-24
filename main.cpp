#include "editor.h"
#include <QApplication>
#include <QThread>
#include <QtCore>
#include <QtConcurrent>


int qt_main_thread_lock = 0;
int want_main_thread_lock = 0;
int ready_for_events = 1;

int *_argc;
char** _argv;

    extern "C" {

#include <ruby.h>
#include <stdio.h>

}

HelloThread thread;

void HelloThread::run()
{
     qDebug() << "hello from worker thread " << thread()->currentThreadId();
    char **argv2 = malloc((*_argc +2)*sizeof(char*));
    char const* script_name = "editor.rb";
    argv2[0] = script_name;
    argv2[1] = script_name;
    for(int i=0;i < *_argc; i++) {
    argv2[i+2] = _argv[i];
    }
    _init_ruby(*_argc+2,argv2);

}

int main(int argc, char *argv[])
{
    _argc = &argc;
    _argv = argv;

    thread.start();
    thread.wait();
    return 0;
}
