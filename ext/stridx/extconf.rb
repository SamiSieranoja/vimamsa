#!/usr/bin/env ruby
#

require 'mkmf'

module_name = "vimamsa"
extension_name = 'stridx'

$CFLAGS << " -Wall "
# $CFLAGS << " -Wall -fopenmp "

# OpenMP Generates symbol lookup error: ...stridx.so: undefined symbol: omp_init_lock
# Workaround is to run with LD_PRELOAD=/usr/lib/gcc/x86_64-linux-gnu/12/libgomp.so
# $CXXFLAGS << " -Wall -Wno-unused-variable -O3 -g -fpermissive -fopenmp"
$CXXFLAGS << " -Wall -Wno-unused-variable -O3 -g -fpermissive"

have_library( 'stdc++', 'gomp' );

dir_config(extension_name)       # The destination
create_makefile(extension_name)  # Create Makefile

