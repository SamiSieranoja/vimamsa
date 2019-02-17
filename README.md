
Vimamsa - Vi/Vim inspired experimental GUI-oriented text editor being written in Ruby embedded in C/C++ QT5 app. 

Status: 
 - Currently in alpha level.  
 - Personally, I've managed to mostly move away from VIm to Vimamsa as my main editor, but the program still needs work to be usable for someone who doesn't know the source code.

Any questions, comments or suggestions, please send email to: sami.sieranoja@gmail.com

## Install & Use

REQUIREMENTS:
 - Ruby 2.5
 - QT 5

Instructions for Ubuntu 18.04:

Install requirements:
```
sudo apt install qtbase5-dev qtbase5-dev-tools qt5-qmake ruby2.5-dev ruby2.5
sudo gem2.5 install parallel
sudo gem2.5 install ripl ripl-multi_line # For debug
```

Packages for optional features:
```
sudo apt install ack-grep clang-format
```

To compile:
```
./make_ubuntu1804.sh 
```

RUN:
```
./vimamsa.rb
```

## Features

 - Key bindings very much like in VIm. See file lib/vimamsa/key_bindings.rb and lib/vimamsa/default_bindings.rb

LIMITATIONS
 - UTF8 only
 - Line endings with "\n"
