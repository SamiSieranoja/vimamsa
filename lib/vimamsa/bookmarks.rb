
module Vimamsa
# Persistent bookmarks across files.
#   , M   add bookmark at cursor
#   , '   list bookmarks (newest first): <enter> jump, <d> delete, <x> exit
#
# Saved to get_dot_path("bookmarks") so they survive restarts. Each bookmark
# stores the text of its line (and the nearest non-blank lines around it), so
# if the file has changed a jump finds the line again with a regexp instead of
# trusting the stored line number.
#
# While a bookmarked file is open, its position is also kept in the buffer's
# @marks hash (key "bm:<id>"), which Buffer#update_index shifts on edits. On
# save the stored line/text is refreshed from there.
class Bookmarks
  attr_reader :list

  def self.init()
    vma.kbd.add_minor_mode("bmark", :bmark, :command)
    reg_act(:bookmark_add, proc { vma.bookmarks.add }, "Add bookmark at cursor (persistent, across files)")
    reg_act(:bookmark_list, proc { BookmarkList.new.run; vma.kbd.set_mode(:bmark) }, "List bookmarks")
    reg_act(:bmark_select, proc { buf.module.select_line }, "")
    reg_act(:bmark_delete, proc { buf.module.delete_selected }, "")

    bindkey "bmark enter", :bmark_select
    bindkey "bmark d", :bmark_delete
    bindkey "bmark x", :close_current_buffer
  end

  def initialize()
    load_list
    vma.hook.register(:change_buffer, self.method("track_buffer"))
    vma.hook.register(:file_saved, self.method("file_saved"))
    vma.hook.register(:shutdown, self.method("save"))
    # Buffers opened before this plugin was created (files from ARGV)
    vma.buffers.list.each { |b| track_buffer(b) }
  end

  def load_list()
    @list = vma.marshal_load("bookmarks", [])
    @list = [] if !@list.is_a?(Array)
    @next_id = (@list.collect { |bm| bm[:id].to_i }.max || 0) + 1
  end

  def save()
    vma.marshal_save("bookmarks", @list)
  rescue => ex
    debug "Bookmarks.save failed: #{ex}"
  end

  # Newest first
  def sorted_list()
    @list.sort_by { |bm| bm[:created] || Time.at(0) }.reverse
  end

  def add(b = vma.buf)
    if b.nil? or b.fname.nil?
      message("Bookmark: buffer is not saved to a file")
      return nil
    end
    lpos = b.lpos
    # Re-marking the same line replaces the old bookmark
    @list.select { |bm| bm[:fname] == b.fname && bm[:lpos] == lpos }.each { |bm| delete(bm, false) }

    bm = { id: @next_id, fname: b.fname, created: Time.now }
    @next_id += 1
    lines = b.to_s.lines
    bm.merge!(snapshot(lines, lpos, b.cpos))
    @list << bm
    b.marks[mark_key(bm)] = anchor_pos(b, lpos, lines)
    save
    message("Bookmark added: #{tilde_path(b.fname)}:#{lpos + 1}")
    return bm
  end

  def delete(bm, do_save = true)
    b = buffer_for(bm[:fname])
    b.marks.delete(mark_key(bm)) if b
    @list.delete(bm)
    save if do_save
  end

  # Open the bookmarked file and put the cursor on the bookmarked line.
  # Returns false if the file could not be opened.
  def jump(bm)
    if !File.exist?(bm[:fname])
      message("Bookmark file not found: #{bm[:fname]}")
      return false
    end
    open_new_file(bm[:fname])
    b = vma.buf
    return false if b.nil? or b.fname != bm[:fname] # e.g. large file confirm dialog

    lines = b.to_s.lines
    (lpos, found) = resolve_line(lines, bm)
    message("Bookmark text not found, using line #{lpos + 1}") if !found
    b.set_pos(line_start(b, lpos) + [bm[:cpos].to_i, [lines[lpos].to_s.chomp.size - 1, 0].max].min)
    center_on_current_line

    if found && lpos != bm[:lpos]
      # Self-heal: remember where the line is now
      bm[:lpos] = lpos
      b.marks[mark_key(bm)] = anchor_pos(b, lpos, lines)
      save
    end
    return true
  end

  # Find the bookmarked line in lines (Array of lines incl. "\n").
  # Returns [lpos, found]. Among lines matching the stored text, the one whose
  # surrounding context also matches wins; ties go to the one closest to the
  # stored line number. If nothing matches, falls back to the stored line
  # number (clamped) with found=false.
  def resolve_line(lines, bm)
    n = lines.size
    return [0, false] if n == 0
    hint = bm[:lpos].to_i
    fallback = hint.clamp(0, n - 1)
    re = text_regexp(bm[:text])
    return [fallback, false] if re.nil?

    best = nil
    best_score = nil
    lines.each_with_index do |l, i|
      next if !l.match?(re)
      score = (i - hint).abs
      score -= n if bm[:before] && context_line(lines, i, -1) == bm[:before]
      score -= n if bm[:after] && context_line(lines, i, 1) == bm[:after]
      if best.nil? or score < best_score
        best = i
        best_score = score
      end
    end
    return [best, true] if best
    return [fallback, false]
  end

  # Whole-line match of text, ignoring indentation and amount of whitespace
  def text_regexp(text)
    t = text.to_s.strip
    return nil if t.empty?
    body = Regexp.escape(t).gsub(/(?:\\ |\\t)+/) { '\s+' }
    return /\A\s*#{body}\s*\z/
  end

  # :change_buffer hook. Start tracking bookmarks of b's file in b.marks.
  def track_buffer(b)
    return if b.nil? or b.fname.nil?
    lines = nil
    for bm in @list
      next if bm[:fname] != b.fname or b.marks.has_key?(mark_key(bm))
      lines ||= b.to_s.lines
      (lpos, found) = resolve_line(lines, bm)
      # If the line is not found, leave it untracked so that a save does not
      # overwrite the stored text with some unrelated line.
      b.marks[mark_key(bm)] = anchor_pos(b, lpos, lines) if found
    end
  end

  # :file_saved hook. Refresh stored line/text from the tracked positions.
  def file_saved(b)
    return if b.nil? or b.fname.nil?
    lines = nil
    changed = false
    for bm in @list
      next if bm[:fname] != b.fname
      pos = b.marks[mark_key(bm)]
      next if pos.nil?
      lines ||= b.to_s.lines
      next if lines.empty?
      lpos = line_of_pos(b, pos)
      bm.merge!(snapshot(lines, lpos, bm[:cpos]))
      changed = true
    end
    save if changed
  end

  private

  def mark_key(bm)
    "bm:#{bm[:id]}"
  end

  def buffer_for(fname)
    id = vma.buffers.get_buffer_by_filename(fname)
    return nil if id.nil?
    return vma.buffers.get_buffer_by_id(id)
  end

  def snapshot(lines, lpos, cpos)
    { lpos: lpos, cpos: cpos,
      text: lines[lpos].to_s.chomp,
      before: context_line(lines, lpos, -1),
      after: context_line(lines, lpos, 1) }
  end

  # Nearest non-blank line from lpos in direction dir (-1 or 1), stripped
  def context_line(lines, lpos, dir)
    i = lpos + dir
    while i >= 0 && i < lines.size
      t = lines[i].strip
      return t if !t.empty?
      i += dir
    end
    return nil
  end

  def line_start(b, lpos)
    return 0 if lpos <= 0
    return b.line_ends[lpos - 1] + 1
  end

  def line_of_pos(b, pos)
    b.line_ends.bsearch_index { |e| e >= pos } || [b.line_ends.size - 1, 0].max
  end

  # Position stored in b.marks. Second char of the line (when there is one), so
  # that inserting text at the line start (e.g. "O") shifts the mark along with
  # the line (update_index only shifts marks after the insert position).
  def anchor_pos(b, lpos, lines)
    line_start(b, lpos) + (lines[lpos].to_s.chomp.empty? ? 0 : 1)
  end
end

# List view for bookmarks, modelled on BufferManager
class BookmarkList
  attr_reader :buf
  @@cur = nil # Current object of class

  def self.cur()
    return @@cur
  end

  def initialize()
    @buf = nil
    @line_to_bm = {}
  end

  def bm_of_current_line()
    return @line_to_bm[@buf.lpos]
  end

  def select_line()
    bm = bm_of_current_line
    return if bm.nil?
    list_id = @buf.id
    return if !vma.bookmarks.jump(bm) # Keep the list open if the jump failed
    vma.buffers.close_other_buffer(list_id)
    @@cur = nil
    vma.kbd.set_mode(vma.kbd.default_mode)
  end

  def delete_selected()
    bm = bm_of_current_line
    return if bm.nil?
    lpos = @buf.lpos
    vma.bookmarks.delete(bm)
    message("Bookmark deleted: #{tilde_path(bm[:fname])}:#{bm[:lpos] + 1}")
    run
    last = @header.size + [@line_to_bm.size - 1, 0].max
    @buf.set_line_and_column_pos([lpos, last].min, 0)
  end

  def run()
    if !@@cur.nil? && @@cur != self && !@@cur.buf.nil?
      # One instance open already, close it
      vma.buffers.close_buffer(@@cur.buf.id)
    end
    @@cur = self
    @header = []
    @header << "Bookmarks (newest first):"
    @header << "keys: <enter> (or <double click>) to jump, <d> to delete, <x> exit"
    @header << "=" * 40

    s = ""
    s << @header.join("\n")
    s << "\n"
    @line_to_bm = {}
    list = vma.bookmarks.sorted_list
    s << "(no bookmarks, add one with , M)\n" if list.empty?
    list.each_with_index do |bm, i|
      @line_to_bm[@header.size + i] = bm
      s << row(bm) << "\n"
    end

    if @buf.nil?
      @buf = create_new_buffer(s, "bookmarks")
      @buf.default_mode = :bmark
      @buf.module = self
      @buf.active_kbd_mode = :bmark
    else
      @buf.set_content(s)
    end
    @buf.set_line_and_column_pos(@header.size, 0)
  end

  def row(bm)
    t = bm[:created].respond_to?(:strftime) ? bm[:created].strftime("%Y-%m-%d %H:%M") : "?"
    "#{t}  #{tilde_path(bm[:fname])}:#{bm[:lpos] + 1}  #{bm[:text].to_s.strip[0, 80]}"
  end
end
end # module Vimamsa
