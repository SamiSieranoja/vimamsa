Viwbaw - Vi(m) and Emacs inspired experimental text editor being written in Ruby embedded in C/C++ QT5 app. Currently in pre-alpha level.


## Install & Use

Currently developed & tested on Ubuntu 14.04.

```
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

RUN:
./viwbaw  # From program dir

KEY BINDINGS
 - Very much like VIM
 - view & edit: lib/viwbaw/key_bindings.rb
```

## Project goals


Develop key bindings and actions to find suitable compromise on the following goals:
 - Minimize strain on hands&fingers (less Ctrl-x, less keystrokes)
 - Get more work done faster with less keystrokes.
 - As easy learning curve as possible without sacrificing long term efficiency. Should have options to adapt to user's background (Emacs/bash, vim or notepad). For example, everything that works in Notepad could easily work in insert mode by default. In my opinion, Vim has currently unnecessarily steep learning curve.
 - Adaptable, supports customizing to every imaginable type of keybinding (Vim, Emacs, Notepad). Total separation of actions and key bindings.
 - Modern features such as autocomplete, [file browsing](https://github.com/scrooloose/nerdtree), [EasyMotion](https://github.com/easymotion/vim-easymotion), [ctrlp](http://kien.github.io/ctrlp.vim/), [Buffer explorer](https://github.com/jlanzarotta/bufexplorer) and remote(ssh) editing should be supported by default in program core, not as plugins.

**Experiment with new types of key bindings.**  For example, to get around [difficulties of using the Esc key](http://vim.wikia.com/wiki/Avoid_the_escape_key) in vim, switching between command and insert mode is currently done by clicking Ctrl-key (switched with caps lock) or Shift-key once (key press, key release, no other key events in between). Key bindings like ctrl-c are still supported. This seems possible only in a GUI window because, to the best of my knowledge, terminal&ncurses do not handle key release events.

Any key could be a modifier. For example, typing ['z'(keypress) 'x'(keypress) 'z'(keyrelease) 'x'(keyrelease)] could be bound to different action than ['z'(keypress)  'z'(keyrelease) 'x'(keypress) 'x'(keyrelease)].

Other points:
 - Write performance critical parts in C and/or C++, other parts in ruby. When features are more stable (not changing) they can be rewritten in C/C++.
 - Separation of key bindings and actions. Activated action is oblivious of what keypress was used to activate it. This allows for a wider range of different key bindings.
 - Asynchronous I/O
 - Use GUI for settings/configuration.
 - UTF8 by default.
 - QTextEdit is currently used in a bit hackish way. This should be replaced at some point.

Long term goals
 - Programming IDE
 - [Orgmode](http://orgmode.org/)
 - Rich text editing.

## Personal anecdote

I used Emacs for 10 uears, starting from 2001, but after a few years I got some repetitive strain injury (RSI) symptoms. Apparently those are common among Emacs users ([1](http://ergoemacs.org/emacs/emacs_hand_pain_celebrity.html), [2](http://developers.slashdot.org/story/13/08/18/198223/how-one-programmer-is-coding-faster-by-voice-than-keyboard)). I tried to switch to using Vim in the hope that the lack of ctrl-x -type key bindings would help with my RSI problems. But because of the steep learning curve with vim, and (at that time) lack of some important features like org-mode, it took me couple attempts and a few years to finally make the switch from Emacs to Vim. 

One of the major problems for me with the default Vim keybindings was that (especially for a beginner) editing with vim involves a lot of switching between insert and command modes, and to get from insert to command mode (on modern keyboards) you need to move your hand to reach the esc key. I'm not the only one who finds this difficult and [many solutions](http://vim.wikia.com/wiki/Avoid_the_escape_key) have been suggested for this problem  including switching caps lock and esc keys. The best solution I have been able to come up with is to use ctrl key (which on my keyboard is where caps lock usually is) to switch between insert mode and command mode. To also allow the use of ctrl-a, ctrl-e  keybindings in insert mode, the switching from insert to command mode has to happen on ctrl key release event. Since there are, to the best of my knowledge, no key release events on ncurses/terminal, and vi(m) is inherently a terminal application, this type of key binding was not possible in Vim without hacking the sources.

Now I have used Vim 2-3 years as a main text editor. I'm mostly satisfied with it, but a few issues makes it a bit frustrating sometimes. Some examples: 
 - Ex/vimscript extension language. Other languages poorly supported.
 - Often slows/jams for mysterious reasons, at least partly due to synchronous I/O and slow (via eval) ruby/python plugins.
 - Have to install a huge amount of plugins to make it work for everyday use.
 - Nonstandard regexp syntax
 - Closing buffer closes window.
 - Customizing keybindings is a bit limited due to Vim being a terminal application (even when inside a GUI) and keybindings and actions not being fully separated in the code. 
 - I have to switch to OpenOffice or another program with different keybindings to do simple WYSIWYG rich text editing. (Or use LaTeX)

For these and other reasons I found that writing a new Vi(m) inspired editor with a modern GUI and Ruby extensions would be a good idea.

Any questions, comments or suggestions, please send email to: sjs@kulma.net

Sami Sieranoja

