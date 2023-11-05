#scriptdir=File.expand_path(File.dirname(__FILE__))
$:.unshift File.dirname(__FILE__) + "/lib"

#/home/samsam/Drive/code/vimamsa/git/lib/vimamsa/lib/vimamsa/main.rb require 'benchmark/ips'

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

# Globals (TODO:refactor)
$command_history = []
$errors = []

$debuginfo = {}

cnf.debug = false

# Return currently active buffer
def buf()
  return vma.buf
end

def bufs()
  return vma.buffers
end

def buflist()
  return vma.buffers
end

require "vimamsa/editor.rb"

$vma = Editor.new
def vma()
  return $vma
end







