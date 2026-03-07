# Map a "line number in a unified diff output" to the corresponding
# line in the new/changed file (the + side), together with the file it belongs to.
#
# Handles multi-file diffs: each --- / +++ pair sets the active file; each @@
# hunk header resets the line counters. Walking hunk lines:
#   ' ' => old++, new++
#   '-' => old++
#   '+' => new++
#
# Returns [new_path, old_path, line_no] or nil for deleted / unmappable lines.
#
class DiffLineMapper
  HUNK_RE = /^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@/

  def initialize(diff_text)
    @lines = diff_text.lines
  end

  # Given a 1-based line number in the diff output, return:
  #   - [new_path, old_path, Integer]: raw +++ path, raw --- path, 1-based new-file line
  #   - nil: if the diff line is a deletion ('-') or cannot be mapped
  def new_line_for_diff_lineno(diff_lineno)
    raise ArgumentError, "diff line number must be >= 1" if diff_lineno.to_i < 1
    idx = diff_lineno.to_i - 1
    return nil if idx >= @lines.length

    old_path = nil
    new_path = nil
    old = nil
    new_ = nil
    in_hunk = false

    @lines.each_with_index do |line, i|
      # File headers reset hunk state and record current file paths.
      # These appear outside hunks, but guard against malformed diffs too.
      if line.start_with?('--- ')
        old_path = line[4..].split("\t").first.strip
        in_hunk = false
        old = new_ = nil
        next
      end

      if line.start_with?('+++ ')
        new_path = line[4..].split("\t").first.strip
        in_hunk = false
        old = new_ = nil
        next
      end

      if (m = line.match(HUNK_RE))
        old = m[1].to_i
        new_ = m[3].to_i
        in_hunk = true
        next
      end

      next unless in_hunk

      if i == idx
        return nil unless new_
        case line.getbyte(0)
        when '+'.ord then return [new_path, old_path, new_]
        when ' '.ord then return [new_path, old_path, new_]
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
  result = mapper.new_line_for_diff_lineno(cur_lpos)

  if result.nil?
    message("No source line for this position")
    return
  end

  new_path, old_path, to_line = result
  orig_path = resolve_diff_path(new_path, old_path)

  if orig_path.nil? || !File.exist?(orig_path)
    message("Could not find file: #{new_path || old_path}")
    return
  end

  jump_to_file(orig_path, to_line)
  center_on_current_line
end

# Resolve a +++ / --- path pair to an absolute filesystem path.
# Prefers new_path (the post-change file); falls back to old_path
# when new_path is /dev/null or a temp file that no longer exists.
def resolve_diff_path(new_path, old_path)
  git_root = `git rev-parse --show-toplevel 2>/dev/null`.strip

  expand = lambda do |path|
    return nil if path.nil? || path == "/dev/null"
    # git diff uses "a/" / "b/" prefixes for old/new sides
    if path.start_with?("b/") || path.start_with?("a/")
      rel = path[2..]
      return git_root.empty? ? File.expand_path(rel) : File.join(git_root, rel)
    end
    path.start_with?("/") ? path : File.expand_path(path)
  end

  path = expand.call(new_path)
  return path if path && File.exist?(path)

  expand.call(old_path)
end

def git_diff_w()
  return if !if_cmd_exists("git")
  diff_buffer_init

  dir = vma.buf.fname ? File.dirname(vma.buf.fname) : Dir.pwd
  git_root = `git -C #{Shellwords.escape(dir)} rev-parse --show-toplevel 2>/dev/null`.strip
  if git_root.empty?
    message("Not a git repository")
    return
  end

  bufstr = run_cmd("git -C #{Shellwords.escape(git_root)} diff -w")
  if bufstr.strip.empty?
    message("git diff -w: no changes")
    return
  end

  create_new_file(nil, bufstr)
  gui_set_file_lang(vma.buf.id, "diff")
  vma.kbd.set_mode(:diffview)
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
