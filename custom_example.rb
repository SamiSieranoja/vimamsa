# Examples for customization

# Extract unique words
# c = Converter.new(lambda { |x| h = {}; x.split(/\s+/).each { |y| h[y] = 1 }; h.keys.join(" ") }, :lambda, :uniqwords)

# Eval selected text as ruby code (e.g. use as calculator)
# bindkey "V , e", "vma.buf.convert_selected_text(:eval)"
# syntax: bindkey "mode key1 key2 ..."

# Execute in new gnome-terminal tab
# bindkey "C , , t", :execute_current_line_in_terminal

# setcnf :tab_width, 4

# Open this file every time the program starts
# setcnf :startup_file, "~/Documents/startup.txt"

def insert_date()
  # $buffer.insert_txt("#{DateTime.now().strftime("==========\n%Y-%m-%d")}\n")
  vma.buf.insert_txt("#{DateTime.now().strftime("%Y-%m-%d")}\n")
end

def collect_c_header()
  # Matches e.g.:
  # static void funcname(parameters)
  s = buf.scan(/^(
  ([\w\*\:&]+\s*){1,3}
  [\*?\w\:&]+
  \(
     ([^\)]|\n)*?
  \)
  )
  /x
  ).collect { |x| x[0] + ";" }.join("\n")
  buf.insert_txt(s)
end

reg_act(:collect_c_header, proc { collect_c_header }, "Collect function definitions for c header file")

# Extract all numbers from txt selection
c = Converter.new(lambda { |x| x.scan(/([\+\-]?\d+(\.\d+)?)/).collect { |x| x[0] }.join(" ") }, :lambda, :getnums)
# (find converter using action search input:"conv getnum")


def insert_lorem_ipsum()
  lorem_ipsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis sollicitudin mauris. Integer in mauris eu nibh euismod gravida. Duis ac tellus et risus vulputate vehicula. Donec lobortis risus a elit. Etiam tempor. Ut ullamcorper, ligula eu tempor congue, eros est euismod turpis, id tincidunt sapien risus a quam. Maecenas fermentum consequat mi. Donec fermentum. Pellentesque malesuada nulla a mi. Duis sapien sem, aliquet nec, commodo eget, consequat quis, neque. Aliquam faucibus, elit ut dictum aliquet, felis nisl adipiscing sapien, sed malesuada diam lacus eget erat. Cras mollis scelerisque nunc. Nullam arcu. Aliquam consequat. Curabitur augue lorem, dapibus quis, laoreet et, pretium ac, nisi. Aenean magna nisl, mollis quis, molestie eu, feugiat in, orci. In hac habitasse platea dictumst."

  # Insert to current position
  vma.buf.insert_txt(lorem_ipsum)
end

# Find with action search ([C] , , s) 
reg_act(:insert_lorem_ipsum, proc { insert_lorem_ipsum }, "Insert lorem ipsum")


