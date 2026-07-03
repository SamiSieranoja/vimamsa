class TestAutocomplete < VmaTest

  # Seed candidate words and enter insert mode
  def seed(words)
    Vimamsa::Autocomplete.add_words(words, :test_seed)
  end

  def teardown_seed
    Vimamsa::Autocomplete.remove_buffer(:test_seed)
  end

  def view
    vma.buf.view
  end

  # ── Ranking (pure candidate engine) ─────────────────────────────────────

  def test_ranking_prefix_beats_substring_beats_subsequence
    seed(%w[prefix_match xprefix_inside pariefaix unrelated])
    m = Vimamsa::Autocomplete.matching_words("prefix")
    assert_eq "prefix_match", m[0]
    assert_eq "xprefix_inside", m[1]
    assert_eq "pariefaix", m[2], "subsequence match expected third: #{m.inspect}"
    assert !m.include?("unrelated"), "non-match must be excluded: #{m.inspect}"
  ensure
    teardown_seed
  end

  def test_ranking_frequency_tie_break
    seed(%w[wombat wonder wonder wonder])
    m = Vimamsa::Autocomplete.matching_words("wo")
    assert_eq "wonder", m[0], "more frequent word should rank first: #{m.inspect}"
  ensure
    teardown_seed
  end

  def test_case_insensitive_prefix_ranks_below_exact
    seed(%w[Foobar foobaz])
    m = Vimamsa::Autocomplete.matching_words("foo")
    assert_eq "foobaz", m[0], "case-sensitive prefix first: #{m.inspect}"
    assert_eq "Foobar", m[1]
  ensure
    teardown_seed
  end

  def test_exact_prefix_not_offered
    seed(%w[word])
    m = Vimamsa::Autocomplete.matching_words("word")
    assert !m.include?("word"), "the typed word itself is not a completion"
  ensure
    teardown_seed
  end

  # ── Popup behavior (live GTK) ────────────────────────────────────────────

  def test_popup_appears_while_typing
    seed(%w[wombat wonderful])
    keys("i w o")
    assert view.autocp_active, "popup should be active after typing 2 word chars"
    assert view.autocp_texts.include?("wombat"), "candidates: #{view.autocp_texts.inspect}"
    assert view.autocp_texts.include?("wonderful")
  ensure
    teardown_seed
    keys("esc esc")
  end

  def test_min_chars_respected
    seed(%w[wombat])
    keys("i w")
    assert !view.autocp_active, "popup must not open below min_chars"
  ensure
    teardown_seed
    keys("esc")
  end

  # zq-prefixed words: buffers from other test suites also feed the word
  # store, so ordering assertions need a collision-proof prefix
  def test_complete_word_with_tab_enter
    seed(%w[zqwombat])
    keys("i z q")
    assert view.autocp_active
    keys("enter")
    assert_buf "zqwombat\n"
    assert_mode :insert
    assert !view.autocp_active
  ensure
    teardown_seed
    keys("esc")
  end

  def test_tab_selects_next_candidate
    seed(%w[zqalpha zqalpha zqbeta])  # zqalpha more frequent => first
    keys("i z q")
    assert view.autocp_active
    keys("tab enter")
    # tab moved selection to the second candidate before enter committed it
    assert_eq "zqbeta\n", vma.buf.to_s
  ensure
    teardown_seed
    keys("esc")
  end

  def test_dismiss_on_nonword_char
    seed(%w[wombat])
    keys("i w o")
    assert view.autocp_active
    keys("space")
    assert !view.autocp_active, "space must dismiss the popup"
    assert_mode :insert
  ensure
    teardown_seed
    keys("esc")
  end

  def test_esc_dismisses_then_exits_insert
    seed(%w[wombat])
    keys("i w o")
    assert view.autocp_active
    keys("esc")
    assert !view.autocp_active, "first esc dismisses the popup"
    assert_mode :insert
    keys("esc")
    assert_mode :command
  ensure
    teardown_seed
  end

  def test_backspace_keeps_refining
    seed(%w[wombat])
    keys("i w o m")
    assert view.autocp_active
    keys("backspace")
    assert view.autocp_active, "popup stays open while prefix >= min_chars"
    assert view.autocp_texts.include?("wombat")
  ensure
    teardown_seed
    keys("esc esc")
  end

  def test_manual_trigger
    seed(%w[zebra zebrafish])
    keys("i z e")
    keys("esc")          # dismiss, stay in insert
    assert !view.autocp_active
    act :autocp_manual_trigger
    assert view.autocp_active, "ctrl-space action should reopen the popup"
  ensure
    teardown_seed
    keys("esc esc")
  end

  # Drive the real GTK key event path (handle_key_event), not just
  # match_key_conf, and check the popover actually maps on screen
  def test_real_key_event_path_maps_popover
    seed(%w[zqwombat zqwonder])
    v = view
    [[105, "i"], [122, "z"], [113, "q"]].each do |keyval, name|
      v.handle_key_event(keyval, name, :key_press)
      v.handle_key_event(keyval, name, :key_release)
    end
    drain_idle
    assert_mode :insert
    assert v.autocp_active, "popup should activate via real key path"
    assert v.autocp_texts.include?("zqwombat"), v.autocp_texts.inspect
    w = v.instance_variable_get(:@acwin)
    drain_idle
    assert w&.visible? && w&.mapped?, "popover should be visible and mapped"
  ensure
    teardown_seed
    keys("esc esc")
  end

  def test_leaving_insert_mode_dismisses
    seed(%w[wombat])
    keys("i w o")
    assert view.autocp_active
    keys("esc esc")
    assert_mode :command
    assert !view.autocp_active
  ensure
    teardown_seed
  end
end
