module Vimamsa
# Help pages written as hyperplaintext templates in help/ (doc/intro_page_plan.md):
#   intro      the introduction page: shown on the first start and from
#              Help ▸ Introduction; buttons that start the demos
#   vim_intro  a one-screen summary of how vimlike differs from Vim
#
# Placeholders in the templates, filled in when a page is opened:
#   {key:ACTION} / {key:MODE:ACTION}  the keys bound to the action (up to two,
#       Command mode first, or only MODE), as ⦁keys⦁; the menu path if unbound
#   {demos}           one line per demo (DemoPlayer::DEMOS) with its button link
#   {vim_key_table}   the table of VIM_INTRO_KEYS
#
# Links ⟦run:ACTION|LABEL⟧ run an action (enter on the link, the context menu,
# or the button shown at the end of its line); only actions allowed by
# hpt_run_allowed? run, as any .txt file can contain such a link.

HELP_DIR = File.expand_path("../../help", __dir__)
HELP_PAGES = %w[intro vim_intro]

# Keys a Vim user hits first that do something else in vimlike: [mode, keys,
# what they do in Vim, the vimlike action]. The page shows the vimlike
# action's description; tests check the action against the live bindings.
VIM_INTRO_KEYS = [
  ["C", "s", "change a character", "jump.easy"],
  ["C", "C", "change to end of line", "grep.files"],
  ["C", "O", "open a line above", "move.line.end"],
  ["C", "X", "delete a character back", "edit.line.below"],
  ["C", "space <char>", "right, then a command", "edit.insert.char"],
  ["C", "tab", "jump forward", "buf.switch.last"],
  ["C", "z", "prefix (zz, zt)", "mode.browse"],
  ["C", "ctrl-o", "jump back", "file.open"],
  ["I", "ctrl-n", "completion", "move.line.next"],
  ["I", "ctrl-p", "completion", "move.line.prev"],
  ["I", "ctrl-c", "leave Insert mode", "sel.copy"],
]

# Actions that ⟦run:…⟧ links may run
HPT_RUN_ALLOWED = [/\Ahelp\./, /\Aapp\.demo\z/]

def hpt_run_allowed?(action)
  HPT_RUN_ALLOWED.any? { |re| re.match?(action.to_s) }
end

# Runs the action of a ⟦run:ACTION|LABEL⟧ link (spec = "ACTION|LABEL")
def hpt_run_link(spec)
  action = spec.split("|", 2)[0].strip
  if !hpt_run_allowed?(action)
    message("Link not run: #{action} is not allowed in ⟦run:…⟧ links")
    return false
  end
  if !vma.actions.include?(action)
    message("Link not run: no action #{action}")
    return false
  end
  call_action(action)
  true
end

# The ⟦…⟧ link around pos on its line (with the brackets), or nil
def hpt_link_at(str, pos)
  ls = pos == 0 ? 0 : (str.rindex("\n", pos - 1) || -1) + 1
  le = str.index("\n", pos) || str.size
  line = str[ls...le]
  line.to_enum(:scan, /⟦[^⟧\n]*⟧/).each {
    m = Regexp.last_match
    return m[0] if pos - ls >= m.begin(0) && pos - ls < m.end(0)
  }
  nil
end

# "⦁i⦁ or ⦁ctrl!⦁" for {key:SPEC}; SPEC is ACTION or MODE:ACTION
def help_key_text(spec, kbd = vma.kbd)
  mode, action = spec.include?(":") ? spec.split(":", 2) : [nil, spec]
  modes = mode ? [mode] : %w[C V I]
  recs = kbd.bindings.select { |b| b[:action].to_s == action && b[:template].nil? && modes.include?(b[:mode]) }
  # in mode order, bindings without conditions first, then as bound
  recs = recs.each_with_index.sort_by { |b, i| [modes.index(b[:mode]), b[:keys].any? { |k| k.include?("(") } ? 1 : 0, i] }.map(&:first)
  keys = recs.map { |b| b[:keys].join(" ") }.uniq.first(2)
  return keys.map { |k| "⦁#{k}⦁" }.join(" or ") if keys.any?
  path = vma.gui&.menu&.path_for(action) rescue nil
  path ? path : "(no key for #{action})"
end

def help_demo_lines
  DemoPlayer::DEMOS.map { |name, d|
    "⟦run:#{d[:action]}|▶ #{d[:title]}⟧ #{d[:desc]} (#{DemoPlayer.duration_text(name)})"
  }.join("\n")
end

def help_vim_key_table
  rows = VIM_INTRO_KEYS.map { |mode, keys, vim, action|
    k = mode == "C" ? keys : "#{KEY_MODE_NAMES[mode]} #{keys}"
    [k, vim, vma.kbd.action_desc(action.to_sym).to_s]
  }
  w0 = ["Key", *rows.map { |r| r[0] }].map(&:size).max
  w1 = ["Vim", *rows.map { |r| r[1] }].map(&:size).max
  (["#{"Key".ljust(w0)}  #{"Vim".ljust(w1)}  Vimamsa (vimlike)"] +
   rows.map { |k, v, d| "#{k.ljust(w0)}  #{v.ljust(w1)}  #{d}" }).map { |l| "    " + l }.join("\n")
end

# The text of help page name, with the placeholders filled in
def help_page_text(name)
  File.read(File.join(HELP_DIR, "#{name}.txt"))
      .gsub("{demos}") { help_demo_lines }
      .gsub("{vim_key_table}") { help_vim_key_table }
      .gsub(/\{key:([^}]+)\}/) { help_key_text($1) }
      .gsub(/⟦run:[^⟧\n]*⟧/) { "#{HPT_BUTTON_SLOT}#{$&}" } # the char a button takes
end

# Before each ⟦run:…⟧ link of a help page: the link's button takes its place
# (before, not after: GTK doesn't draw a child widget that follows invisible
# text)
HPT_BUTTON_SLOT = " "

# Opens help page name in a read-only buffer, or switches to it if open
def show_help_page(name)
  b = vma.buffers.list.find { |x| x.help_page == name }
  if b
    vma.buffers.set_current_buffer_by_id(b.id)
    return b
  end
  b = create_new_buffer(help_page_text(name), name)
  b.help_page = name
  b.read_only = true
  gui_set_file_lang(b.id, "hyperplaintext")
  b.set_pos(0)
  help_add_run_buttons(b)
  b
end

# A button in place of each ⟦run:ACTION|LABEL⟧ link: the link text is hidden
# (an invisible GTK tag, so the text stays and keeps its offsets) and the
# button takes the place of the HPT_BUTTON_SLOT char before it, so the GTK
# buffer keeps the same length as the Buffer. In a buffer that can be edited
# the link text shows again, instead of the button, while the cursor is on its
# line (hpt_update_run_buttons); in a read-only one (help pages) never.
def help_add_run_buttons(b)
  view = b.view
  return if view.nil?
  vbuf = view.buffer
  help_button_refresh_css if $help_button_css_provider.nil?
  b.help_buttons = []
  b.to_enum(:scan, /#{HPT_BUTTON_SLOT}⟦run:([^|⟧\n]+)\|([^⟧\n]+)⟧/).map { Regexp.last_match }.each { |m|
    action, label = m[1], m[2]
    at = m.begin(0) # the slot
    vbuf.delete(vbuf.get_iter_at(offset: at), vbuf.get_iter_at(offset: at + 1))
    anchor = vbuf.create_child_anchor(vbuf.get_iter_at(offset: at))
    btn = Gtk::Button.new(label: label)
    btn.focus_on_click = false
    btn.add_css_class("help-run-button")
    btn.valign = :baseline_center rescue nil # the label on the text's baseline (GTK 4.12+)
    btn.signal_connect("clicked") { hpt_run_link(action) }
    view.add_child_at_anchor(btn, anchor)
    b.help_buttons << [action, btn, anchor]
  }
  hpt_watch_run_buttons
  hpt_update_run_buttons(b)
end

# Looks of the ⟦run:…⟧ buttons (cnf.help.button_style, Settings ▸
# Appearance). Each is CSS for button.help-run-button, in its own provider
# above the theme's (PRIORITY_USER + 1), so the theme's general button rule
# (border, glow) doesn't override it. c: a cyberpunk palette color.
HELP_BUTTON_STYLES = {
  # small, square-cornered, the theme's colors, no glow
  "flat" => lambda { |c| <<~CSS },
    button.help-run-button { padding: 0px 6px; margin: 0px; min-height: 0px; font-size: 80%;
      border-radius: 1px; box-shadow: none; }
  CSS
  # like a link: accent text, underlined; tinted on hover
  "link" => lambda { |c| <<~CSS },
    button.help-run-button { padding: 0px 2px; margin: 0px; min-height: 0px;
      background: none; border: none; box-shadow: none; border-radius: 2px;
      color: #{c[:base]}; font-weight: bold; }
    button.help-run-button label { text-decoration: underline; }
    button.help-run-button:hover { background: #{cyber_rgba(c[:base], 0.18)}; color: #{c[:base_bright]}; }
  CSS
  # rounded pill: thin accent outline, faint accent fill
  "pill" => lambda { |c| <<~CSS },
    button.help-run-button { padding: 0px 10px; margin: 0px 2px; min-height: 0px; font-size: 90%;
      border-radius: 999px; border: 1px solid #{cyber_rgba(c[:base], 0.8)}; box-shadow: none;
      background: #{cyber_rgba(c[:base], 0.12)}; color: #{c[:base_bright]}; }
    button.help-run-button:hover { background: #{cyber_rgba(c[:base], 0.35)}; color: #{c[:hover_bright]}; }
  CSS
  # filled with the accent color, dark bold text
  "solid" => lambda { |c| <<~CSS },
    button.help-run-button { padding: 0px 8px; margin: 0px 2px; min-height: 0px; font-size: 90%;
      border-radius: 3px; border: none; box-shadow: none; font-weight: bold;
      background: #{c[:base]}; color: #{c[:bg_mid]}; }
    button.help-run-button:hover { background: #{c[:base_bright]}; color: #{c[:bg_end]}; }
  CSS
  # a key cap: monospace, a thicker bottom edge
  "key" => lambda { |c| <<~CSS },
    button.help-run-button { padding: 0px 6px; margin: 0px 2px; min-height: 0px; font-family: monospace; font-size: 90%;
      border-radius: 4px; border: 1px solid #{cyber_rgba(c[:base], 0.6)}; border-bottom-width: 3px; box-shadow: none;
      background: #{c[:button_bg]}; color: #{c[:window_fg]}; }
    button.help-run-button:hover { border-color: #{c[:base_bright]}; color: #{c[:hover_bright]}; }
  CSS
}

def help_button_css(style = cnf.help.button_style!)
  c = Hash.new { |_h, k| cyber_color(k) }
  (HELP_BUTTON_STYLES[style.to_s] || HELP_BUTTON_STYLES["solid"]).call(c)
end

# Installs or reloads the button CSS (at the first help page and when the
# colors or settings change: gui_refresh_colors)
def help_button_refresh_css
  return if Gdk::Display.default.nil?
  if $help_button_css_provider.nil?
    $help_button_css_provider = Gtk::CssProvider.new
    Gtk::StyleContext.add_provider_for_display(Gdk::Display.default, $help_button_css_provider,
                                               Gtk::StyleProvider::PRIORITY_USER + 1)
  end
  $help_button_css_provider.load(data: help_button_css)
end

# The hidden-text tag of b's GTK buffer
def hpt_hidden_tag(vbuf)
  vbuf.tag_table.lookup("hpt_hidden") || vbuf.create_tag("hpt_hidden", { "invisible" => true })
end

# [anchor offset, link end, button] of each button of b, in order: the link
# is from anchor + 1 to link end
def hpt_button_ranges(b)
  vbuf = b.view.buffer
  b.help_buttons.map { |action, btn, anchor|
    at = vbuf.get_iter_at_child_anchor(anchor).offset
    m = b[(at + 1)..].match(/\A⟦run:[^⟧\n]*⟧/)
    [at, m ? at + 1 + m.end(0) : at + 1, btn]
  }
end

# Hides the link text and shows the button, or (editable buffer, cursor on
# the line) the other way round. In a read-only buffer the cursor moves off
# hidden text onto the button.
def hpt_update_run_buttons(b)
  return if b.nil? || b.help_buttons.nil? || b.help_buttons.empty? || b.view.nil?
  vbuf = b.view.buffer
  tag = hpt_hidden_tag(vbuf)
  ranges = hpt_button_ranges(b)
  ranges.each { |at, to, btn|
    s, e = vbuf.get_iter_at(offset: at + 1), vbuf.get_iter_at(offset: to)
    on_line = !b.read_only && b.get_line_start(b.pos) == b.get_line_start(at)
    if on_line
      vbuf.remove_tag(tag, s, e)
      btn.visible = false
    else
      vbuf.apply_tag(tag, s, e)
      btn.visible = true
    end
  }
  if b.read_only && (r = ranges.find { |at, to, _| b.pos > at && b.pos < to })
    b.set_pos(r[0])
  end
end

# Updates the buttons of the current buffer after each key action and buffer
# switch (registered once)
def hpt_watch_run_buttons
  return if $hpt_run_buttons_watched
  $hpt_run_buttons_watched = true
  vma.kbd.on(:action_handled) { |*_| hpt_update_run_buttons(vma.buf) }
  vma.hook.register(:change_buffer, method(:hpt_update_run_buttons))
end

# Show the introduction page at start? argv: the command line arguments
# (exe/vimamsa has removed --intro and --user-dir)
def intro_on_startup?(argv: ARGV, forced: $vma_show_intro, test_mode: vma_test_mode?, session: nil)
  return true if forced
  return false if test_mode || !cnf.intro.show_on_startup?
  # a startup file that is opened (custom_example.rb sets one that usually
  # doesn't exist)
  return false if cnf.startup_file? && File.exist?(File.expand_path(cnf.startup_file!))
  return false if argv.any? { |a| File.exist?(File.expand_path(a)) }
  return false if (session || session_files_to_restore).any?
  true
end

# Files of the last session that would be offered for restoring
def session_files_to_restore
  path = get_dot_path("session.txt")
  return [] if !File.exist?(path)
  File.read(path).lines.map(&:strip).reject(&:empty?).select { |f| File.exist?(f) }
end

# Called at the end of Editor#start. After the page has been shown at start
# once, it isn't shown at start again (cnf.intro.show_on_startup = false,
# saved in settings.rb), unless --intro is given.
def show_intro_on_startup
  return if !intro_on_startup?
  show_help_page("intro")
  if !$vma_show_intro && cnf.intro.show_on_startup?
    cnf.intro.show_on_startup = false
    save_settings_to_file(quiet: true)
  end
end

def toggle_intro_on_startup
  cnf.intro.show_on_startup = !cnf.intro.show_on_startup?
  save_settings_to_file(quiet: true)
  message(cnf.intro.show_on_startup? ? "The introduction page will be shown at the next start" :
                                       "The introduction page won't be shown at start (Help ▸ Introduction)")
end
end # module Vimamsa
