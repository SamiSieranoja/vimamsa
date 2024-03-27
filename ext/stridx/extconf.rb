#!/usr/bin/env ruby
#

require 'mkmf'

module_name = "vimamsa"
extension_name = 'stridx'

$CFLAGS << " -Wall "

$CXXFLAGS << " -Wall -Wno-unused-variable -O3"

have_library( 'stdc++' );

dir_config(extension_name)       # The destination
create_makefile(extension_name)  # Create Makefile

