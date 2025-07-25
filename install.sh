#!/bin/bash
gem build vimamsa.gemspec 
sudo gem uninstall vimamsa
sudo gem install --local $(ls -1tr *gem |head -n 1)
