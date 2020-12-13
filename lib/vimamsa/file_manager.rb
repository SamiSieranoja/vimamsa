

class FileManager
  @@cur

  def initialize()
    @buf = nil
  end

  def self.chdir_parent()
    @@cur.chdir_parent
  end

  def self.init()
    reg_act(:start_file_selector, proc { FileManager.new.run; $kbd.set_mode(:file_exp) }, "File selector")

    reg_act(:fexp_chdir_parent, proc { FileManager.chdir_parent }, "File selector")
    reg_act(:fexp_select, proc { buf.module.select_line }, "")

    bindkey "C , j f", :start_file_selector
    bindkey "C , f", :start_file_selector

    $kbd.add_minor_mode("fexp", :file_exp, :command)

    # bindkey "fexp l", [:fexp_right, proc { puts "==fexp_right==" }, ""]
    bindkey "fexp h", :fexp_chdir_parent
    bindkey "fexp esc", [:fexp_quit, proc { $kbd.set_mode(:command) }, ""]
    bindkey "fexp enter", :fexp_select
    bindkey "fexp l", :fexp_select
  end

  def chdir_parent
    dir_to_buf(fullp(".."))
  end

  def run
    @@cur = self
    ld = buflist.get_last_dir
    dir_to_buf(ld)
    # puts "ld=#{ld}"
    # dlist = Dir["#{ld}/*"]
  end

  def dir_to_buf(dirpath, b = nil)
    # File.stat("testfile").mtime
    dirpath = File.expand_path(dirpath)
    @header = []
    @header << "#{dirpath}"
    @header << "=" * 40
    @ld = dirpath
    @dlist = Dir.children(@ld).sort
    @cdirs = []
    @cfiles = []
    for x in @dlist
      if File.directory?(fullp(x))
        @cdirs << x
      else
        @cfiles << x
      end
    end

    s = ""
    s << @header.join("\n")
    s << "\n"
    s << "..\n"
    s << @cdirs.join("\n")
    s << @cfiles.join("\n")

    if @buf.nil?
      @buf = create_new_file(nil, s)
      @buf.module = self
      @buf.active_kbd_mode = :file_exp
    else
      @buf.set_content(s)
    end
    @buf.set_line_and_column_pos(@header.size, 0)
  end

  def fullp(fn)
    "#{@ld}/#{fn}"
  end

  def select_line
    return if @buf.lpos < @header.size
    # puts "def select_line"
    fn = fullp(@buf.get_current_line[0..-2])
    if File.directory?(fn)
      puts "CHDIR: #{fn}"
      dir_to_buf(fn)
    # elsif vma.can_open_extension?(fn)
      # jump_to_file(fn)
    elsif file_is_text_file(fn)
      jump_to_file(fn)
    else
      open_with_default_program(fn)
    end
    # puts l.inspect
  end
end
