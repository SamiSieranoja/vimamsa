# Map a "line number in a unified diff output" to the corresponding
# line number in the *new/changed file* (the + side).
#
# Key idea:
#   @@ -old_start,old_count +new_start,new_count @@
# sets starting counters. Then walk each hunk line:
#   ' ' => old++, new++
#   '-' => old++
#   '+' => new++
#
# If the target diff line is:
#   ' ' or '+' => it corresponds to current new line (before increment)
#   '-'        => it has no new-file line (deleted). We return nil.
#
class DiffLineMapper
  HUNK_RE = /^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@/

  def initialize(diff_text)
    @lines = diff_text.lines
  end

  # Given a 1-based line number in the diff output, return:
  #   - Integer: 1-based line number in the new file
  #   - nil:     if the diff line is a deletion ('-') or cannot be mapped
  def new_line_for_diff_lineno(diff_lineno)
    raise ArgumentError, "diff line number must be >= 1" if diff_lineno.to_i < 1
    idx = diff_lineno.to_i - 1
    return nil if idx >= @lines.length

    old = nil
    new_ = nil
    in_hunk = false

    @lines.each_with_index do |line, i|
      if (m = line.match(HUNK_RE))
        old = m[1].to_i
        new_ = m[3].to_i
        in_hunk = true
        next
      end

      next unless in_hunk

      if line.start_with?('--- ', '+++ ')
        in_hunk = false
        old = new_ = nil
        next
      end

      if i == idx
        return nil unless new_
        case line.getbyte(0)
        when '+'.ord then return new_
        when ' '.ord then return new_
        when '-'.ord then return nil
        else              return nil
        end
      end

      next unless old && new_

      case line.getbyte(0)
      when ' '.ord then old += 1; new_ += 1
      when '-'.ord then old += 1
      when '+'.ord then new_ += 1
      end
    end

    nil
  end
end

def diff_buffer_init()
  return if @diff_buffer_init_done
  @diff_buffer_init_done = true
  vma.kbd.add_minor_mode("diffview", :diffview, :command)
  bindkey "diffview enter", :diff_buffer_jump_to_source
end

def diff_buffer()
  return if !if_cmd_exists("diff")
  diff_buffer_init
  orig_path = vma.buf.fname
  infile = Tempfile.new("in")
  infile.write(vma.buf.to_s)
  infile.flush
  bufstr = run_cmd("diff -uw '#{orig_path}' #{infile.path}")
  infile.close; infile.unlink
  create_new_file(nil, bufstr)
  gui_set_file_lang(vma.buf.id, "diff")
  vma.kbd.set_mode(:diffview)
end

def diff_buffer_jump_to_source()
  mapper = DiffLineMapper.new(vma.buf.to_s)
  cur_lpos = vma.buf.lpos + 1
  to_line = mapper.new_line_for_diff_lineno(cur_lpos)

  orig_path = nil
  vma.buf.to_s.each_line do |l|
    if l =~ /^--- (.+)/
      path = $1.split("\t").first.strip
      # git diff prefixes paths with "a/" — strip it and resolve from git root
      if path.start_with?("a/")
        git_root = `git rev-parse --show-toplevel 2>/dev/null`.strip
        path = File.join(git_root, path[2..]) unless git_root.empty?
      end
      orig_path = path
      break
    end
  end
  if orig_path.nil? || !File.exist?(orig_path)
    message("Could not find original file in diff")
    return
  end

  jump_to_file(orig_path, to_line)
  center_on_current_line
end

def git_diff_buffer()
  return if !if_cmd_exists("git")
  diff_buffer_init
  fname = vma.buf.fname
  if fname.nil?
    message("Buffer has no file")
    return
  end
  bufstr = run_cmd("git diff -w -- #{Shellwords.escape(fname)}")
  if bufstr.strip.empty?
    message("git diff: no changes")
    return
  end
  create_new_file(nil, bufstr)
  gui_set_file_lang(vma.buf.id, "diff")
  vma.kbd.set_mode(:diffview)
end
