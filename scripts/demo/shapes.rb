# Example file for the README demo
class Shape
  def initialize(name)
    @name = name
  end

  def area
    0
  end

  def to_s
    "#{@name}: #{area.round(2)}"
  end
end

class Circle < Shape
  def initialize(radius)
    super("circle")
    @radius = radius
  end

  def area
    Math::PI * @radius**2
  end
end

shapes = [Circle.new(1), Circle.new(2.5)]
shapes.each { |s| puts s }
