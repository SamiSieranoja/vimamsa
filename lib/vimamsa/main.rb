#scriptdir=File.expand_path(File.dirname(__FILE__))
$:.unshift File.dirname(__FILE__) + "/lib"

# require 'benchmark/ips'

# load "vendor/ver/lib/ver/vendor/textpow.rb"
# load "vendor/ver/lib/ver/syntax/detector.rb"
# load "vendor/ver/config/detect.rb"

require "differ"
module Differ
  class Diff
    def get_raw_array()
      return @raw
    end
  end
end

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

# Globals
$command_history = []
$clipboard = []
$register = Hash.new("")
$cnf = {}
$search_dirs = []
$errors = []

$cur_register = "a"
$input_char_call_func = nil
$debuginfo = {}

$jump_sequence = []

$debug = false
$experimental = false

# Return currently active buffer
def buf()
  return $buffer
end

def bufs()
  return $buffers
end

def buflist()
  return $buffers
end

require "vimamsa/editor.rb"

# load "qt_funcs.rb"

$vma = Editor.new
def vma()
  return $vma
end

# c_startup
# run_random_jump_test
# main_loop

# debug("END")






