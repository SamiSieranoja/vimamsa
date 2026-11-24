# The introduction page and the Vim summary (intro_page.rb, help/*.txt):
# ⟦run:…⟧ links and their buttons, {key:…} placeholders, read-only help
# buffers, the demo list above the key log, and when the page is shown at
# start (doc/intro_page_plan.md)
require "rbconfig"
require "tmpdir"

class TestIntroPage < VmaTest
  REPO = File.expand_path("..", __dir__)

  def setup_counter
    $intro_test_runs = 0
    reg_act("help.zz_intro_test", proc { $intro_test_runs += 1 }, "test")
    reg_act("edit.zz_intro_test", proc { $intro_test_runs += 1 }, "test")
  end

  def close_help_pages
    vma.buffers.list.select { |b| b.help_page }.each { |b| vma.buffers.close_buffer(b.id) }
  end

  def stop_demo
    p = DemoPlayer.current
    return if p.nil?
    p.stop
    (p.bufs || []).each { |b| vma.buffers.close_buffer(b.id) if vma.buffers.list.any? { |x| x.equal?(b) } }
    drain_idle
  end

  # ── Links ────────────────────────────────────────────────────────────────

  def test_link_at
    s = "abc ⟦run:help.x|Two words⟧ d ⟦help:intro⟧\n"
    assert_eq "⟦run:help.x|Two words⟧", hpt_link_at(s, s.index("words"))
    assert_eq "⟦help:intro⟧", hpt_link_at(s, s.index("intro"))
    assert_eq nil, hpt_link_at(s, 1)
  end

  def test_enter_runs_allowed_action
    setup_counter
    create_new_buffer("x ⟦run:help.zz_intro_test|Run it now⟧\n", "linktest")
    buf.set_pos(buf.index("it now"))
    buf.handle_line_action
    assert_eq 1, $intro_test_runs
  ensure
    vma.actions.unregister("help.zz_intro_test") rescue nil
    vma.actions.unregister("edit.zz_intro_test") rescue nil
  end

  # Any .txt file can hold a ⟦run:…⟧ link: only allowed actions run
  def test_disallowed_action_not_run
    setup_counter
    create_new_buffer("⟦run:edit.zz_intro_test|Do it⟧\n", "linktest")
    buf.set_pos(3)
    buf.handle_line_action
    assert_eq 0, $intro_test_runs
    assert !hpt_run_allowed?("app.quit")
    assert hpt_run_allowed?("app.demo")
    # demos play keys through the user's (maybe customized) bindings
    %w[help.demo help.demo.easyjump help.demo.record help.demo.user.x].each { |a| assert !hpt_run_allowed?(a), a }
    assert hpt_run_allowed?("help.demonstrate"), "only help.demo and help.demo.*"
  ensure
    vma.actions.unregister("help.zz_intro_test") rescue nil
    vma.actions.unregister("edit.zz_intro_test") rescue nil
  end

  def test_help_link_opens_vim_intro
    create_new_buffer("see ⟦help:vim_intro⟧\n", "linktest")
    buf.set_pos(6)
    buf.handle_line_action
    assert_eq "vim_intro", vma.buf.help_page
  ensure
    close_help_pages
  end

  # ── The page ─────────────────────────────────────────────────────────────

  def test_intro_page_filled_in
    b = show_help_page("intro")
    assert_eq "intro", b.help_page
    assert b.read_only
    assert !b.include?("{"), "placeholder left: #{b.lines.grep(/\{/).first}"
    assert !b.include?("(no key for"), "unbound key: #{b.lines.grep(/no key for/).first}"
    assert !b.include?("⟦run:help.demo"), "a demo link on the page"
    assert b.include?("⦁ctrl!⦁ or ⦁i⦁"), "mode.insert keys: #{b.lines.grep(/Insert mode/).first}"
  ensure
    close_help_pages
  end

  # The links to the other help pages are buttons too, and open them
  def test_help_page_links_are_buttons
    b = show_help_page("intro")
    drain_idle
    %w[help.vim_intro help.keys].each { |act|
      assert b.help_buttons.any? { |a, _, _| a == act }, "no button for #{act}"
    }
    btn = b.help_buttons.find { |a, _, _| a == "help.vim_intro" }[1]
    btn.signal_emit("clicked")
    assert_eq "vim_intro", vma.buf.help_page
  ensure
    close_help_pages
  end

  # On a read-only page the ⦁ marks are hidden, the text between them is
  # not, and the cursor steps over a hidden mark
  def test_marks_hidden_on_help_page
    b = show_help_page("intro")
    drain_idle
    # the first marked key on the page (e.g. ⦁ctrl!⦁ from {key:...})
    m = b.match(/⦁[^⦁\n]+⦁/)
    assert m, "no ⦁ marks on the page"
    i = m.begin(0)
    assert hidden?(b, i), "opening mark shown"
    assert hidden?(b, m.end(0) - 1), "closing mark shown"
    assert !hidden?(b, i + 1), "key text hidden"
    b.set_pos(i - 1)
    hpt_skip_hidden_marks(b)
    keys "l"
    assert_eq i + 1, b.pos, "cursor on the hidden opening mark"
    keys "h"
    assert_eq i - 1, b.pos, "cursor back on the hidden opening mark"
    # an editable buffer shows them
    e = create_new_buffer("a ⦁key⦁ b\n", "marktest")
    gui_set_file_lang(e.id, "hyperplaintext")
    hpt_hide_marks(e)
    assert !hidden?(e, 2), "mark hidden in an editable buffer"
  ensure
    close_help_pages
  end

  # The keys come from the bindings, so the page works in notepad too
  # (which never leaves Insert mode, so it has no I:mode.prev)
  def test_keys_resolve_in_notepad
    kbd = load_scheme_kbd(["vimlike", "notepad"])
    specs = HELP_PAGES.flat_map { |n| File.read(File.join(HELP_DIR, "#{n}.txt")).scan(/\{key:([^}]+)\}/).flatten }
    assert specs.size >= 8
    (specs - ["I:mode.prev"]).each { |s|
      t = help_key_text(s, kbd)
      assert !t.include?("no key for"), "#{s}: #{t}"
    }
  end

  def test_opening_twice_keeps_one_buffer
    a = show_help_page("intro")
    create_new_buffer("other\n", "other")
    b = show_help_page("intro")
    assert a.equal?(b)
    assert vma.buf.equal?(a)
    assert_eq 1, vma.buffers.list.count { |x| x.help_page == "intro" }
  ensure
    close_help_pages
  end

  def test_read_only
    b = show_help_page("intro")
    text = b.to_s.dup
    keys "x d d"
    keys "i a b c esc"
    assert_eq text, b.to_s
  ensure
    vma.kbd.set_mode(:command)
    close_help_pages
  end

  def test_command_line_and_menu
    vma.gui.cmd_line.execute("intro")
    assert_eq "intro", vma.buf.help_page
    assert_eq "Help ▸ Introduction", vma.gui.menu.path_for("help.intro")
    assert_eq nil, vma.gui.menu.path_for("help.demo.easyjump"), "demos in the menu"
  ensure
    close_help_pages
  end

  # ── Buttons and demos ────────────────────────────────────────────────────

  # One button per ⟦run:…⟧ line; the GTK buffer keeps the Buffer's length
  def test_buttons_added
    b = show_help_page("intro")
    drain_idle
    n = b.lines.count { |l| l.include?("⟦run:") }
    assert_eq n, b.help_buttons.size
    assert_eq 4, n
    assert_eq b.size, b.view.buffer.char_count
  ensure
    close_help_pages
  end

  def hidden?(b, pos)
    tag = b.view.buffer.tag_table.lookup("hpt_hidden")
    !tag.nil? && b.view.buffer.get_iter_at(offset: pos).has_tag?(tag)
  end

  # On a read-only page the buttons replace the link text everywhere; the
  # cursor moves off the hidden text onto the button, where enter runs it
  def test_buttons_replace_links_on_help_page
    setup_counter
    b = show_help_page("intro")
    drain_idle
    from = b.index("⟦run:help.vim_intro|")
    assert_eq HPT_BUTTON_SLOT, b[from - 1]
    assert !hidden?(b, from - 1), "the button's place hidden"
    assert hidden?(b, from), "link text shown"
    assert hidden?(b, from + 5)
    btn = b.help_buttons[0][1]
    assert btn.visible?, "button hidden"
    assert_eq "pointer", btn.cursor&.name, "mouse pointer over the button"
    # the cursor on the link's line: still hidden (read-only)
    b.set_pos(from + 3)
    hpt_update_run_buttons(b)
    assert hidden?(b, from), "link shown with the cursor on its line"
    assert_eq from - 1, b.pos, "cursor not moved onto the button"
  ensure
    vma.actions.unregister("help.zz_intro_test") rescue nil
    vma.actions.unregister("edit.zz_intro_test") rescue nil
    close_help_pages
  end

  # The cursor treats a button as one char: w and l from the button go past
  # its (hidden) link, b and h come back onto it, w from before it stops on
  # it; and many w's in a row move on without getting stuck
  def test_cursor_treats_button_as_one_char
    b = show_help_page("intro")
    drain_idle
    at = b.index("#{HPT_BUTTON_SLOT}⟦run:help.vim_intro|")
    to = b.index("⟧", at) + 1
    b.set_pos(at)
    hpt_skip_button(b)
    keys "l"
    assert_eq to, b.pos, "l from the button"
    keys "h"
    assert_eq at, b.pos, "h back onto the button"
    keys "w"
    assert_eq b.index(/\S/, to), b.pos, "w from the button: the next word after the link"
    keys "b"
    assert_eq at, b.pos, "b back onto the button"
    # w from the end of the line above stops on the button
    b.set_pos(at - 2)
    hpt_skip_button(b)
    keys "w"
    assert_eq at, b.pos, "w onto the button"
    last = b.pos
    40.times {
      keys "w"
      assert b.pos > last || b.pos >= b.size - 2, "w stuck at #{b.pos}: #{b[b.pos, 20].inspect}"
      last = b.pos
      break if b.pos >= b.size - 2
    }
  ensure
    close_help_pages
  end

  # In a buffer that can be edited, the link text shows instead of the
  # button while the cursor is on its line
  def test_link_code_shown_on_cursor_line_when_editable
    setup_counter
    b = create_new_buffer("first line\nx#{HPT_BUTTON_SLOT}⟦run:help.zz_intro_test|Go⟧ y\nlast\n", "linktest")
    help_add_run_buttons(b)
    btn = b.help_buttons[0][1]
    from = b.index("⟦")
    b.set_pos(0)
    hpt_update_run_buttons(b)
    assert hidden?(b, from)
    assert btn.visible?
    keys "j"
    assert !hidden?(b, from), "link code hidden with the cursor on its line"
    assert !btn.visible?, "button shown with the cursor on its line"
    keys "j"
    assert hidden?(b, from)
    assert btn.visible?
    assert_eq b.size, b.view.buffer.char_count
    btn.signal_emit("clicked")
    assert_eq 1, $intro_test_runs
  ensure
    vma.actions.unregister("help.zz_intro_test") rescue nil
    vma.actions.unregister("edit.zz_intro_test") rescue nil
  end

  # Enter on the button position (before the hidden link) runs the link
  def test_enter_on_button_position
    setup_counter
    b = create_new_buffer("x ⟦run:help.zz_intro_test|Go⟧\n", "linktest")
    b.set_pos(1)
    b.handle_line_action
    assert_eq 1, $intro_test_runs
  ensure
    vma.actions.unregister("help.zz_intro_test") rescue nil
    vma.actions.unregister("edit.zz_intro_test") rescue nil
  end

  # The demo list above the key log switches demos, keeping the speed
  def test_demo_list_switches
    DemoPlayer.toggle(:basic)
    a = DemoPlayer.current
    a.faster
    rate = a.rate
    list = vma.gui.keylog_panel.demo_list
    assert_eq 0, list.selected
    list.selected = DemoPlayer::DEMOS.keys.index(:easyjump)
    # the switch runs in an idle callback
    t = Time.now
    until !DemoPlayer.current.equal?(a) || Time.now - t > 5
      drain_idle
      sleep 0.01
    end
    b = DemoPlayer.current
    assert !a.running?, "the basic demo still runs"
    assert b.running?
    assert_eq :easyjump, b.name
    assert_eq rate, b.rate
    assert_eq DemoPlayer::DEMOS.keys.index(:easyjump), list.selected
  ensure
    [a, b].compact.each { |x| x.stop; (x.bufs || []).each { |y| vma.buffers.close_buffer(y.id) if vma.buffers.list.any? { |z| z.equal?(y) } } }
    drain_idle
  end

  def test_demo_duration
    DemoPlayer::DEMOS.each_key { |n|
      d = DemoPlayer.duration(n)
      assert d > 5 && d < 600, "#{n}: #{d} s"
      assert DemoPlayer.duration_text(n).match?(/\A\d+ (s|min)\z/)
    }
  end

  # ── Vim summary ──────────────────────────────────────────────────────────

  # Each row of the "keys that do something else" table matches the keymap
  def test_vim_key_table_matches_bindings
    all = vma.kbd.bindings
    VIM_INTRO_KEYS.each { |mode, keys, _vim, action|
      b = all.find { |x| x[:mode] == mode && x[:keys].join(" ") == keys && x[:template].nil? }
      assert b, "#{mode} #{keys}: not bound"
      assert_eq action, b[:action].to_s, "#{mode} #{keys}"
    }
    page = show_help_page("vim_intro")
    VIM_INTRO_KEYS.each { |_, keys, vim, _| assert page.lines.any? { |l| l.include?(keys) && l.include?(vim) }, keys }
  ensure
    close_help_pages
  end

  # ── At start ─────────────────────────────────────────────────────────────

  def test_intro_on_startup_rules
    was = cnf.intro.show_on_startup?
    sf = cnf.startup_file!
    cnf.intro.show_on_startup = true
    cnf.startup_file = false
    rule = lambda { |argv: [], forced: false, test_mode: false, session: []|
      intro_on_startup?(argv: argv, forced: forced, test_mode: test_mode, session: session)
    }
    assert rule.(), "fresh start"
    assert rule.(forced: true, test_mode: true, session: ["x"]), "--intro"
    assert !rule.(test_mode: true), "test mode"
    assert !rule.(argv: [File.join(REPO, "README.md")]), "file argument"
    assert !rule.(argv: [REPO]), "dir argument"
    assert !rule.(session: ["/x"]), "session to restore"
    cnf.startup_file = "/nonexistent/startup.txt"
    assert rule.(), "startup file that doesn't exist"
    cnf.startup_file = File.join(REPO, "README.md")
    assert !rule.(), "startup file opened"
    cnf.startup_file = false
    cnf.intro.show_on_startup = false
    assert !rule.(), "setting off"
  ensure
    cnf.intro.show_on_startup = was
    cnf.startup_file = sf
  end

  # Real starts: shown with a fresh config dir, not the second time, not
  # with a file to open; --intro shows it anyway
  def test_shown_on_first_start
    skip "needs a display" unless ENV["DISPLAY"] || ENV["WAYLAND_DISPLAY"]
    Dir.mktmpdir("vma-intro") { |tmp|
      ud = File.join(tmp, "user")
      assert_eq "intro", start_and_report(ud)
      assert_eq "nil", start_and_report(ud)
      assert_eq "intro", start_and_report(ud, "--intro")
      assert_eq "nil", start_and_report(File.join(tmp, "user2"), File.join(REPO, "README.md"))
      assert File.read(File.join(ud, "settings.rb")).include?("cnf.intro.show_on_startup = false")
    }
  end

  # Starts the editor with user dir ud; returns the help page shown once it
  # is up ("nil" for none)
  def start_and_report(ud, *args)
    FileUtils.mkdir_p(ud)
    out = File.join(ud, "shown.txt")
    FileUtils.rm_f(out)
    # custom.rb as on a real first start (from custom_example.rb), plus a
    # report of the page shown
    File.write(File.join(ud, "custom.rb"), File.read(File.join(REPO, "custom_example.rb")) + <<~RUBY)
      cnf.lsp.enabled = false
      def hook_custom_after_init
        GLib::Idle.add {
          File.write(#{out.inspect}, vma.buf.help_page.inspect.delete('"'))
          GLib::Timeout.add(200) { vma.shutdown; false }
          false
        }
      end
    RUBY
    pid = Process.spawn(*vma_editor_command(File.join(REPO, "exe/vimamsa")), "--user-dir", ud, *args,
                        out: File::NULL, err: File.join(ud, "log.txt"))
    t = Time.now
    until File.exist?(out) && File.size(out) > 0
      if Process.waitpid(pid, Process::WNOHANG)
        pid = nil
        break
      end
      if Time.now - t > 60
        break
      end
      sleep 0.05
    end
    if pid
      t = Time.now
      sleep 0.05 while Process.waitpid(pid, Process::WNOHANG).nil? && Time.now - t < 20
      Process.kill("KILL", pid) rescue nil
      Process.wait(pid) rescue nil
    end
    File.exist?(out) ? File.read(out) : "no report (log: #{File.read(File.join(ud, "log.txt"))[-500..]})"
  end
end
