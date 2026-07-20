
module Vimamsa

# Vim-style marker folds ({{{ ... }}}), "extract & stash" model.
#
# When a fold is closed, the whole {{{...}}} block is *removed* from the buffer
# string and stashed in @folds; the block is replaced by a single placeholder
# line. Opening re-inserts the stashed text verbatim. Because the folded text is
# no longer in the buffer string, every path that serialises the buffer to disk
# (Buffer#write_contents_to_file, Buffer#autosave) routes through
# #content_for_disk, which re-inflates folds so the file on disk always holds the
# fully expanded text.
#
# Known v1 limitations (inherent to the extract & stash approach): folded text is
# absent from in-buffer search / replace / LSP while closed, and fold state does
# not persist across restart (the {{{ }}} markers do, so a reopened file starts
# fully expanded). A region that already contains a *closed* fold cannot be
# folded until the inner fold is opened.

# One closed fold. `body` is the exact original block text (the {{{ line through
# the }}} line, trailing newline included) so open/save round-trips byte-for-byte.
FoldRecord = Struct.new(:anchor_id, :label, :body, :nlines)

class Buffer < String
  FOLD_START_RE = /^\s*\{\{\{/
  FOLD_END_RE   = /^\s*\}\}\}/

  def _fold_state
    @folds ||= []
    @fold_anchors ||= {}
    @fold_next_id ||= 0
  end

  def fold_line_text(line_i)
    self[line_range(line_i, 1)]
  end

  # Toggle the fold on line `line_i`. Returns true if the line was a fold-start or
  # a closed-fold placeholder (i.e. this consumed the key); false otherwise, so
  # the caller can run its normal line action.
  def fold_toggle_at(line_i)
    _fold_state
    return false if line_i < 0 || line_i >= @line_ends.size

    lr = line_range(line_i, 1)
    anchor = @fold_anchors.find { |_id, p| p >= lr.begin && p <= lr.end }
    if anchor
      _fold_open(anchor[0])
      return true
    end

    line = fold_line_text(line_i)
    if line =~ FOLD_START_RE
      _fold_close(line_i)
      return true
    end

    false
  end

  # Close the fold whose start marker is on line `start_lpos`.
  def _fold_close(start_lpos)
    _fold_state
    start_range = line_range(start_lpos, 1)
    start_line = self[start_range]
    label = start_line.sub(FOLD_START_RE, "").strip

    # Find the depth-matched closing }}} line (nested folds counted so an outer
    # fold swallows inner markers as literal text).
    depth = 1
    end_lpos = nil
    i = start_lpos + 1
    while i < @line_ends.size
      lt = fold_line_text(i)
      depth += 1 if lt =~ FOLD_START_RE
      depth -= 1 if lt =~ FOLD_END_RE
      if depth == 0
        end_lpos = i
        break
      end
      i += 1
    end

    if end_lpos.nil?
      message("Unbalanced fold marker: no matching }}}")
      return
    end

    end_range = line_range(end_lpos, 1)
    block_begin = start_range.begin
    block_end = end_range.end            # inclusive; covers the }}} line + its \n

    # v1: refuse to fold a region that already contains a closed fold — its
    # placeholder anchor and stashed body would be orphaned by the extraction.
    if @fold_anchors.values.any? { |p| p > block_begin && p <= block_end }
      message("Cannot fold: region contains a closed fold — open it first")
      return
    end

    body = self[block_begin..block_end]
    nlines = body.count("\n")
    head = label.empty? ? "{{{" : "{{{ #{label}"
    placeholder = "#{head}  ⟨#{nlines} lines⟩\n"

    # Insert the placeholder first, then delete the original block (now shifted
    # past it). Deleting first would momentarily empty the buffer and trip
    # add_delta's auto-trailing-newline guard, doubling the final newline.
    new_undo_group
    block_len = block_end - block_begin + 1
    add_delta([block_begin, INSERT, placeholder.size, placeholder], true)
    add_delta([block_begin + placeholder.size, DELETE, block_len], true)
    new_undo_group

    anchor_id = (@fold_next_id += 1)
    @fold_anchors[anchor_id] = block_begin
    @folds << FoldRecord.new(anchor_id, label, body, nlines)

    set_pos(block_begin)
  end

  # Open the closed fold identified by `anchor_id`: replace its placeholder line
  # with the stashed body.
  def _fold_open(anchor_id)
    _fold_state
    rec = @folds.find { |f| f.anchor_id == anchor_id }
    pos = @fold_anchors[anchor_id]
    return if rec.nil? || pos.nil?

    # The placeholder is a single line starting at `pos`.
    line_end = self.index("\n", pos) || (self.size - 1)
    ph_len = line_end - pos + 1          # placeholder line incl. its \n

    # Insert the body first, then delete the placeholder (now shifted past it);
    # see _fold_close for why insert-before-delete avoids a doubled newline.
    new_undo_group
    add_delta([pos, INSERT, rec.body.size, rec.body], true)
    add_delta([pos + rec.body.size, DELETE, ph_len], true)
    new_undo_group

    @folds.delete(rec)
    @fold_anchors.delete(anchor_id)
    set_pos(pos)
  end

  # The buffer text with every closed fold re-inflated to its original block.
  # Used for all disk writes so the extract & stash model never loses folded
  # text. Does not mutate the live (folded) buffer.
  def content_for_disk
    _fold_state
    return self.to_s if @folds.empty?

    result = self.to_s.dup
    # Process placeholders back-to-front so earlier offsets stay valid.
    @folds.sort_by { |f| -(@fold_anchors[f.anchor_id] || -1) }.each do |rec|
      pos = @fold_anchors[rec.anchor_id]
      next if pos.nil? || pos > result.size

      lb = pos > 0 ? result.rindex("\n", pos - 1) : nil
      lb = lb ? lb + 1 : 0
      le = result.index("\n", pos) || (result.size - 1)

      # Safety: only splice if the anchored line still looks like a placeholder.
      # If the user deleted the placeholder line, the body was intentionally
      # dropped — leave the (already-collapsed) text as is.
      next unless result[lb..le] =~ FOLD_START_RE

      result[lb..le] = rec.body
    end
    result
  end
end
end # module Vimamsa
