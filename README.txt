
REQUIREMENTS:
 - Ruby 2.0.0
 - QT 5

RUBY INSTALL:
wget http://cache.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p645.tar.gz
./configure --enable-shared && make && sudo make install
ldconfig #(update cache)

Ubuntu packages:
sudo apt-get install qtbase5-dev
ruby2.0-dev # does not have all required sources for embedding
ruby2.0

BUILD:
qmake -qt=qt5
make

