#!/bin/bash
cp vimamsa.pro_ubuntu1804 vimamsa.pro
qmake -qt=qt5
make clean;
make
