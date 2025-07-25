# Vimamsa

Vi/Vim -inspired experimental GUI-oriented text editor written with Ruby and GTK.

<!-- toc -->

- [Requirements](#requirements)
- [Installation](#installation)
  * [Other install options](#other-install-options)
- [Run](#run)
- [Screenshots](#screenshots)
- [Key bindings](#key-bindings)
- [Current limitations](#current-limitations)

<!-- tocstop -->

## Requirements
 - Ruby 3.0+
 - GTK 4


## Installation


On Ubuntu (22.04):
```
sudo apt install ruby-dev build-essential
sudo gem install vimamsa
```

Run:
```
vimamsa
```

### Other install options

Install from sources:

```
git clone https://github.com/SamiSieranoja/vimamsa.git
cd vimamsa
gem build vimamsa.gemspec 
sudo gem install --local vimamsa-0.1.*.gem

```

Older version for GTK3:

    sudo gem install vimamsa -v 0.1.10

## Run
```
vimamsa
```

Install packages for optional features:
```
sudo apt install ack-grep clang-format
```

For customization, edit ~/.vimamsa/custom.rb

## Screenshots

<a href="https://samiddhi.net/vimamsa/screenshot1.png" target="_blank"><img src="https://samiddhi.net/vimamsa/screenshot1.png" width="400"/></a>
<a href="https://samiddhi.net/vimamsa/screenshot2.png" target="_blank"><img src="https://samiddhi.net/vimamsa/screenshot2.png" width="400"/></a>

## Key bindings

Key bindings are very much like in VIm. For details, see menu item "Help -> Show key bindings" and file lib/vimamsa/key_bindings_vimlike.rb

Keys that work somewhat similarly as in Vim:

In Command mode: 
```
j k l h w b p P G f F ; 0 $ v i o  J * / a A I u ctrl-r x 
zz dd dw gg <linenum>G r<char>
```

In Visual mode:
```
d y gU gu 
```

Keys that work differently to Vim are documented in the tables below

Syntax:  

 - ctrl! means press and immediate release of ctrl key. Triggered by key up event when no other keys were pressed between key down and key up events.
 - ctrl-x means press and hold ctrl key, press x  

<table>
<colgroup>
<col style="text-align:center;"/>
<col style="text-align:left;"/>
</colgroup>

<thead> <tr> <th style="text-align:center;" colspan="4">Command mode keys</th> </tr> </thead>

<tbody>
<tr><th>Key</th><th>Action</th></tr>
<tr><td style="text-align:center;">ctrl!</td>     <td style="text-align:left;">switch between command and insert modes</td> </tr>
<tr> <td style="text-align:center;">z</td> <td style="text-align:left;"> enter into BROWSE mode</td></tr>
<tr>     <td style="text-align:center;">shift!</td>     <td style="text-align:left;">save file</td> </tr>
<tr>     <td style="text-align:center;">s</td>     <td style="text-align:left;">Easy jump (Similar to Vim EasyMotion https://github.com/easymotion/vim-easymotion ) </td> </tr>
<tr> <td style="text-align:center;">tab</td> <td style="text-align:left;">switch betwen current and previous buffer/file</td></tr>
<tr> <td style="text-align:center;">enter</td> <td style="text-align:left;"> (when cursor on link) open url in browser </td></tr>
<tr> <td style="text-align:center;">enter</td> <td style="text-align:left;">(when cursor on /path/to/file.txt:linenum ) open file in editor, jump to linenum </td></tr>
<tr> <td style="text-align:center;">,a</td> <td style="text-align:left;">Search for string using ack
</td></tr>
<tr> <td style="text-align:center;">,b</td> <td style="text-align:left;"> Switch buffer (jump to other open file)</td></tr>
<tr> <td style="text-align:center;">,g</td> <td style="text-align:left;">search for input string inside current buffer</td></tr>
<tr> <td style="text-align:center;">,f</td> <td style="text-align:left;">File finder</td></tr>
<tr> <td style="text-align:center;">space c</td> <td style="text-align:left;">insert character "c"</td></tr>
</tbody>
</table>

<table>
<colgroup>
<col style="text-align:center;"/>
<col style="text-align:left;"/>
</colgroup>

<thead> <tr> <th style="text-align:center;" colspan="4">Insert mode keys (similar to bash or emacs)</th> </tr> </thead>

<tbody>
<tr> <td style="text-align:center;">ctrl! OR esc</td> <td style="text-align:left;">Switch to command mode</td></tr>
<tr> <td style="text-align:center;">ctrl-n</td> <td style="text-align:left;">Move to next line</td></tr>
<tr> <td style="text-align:center;">ctrl-p</td> <td style="text-align:left;">Move to previous line</td></tr>
<tr> <td style="text-align:center;">ctrl-a</td> <td style="text-align:left;">Move beginning of line</td></tr>
<tr> <td style="text-align:center;">ctrl-e</td> <td style="text-align:left;">Move to end of line</td></tr>
<tr> <td style="text-align:center;">ctrl-b</td> <td style="text-align:left;">Move backward one char</td></tr>
<tr> <td style="text-align:center;">ctrl-f</td> <td style="text-align:left;">Move forward one char</td></tr>
<tr> <td style="text-align:center;">alt-f</td> <td style="text-align:left;">Move forward one word</td></tr>
<tr> <td style="text-align:center;">alt-b</td> <td style="text-align:left;">Move backward one word</td></tr>
</tbody>
</table>


<table>
<colgroup>
<col style="text-align:center;"/>
<col style="text-align:left;"/>
</colgroup>

<thead> <tr> <th style="text-align:center;" colspan="4">Browse mode keys</th> </tr> </thead>

<tbody>
<tr> <td style="text-align:center;">h</td> <td style="text-align:left;">jump to previous buffer in history</td></tr>
<tr> <td style="text-align:center;">l</td> <td style="text-align:left;">jump to next buffer in history</td></tr>
<tr> <td style="text-align:center;">q</td> <td style="text-align:left;">jump to previous edited position</td></tr>
<tr> <td style="text-align:center;">w</td> <td style="text-align:left;">jump to next edited position</td></tr>
<tr> <td style="text-align:center;">j OR esc</td> <td style="text-align:left;">switch from browse to command mode</td></tr>
</tbody>
</table>

Bindings can be customized in ~/.vimamsa/custom.rb
For example, to bind ctrl-n to action "create new file":  
```
bindkey 'C ctrl-n',  'create_new_file()'
```


## Known issues
 - Cursor sometimes vanishes when dragging or resizing the window. At least some cases are fixed in new GTK4 versions ( >= 4.18, in Ubuntu Ubuntu 25.04). Workaround is to press ctrl key twice.

## Current limitations
 - UTF8 only
 - Line endings with "\n"


