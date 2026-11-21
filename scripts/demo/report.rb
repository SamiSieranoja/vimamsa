# Example file for the file switching demo: prints the shapes as a table
require_relative "shapes"

def report(shapes)
  puts format("%-8s %8s", "shape", "area")
  shapes.each { |s| puts format("%-8s %8.2f", s.class.name.downcase, s.area) }
end
