class Converter
  def initialize(obj, type, id = nil)
    @obj = obj
    @type = type
    if id != nil
      $vma.reg_conv(self, id)
    end
  end

  def apply(txt)
    if @type == :gsub
      return txt.gsub(@obj[0], @obj[1])
    elsif @type == :lambda
      return @obj.call(txt)
    end
  end
end

c = Converter.new(lambda { |x| x.split("\n").collect{|x|r=x.strip}.select{|y|!y.empty?}.join(" ") +"\n"}, :lambda, :joinlines)

