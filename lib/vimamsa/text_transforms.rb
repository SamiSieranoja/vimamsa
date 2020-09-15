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

Converter.new(lambda { |x| x.split("\n").collect{|x|r=x.strip}.select{|y|!y.empty?}.join(" ") +"\n"}, :lambda, :joinlines)

Converter.new(lambda { |x| x.split("\n").sort.join("\n") }, :lambda, :sortlines)
Converter.new(lambda { |x| x.split(/\s+/).sort.join(" ") }, :lambda, :sortwords)
Converter.new(lambda { |x| x.split("\n").collect { |b| b.scan(/(\d+(\.\d+)?)/).collect { |c| c[0] }.join(" ") }.join("\n") }, :lambda, :getnums_on_lines)


Converter.new(lambda { |x| x+"\n"+x.split("\n").collect { |b| b.scan(/(\d+(\.\d+)?)/).collect { |c| c[0] }.join(" ") }.join("\n") }, :lambda, :getnums_on_lines)



