#!/usr/bin/env ruby
#

require 'mkmf'

module_name = "vimamsa"
extension_name = 'vmaext'

# $CFLAGS << " -Wall -fpermissive "
# $CXXFLAGS << " -Wall -fpermissive "

# have_library( 'stdc++' );

dir_config(extension_name)       # The destination
create_makefile(extension_name)  # Create Makefile

