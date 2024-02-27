require "fileutils"

class FileManager
  @@cur

  def initialize()
    @buf = nil
    @cut_files = []
    @copied_files = []
  end

  def self.chdir_parent()
    @@cur.chdir_parent
  end

  def self.cur()
    return @@cur
  end

  def self.init()
    reg_act(:start_file_selector, proc { FileManager.new.run; vma.kbd.set_mode(:file_exp); }, "File selector")

    reg_act(:fexp_chdir_parent, proc { FileManager.chdir_parent }, "File selector")
    reg_act(:fexp_select, proc { buf.module.select_line }, "")

    reg_act(:fexp_sort_mtime, proc { FileManager.cur.sort_mtime }, "Sort based on time")
    reg_act(:fexp_sort_fname, proc { FileManager.cur.sort_fname }, "Sort based on file name")

    bindkey "C , j f", :start_file_selector
    bindkey "C , f", :start_file_selector

    # bindkey "C o", :delete_state

    vma.kbd.add_minor_mode("fexp", :file_exp, :command)

    bindkey "fexp o m", :fexp_sort_mtime
    bindkey "fexp o f", :fexp_sort_fname

    # These are not yet safe to use
    if cnf.fexp.experimental?
      reg_act(:fexp_cut_file, proc { FileManager.cur.cut_file }, "Cut file (to paste elsewhere)")
      reg_act(:fexp_copy_file, proc { FileManager.cur.copy_file }, "Copy file (to paste elsewhere)")
      reg_act(:fexp_delete_file, proc { FileManager.cur.delete_file }, "Delete current file")
      reg_act(:fexp_paste_files, proc { FileManager.cur.paste_files }, "Move previously cut files here")

      bindkey "fexp d d", :fexp_cut_file
      bindkey "fexp y y", :fexp_copy_file
      bindkey "fexp d D", :fexp_delete_file
      bindkey "fexp p p", :fexp_paste_files
    end

    # bindkey "fexp l", [:fexp_right, proc { debug "==fexp_right==" }, ""]
    bindkey "fexp h", :fexp_chdir_parent
    bindkey "fexp esc", [:fexp_quit, proc { FileManager.cur.quit }, ""]
    bindkey "fexp enter", :fexp_select
    bindkey "fexp l", :fexp_select

    @sort_by = :name
  end

  def chdir_parent
    dir_to_buf(fullp(".."))
  end

  def run
    @@cur = self
    ld = buflist.get_last_dir
    dir_to_buf(ld)
    # debug "ld=#{ld}"
    # dlist = Dir["#{ld}/*"]
  end

  def sort_mtime
    @sort_by = :mtime
    dir_to_buf(@ld)
  end

  def sort_fname
    @sort_by = :name
    dir_to_buf(@ld)
  end

  def paste_files
    if !@cut_files.empty?
      message "MOVE FILES #{@cut_files.join(",")} TO #{@ld} "
      # Thread.new {
      for fn in @cut_files
        FileUtils.move(fn, @ld)
        debug "FileUtils.move(#{fn}, #{@ld})"
      end
    elsif !@copied_files.empty?
      for fn in @copied_files
        bn = File.basename(fn)
        bnwe = File.basename(fn, ".*")
        ext = File.extname(fn)
        dst = "#{@ld}/#{bn}"
        break if !File.exist?(fn)
        if dst == fn #or File.exist?(dst)
          i = 1
          exists = true
          while File.exist?(dst)
            dst = "#{@ld}/#{bnwe}_copy#{i}#{ext}"
            i += 1
          end
        elsif File.exist?(dst)
          message("File #{dst} already exists")
          break
          #TODO: confirm if user wants to replace existing file
        end
        message "FileUtils.copy_entry(#{fn}, #{dst})"
        FileUtils.copy_entry(fn, dst, preserve = false, dereference_root = false, remove_destination = false)
      end
    else
      message "Nothing to paste, cut/copy some files first!"
      return
    end
    # }
    @cut_files = []
    @copied_files = []
    refresh
  end

  def cut_file
    fn = cur_file
    debug "CUT FILE #{fn}", 2
    @cut_files << fn if !@cut_files.include?(fn)
    @copied_files = []
  end

  def copy_file
    fn = cur_file
    debug "COPY FILE #{fn}", 2
    @copied_files << fn
    @cut_files = []
  end

  def delete_file_confirmed(*args)
    debug args, 2
    fn = @file_to_delete
    message "Deleting file #{fn}"
    # FileUtils.remove_file(fn)
    FileUtils.remove_entry_secure(fn, force = false)
    refresh
  end

  def delete_file
    fn = cur_file
    if File.file?(fn)
      @file_to_delete = fn #TODO: set as parameter to confirm_box
      Gui.confirm("Delete the file? \r #{fn}",
                  self.method("delete_file_confirmed"))
    elsif File.directory?(fn)
      @file_to_delete = fn #TODO: set as parameter to confirm_box
      Gui.confirm("Delete the directory? \r #{fn}",
                  self.method("delete_file_confirmed"))
    else
      message "Can't delete #{fn}"
    end

    # TODO: FileUtils.remove_dir

    #TODO:
  end

  def dir_to_buf(dirpath, b = nil)
    # File.stat("testfile").mtime

    debug "last file: #{vma.buffers.last_file}", 2
    lastf = vma.buffers.last_file
    jumpto = nil
    if File.dirname(lastf) == dirpath
      jumpto = File.basename(lastf)
    end
    vma.buffers.last_dir = dirpath
    dirpath = File.expand_path(dirpath)
    @header = []
    @header << "#{dirpath}"
    @header << "=" * 40
    @ld = dirpath # Path to current directory
    @dlist = Dir.children(@ld).sort
    @cdirs = [] # Dirs in current directory
    @cfiles = [] # Files in current directory
    for x in @dlist
      fpath = fullp(x)

      ok = true
      begin
        fstat = File.stat(fpath)
      rescue Errno::ENOENT # Broken link or something
        next
      end
      next if x[0] == "."
      if File.directory?(fpath)
        # if f.directory?(fpath)
        @cdirs << x
      else
        @cfiles << [x, fstat]
      end
    end

    @cfiles.sort_by! { |x| x[1].mtime }.reverse! if @sort_by == :mtime
    @cfiles.sort_by! { |x| x[1].size }.reverse! if @sort_by == :size
    @cfiles.sort_by! { |x| x[0] } if @sort_by == :name

    s = ""
    s << @header.join("\n")
    s << "\n"
    s << "..\n"
    s << @cdirs.join("\n")
    s << "\n"
    s << "\n"
    jumppos = nil
    for f in @cfiles
      if f[0] == jumpto
        jumppos = s.size
      end
      s << "#{f[0]}\n"
      # s << @cfiles.join("\n")
    end

    if @buf.nil?
      @buf = create_new_buffer(s, "filemgr")
      @buf.default_mode = :file_exp
      @buf.module = self
      @buf.active_kbd_mode = :file_exp
    else
      @buf.set_content(s)
    end
    if jumppos
      @buf.set_pos(jumppos)
    else
      @buf.set_line_and_column_pos(@header.size, 0)
    end
  end

  def fullp(fn)
    "#{@ld}/#{fn}"
  end

  def refresh
    # TODO: only apply diff
    lpos = @buf.lpos
    # cpos = @buf.cpos
    dir_to_buf(@ld)
    @buf.set_line_and_column_pos(lpos, 0)
  end

  def cur_file
    return nil if @buf.lpos < @header.size
    fn = fullp(@buf.get_current_line[0..-2])
    return fn
  end

  def select_line
    # return if @buf.lpos < @header.size
    # debug "def select_line"
    # fn = fullp(@buf.get_current_line[0..-2])
    fn = cur_file
    return if fn.nil?
    if File.directory?(fn)
      debug "CHDIR: #{fn}"
      dir_to_buf(fn)
      # elsif vma.can_open_extension?(fn)
      # jump_to_file(fn)
    elsif file_is_text_file(fn)
      # bufs.close_current_buffer
      jump_to_file(fn)
      # vma.buffers.set_current_buffer(idx)
      vma.buffers.close_other_buffer(@buf.id)

    else
      open_with_default_program(fn)
    end
  end

  def quit
    @buf.close
  end
end
