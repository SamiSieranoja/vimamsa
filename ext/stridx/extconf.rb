#!/usr/bin/env ruby
#

require 'mkmf'

module_name = "vimamsa"
extension_name = 'stridx'

$CXXFLAGS << " -Wall -Wno-unused-variable -O3 -fopenmp -g" 
# $CXXFLAGS << " -Wall -Wno-unused-variable -O3 "

have_library( 'stdc++');
have_library( 'gomp' );

dir_config(extension_name)       # The destination
create_makefile(extension_name)  # Create Makefile

