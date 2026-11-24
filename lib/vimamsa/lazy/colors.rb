# Stands in for the red-colors gem while GTK loads (rbvma.rb puts this dir
# first on $LOAD_PATH only around `require "gtk4"`). cairo requires "colors",
# and red-colors builds all its colormaps when loaded: 0.5 s of startup for a
# library cairo uses only in Cairo::Color.parse. The real one loads on the
# first use of Colors.
Object.autoload(:Colors, File.join($vma_red_colors_dir, "lib/colors.rb"))
