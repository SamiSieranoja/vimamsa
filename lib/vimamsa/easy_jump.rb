
module Vimamsa
# Similar feature as Vim EasyMotion https://github.com/easymotion/vim-easymotion
class EasyJump
  # def self.initialize()
  # make_jump_sequence
  # end

  def self.start()
    @@cur = EasyJump.new
  end

  def initialize()
    visible_range = get_visible_area()
    visible_text = buf[visible_range[0]..visible_range[1]]
    wsmarks = scan_word_start_marks(visible_text)
    line_starts = scan_indexes(visible_text, /^/)
    lsh = Hash[line_starts.collect { |x| [x, true] }]
    wsmh = Hash[wsmarks.collect { |x| [x, true] }]

    # Exclude work starts that are too close to start of line
    wsmarks.select! { |x|
      r = true
      r = false if lsh[x] or lsh[x - 1] or lsh[x - 2]
      r
    }
    
    wsmarks = [0] if wsmarks.empty?

    # Exclude those word start positions that are too close to each other
    wsmarks.sort!
    wsm2 = [wsmarks[0]]
    for i in 1..(wsmarks.size - 1)
      if (wsmarks[i] - wsm2[-1]) >= 4 or visible_text[wsm2[-1]..wsmarks[i]].include?("\n")
        wsm2 << wsmarks[i]
      end
    end
    wsmarks = wsm2


    linestart_buf = (line_starts).collect { |x| x + visible_range[0] }
    wsmarks_buf = (wsmarks).collect { |x| x + visible_range[0] }

    # All line starts should be accessible with just two key presses, so put them first in order
    # Other word start positions ordered by distance from current pos
    wsmarks_buf.sort_by! { |x| (x - buf.pos).abs }
    @easy_jump_wsmarks = linestart_buf + wsmarks_buf

    @jump_sequence = make_jump_sequence(@easy_jump_wsmarks.size)

    vma.kbd.set_keyhandling_override(self.method(:easy_jump_input_char))
    @easy_jump_input = ""
    easy_jump_draw
  end

  def easy_jump_input_char(c, event_type)
    return true if event_type != :key_press
    # vma.paint_stack = []
    debug "EASY JUMP: easy_jump_input_char [#{c}]"
    @easy_jump_input << c.upcase
    state = :typing
    if @jump_sequence.include?(@easy_jump_input)
      state = :jumped
      jshash = Hash[@jump_sequence.map.with_index.to_a]
      nthword = jshash[@easy_jump_input]
      newpos = @easy_jump_wsmarks[nthword]
      if !newpos.nil?
        debug "nthword:#{nthword} #{[@easy_jump_wsmarks[nthword], @jump_sequence[nthword]]}"
        buf.set_pos(@easy_jump_wsmarks[nthword])
      end
      vma.kbd.remove_keyhandling_override
      @jump_sequence = []
      show_chosen(nthword)
    end
    show_typed if state == :typing && @easy_jump_input.size <= 2
    if state == :typing && @easy_jump_input.size > 2
      state = :nomatch
      # @kbd.set_mode(:command)
      vma.kbd.remove_keyhandling_override
      @jump_sequence = []
      vma.gui.clear_overlay
    end
    # The keys of the label go to this override, not to the key bindings:
    # the key log gets them from here
    vma.gui.keylog_panel&.log_jump_label(@easy_jump_input, state, state == :jumped ? buf.lpos + 1 : nil)
    return true
  end

  LABEL_FG = "#ff0000"
  TYPED_FG = "#ffff66" # the keys of a label typed so far
  CHOSEN_SECS = 0.15 # the chosen label stays this long after the others go

  def easy_jump_draw()
    vma.gui.start_overlay_draw
    @labels = []
    for i in 0..(@easy_jump_wsmarks.size - 1)
      @labels << vma.gui.overlay_draw_text(@jump_sequence[i], @easy_jump_wsmarks[i], markup: label_markup(@jump_sequence[i], 0))
    end
    vma.gui.end_overlay_draw
  end

  # Markup of label seq whose first n keys are typed: those bright and
  # bold, the rest red; dim: a label that no longer matches
  def label_markup(seq, n, dim: false)
    seq = seq.to_s
    typed = CGI.escapeHTML(seq[0, n].to_s)
    rest = CGI.escapeHTML(seq[n..].to_s)
    alpha = dim ? " alpha='35%'" : ""
    s = "<span background='#000000ff' weight='ultrabold'#{alpha}>"
    s << "<span foreground='#{TYPED_FG}' weight='heavy'>#{typed}</span>" if !typed.empty?
    s << "<span foreground='#{LABEL_FG}'>#{rest}</span>" if !rest.empty?
    s << "</span>"
  end

  # After a key of a label: the matching labels show the typed part, the
  # others are dimmed
  def show_typed
    return if @labels.nil?
    inp = @easy_jump_input
    @labels.each_with_index { |l, i|
      seq = @jump_sequence[i].to_s
      l.markup = seq.start_with?(inp) ? label_markup(seq, inp.size) : label_markup(seq, 0, dim: true)
    }
  end

  # The chosen label alone, all bright, for CHOSEN_SECS
  def show_chosen(i)
    label = @labels && i && @labels[i]
    if label.nil?
      vma.gui.clear_overlay
      return
    end
    @labels.each { |l| vma.gui.overlay_remove(l) if !l.equal?(label) }
    label.markup = label_markup(@easy_jump_input, @easy_jump_input.size)
    vma.gui.clear_overlay_later((CHOSEN_SECS * 1000).round)
  end

  # Test-visible: the label widgets, in the order of the marks
  attr_reader :labels

  def make_jump_sequence(num_items)
    left_hand = "asdfvgbqwertzxc123".upcase.split("")
    right_hand = "jklhnnmyuiop890".upcase.split("")

    sequence = []
    left_hand_fast = "asdf".upcase.split("")
    right_hand_fast = "jkl;".upcase.split("")

    left_hand_slow = "wergc".upcase.split("") # v
    right_hand_slow = "uiophnm,".upcase.split("")

    left_hand_slow2 = "tzx23".upcase.split("")
    right_hand_slow2 = "yb9'".upcase.split("")

    # Rmoved characters that can be mixed: O0Q, 8B, I1, VY

    left_fast_slow = Array.new(left_hand_fast).concat(left_hand_slow)
    right_fast_slow = Array.new(right_hand_fast).concat(right_hand_slow)

    left_hand_all = Array.new(left_hand_fast).concat(left_hand_slow).concat(left_hand_slow2)
    right_hand_all = Array.new(right_hand_fast).concat(right_hand_slow).concat(right_hand_slow2)

    left_hand_fast.each { |x|
      left_hand_fast.each { |y|
        sequence << "#{x}#{y}"
      }
    }

    right_hand_fast.each { |x|
      right_hand_fast.each { |y|
        sequence << "#{x}#{y}"
      }
    }

    right_hand_fast.each { |x|
      left_hand_fast.each { |y|
        sequence << "#{x}#{y}"
      }
    }

    left_hand_fast.each { |x|
      right_hand_fast.each { |y|
        sequence << "#{x}#{y}"
      }
    }

    left_hand_slow.each { |x|
      right_fast_slow.each { |y|
        sequence << "#{x}#{y}"
      }
    }

    right_hand_slow.each { |x|
      left_fast_slow.each { |y|
        sequence << "#{x}#{y}"
      }
    }

    left_hand_slow2.each { |x|
      right_hand_all.each { |y|
        left_hand_all.each { |z|
          sequence << "#{x}#{y}#{z}"
        }
      }
    }

    right_hand_slow2.each { |x|
      left_hand_all.each { |y|
        right_hand_all.each { |z|
          sequence << "#{x}#{y}#{z}"
        }
      }
    }

    return sequence
  end
end
end # module Vimamsa
