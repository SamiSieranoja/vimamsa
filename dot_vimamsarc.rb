require "date"

def insert_date()
  $buffer.insert_txt("#{DateTime.now().strftime("==========\n%d.%m.%Y")}\n")
end

# In command mode (C), sequentially press keys ", i t"
bindkey "C , i t", "insert_date"

# Search dirs to find files using fast fuzzy file search (in command mode: ", f")
$search_dirs << File.expand_path("~/Documents/")

# Limit file search to these extensions:
$find_extensions = [".txt", ".h", ".c", ".cpp", ".hpp", ".rb", ".inc", ".php", ".sh", ".m", ".md"]

# After edit, copy this file to:
# cp dot_vimamsarc.rb  ~/.vimamsarc
