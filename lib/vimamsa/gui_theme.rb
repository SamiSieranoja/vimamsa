
module Vimamsa

# Absolute path to this file, captured once, so gui_reload_theme_and_colors
# can `load` it again to pick up hand-edited palette defaults at runtime.
# `unless defined?` keeps a reload from re-pinning / warning on it.
GUI_THEME_FILE = File.expand_path(__FILE__) unless defined?(GUI_THEME_FILE)

# Optional "cyberpunk glow" chrome theme: neon teal/amber accents with glow
# shadows on near-black navy, ported from the rterm terminal project.
# Off by default; toggled via cnf.theme.cyberpunk_glow (Settings > Appearance).
# Only window chrome is themed — source view text colors stay with the
# GtkSourceView style scheme.

# ── Palettes ──────────────────────────────────────────────────────────────
# All GUI chrome / highlight colors live here as two named palettes. Every
# entry is overridable at runtime via config with no restart:
#   cnf.theme.colors.<name> = "#rrggbb"   # baseline palette (theme off)
#   cnf.theme.cyber.<name>  = "#rrggbb"   # cyberpunk-glow palette (theme on)
# after which `gui_refresh_colors` (called on settings-save, or bind it to a
# key) re-reads the values and reloads the CSS providers live.
#
# The hashes below are only the *defaults* — a cnf override wins per-key
# (see theme_color / cyber_color). Mode *cursor* colors and the search-match
# color already have their own config (cnf.mode.*.cursor, cnf.match.highlight
# .color) and are intentionally not duplicated here.

# Cyberpunk-glow palette. Defaults mirror the user's live rterm colors
# (~/.config/rterm/settings.json), not the rterm repo defaults.
CYBER_COLOR_DEFAULTS = {
  base: "#3dcbb8",        # neon teal — primary accent
  base_bright: "#81dbd6", # same teal hue, brighter — hover states
  highlight: "#81dbd6",   # light cyan — secondary accent / glow
  bg_start: "#026b65",
  bg_mid: "#0d1224",
  bg_end: "#090c18",
  window_fg: "#d6f7ff",
  header_bg: "#014a47",
  button_bg: "#0d172e",
  button_hover_bg: "#1f3330",
  sidebar_bg: "#080e1c",
  stack_bg: "#03080f",
  status_bg: "#080e1c",
  status_fg: "#9fd7e4",
  tree_selection_fg: "#d5f7f5",
  # neon mode-badge tints (lit-tube colors per mode)
  badge_glow_command: "#ffc5ff",
  badge_glow_insert:  "#9fe8a4",
  badge_glow_visual:  "#ffc890",
  badge_glow_browse:  "#ff9fb7",
  badge_glow_replace: "#ff9d94",
  badge_glow_other:   "#c5c5ff",
}

# Baseline (default, non-cyberpunk) palette.
THEME_COLOR_DEFAULTS = {
  # chrome
  header_fg:       "#d8e6ee",
  menu_item_fg:    "#b8ccd8",
  gutter_fg:       "#8aa",
  title_fg:        "#cdffee",
  action_trail_fg: "#aaaaaa",
  keytrail_fg:     "#e6db74",
  # mode badge (base + per-mode background)
  badge_fg:        "#1b1d1e",
  badge_bg:        "#75715e",
  badge_command:   "#9e4cff",
  badge_insert:    "#78bf78",
  badge_visual:    "#d49e63",
  badge_browse:    "#a96bb0",
  badge_replace:   "#d66d63",
  badge_other:     "#9670d6",
  # minibuffer / command line
  minibuf_fg:      "#cdd6f4",
  minibuf_bg:      "#1e1e2e",
  # key log panel newest-row outline
  keylog_newest_border: "#94ffbb",
  # media controls strip
  medctr_bg:       "#353535",
  # source-view selected-text foreground
  selection_fg:    "#ffffff",
  # text-highlight helpers (Gui.hilight_range / highlight_match defaults + callers)
  highlight_default: "#aa0000ff", # generic range highlight
  search_jump:       "#4488ffff", # jump-to-match highlight (file_manager)
  buffer_switch:     "#666666ff", # buffer-switch highlight (buffer_manager)
}

# Look up a baseline palette color by name: a cnf.theme.colors.<name> override
# if set, else the default. Callable everywhere (the Vimamsa module is mixed
# into Object), including as a default-argument expression.
def theme_color(name)
  cnf_get([:theme, :colors, name]) || THEME_COLOR_DEFAULTS.fetch(name)
end

# Look up a cyberpunk palette color: a cnf.theme.cyber.<name> override if set,
# else the default.
def cyber_color(name)
  cnf_get([:theme, :cyber, name]) || CYBER_COLOR_DEFAULTS.fetch(name)
end

# Baseline chrome CSS (always installed; the cyberpunk provider layers over it
# at PRIORITY_USER when enabled). Colors come from theme_color; layout is
# literal. Relocated here from gui.rb so all color code lives in this file.
def base_chrome_css
  <<~CSS
    /* Edge-lit panel: near-black chrome, neon-cyan bottom edge */
    headerbar { padding: 0 0px; min-height: 16px; border-width: 0 0 0px; border-style: solid; color: #{theme_color(:header_fg)}; }

    menubar { background: transparent; }
    menubar > item { color: #{theme_color(:menu_item_fg)}; }

    /* Relative size so the gutter tracks the editor font setting
       (a fixed pt size left the gutter unchanged when the font changed). */
    textview border.left gutter { padding: 0px 0px 0px 0px; margin: 0px 0px 0px 0px; color: #{theme_color(:gutter_fg)}; font-size: 85%; }

    headerbar .title { font-weight: bold; font-size: 11pt; color: #{theme_color(:title_fg)}; }

    headerbar > windowhandle > box .start { border-spacing: 6px; }

    headerbar windowcontrols button { min-height: 15px; min-width: 15px; }

    popover background > contents { padding: 8px; border-radius: 20px; }

    label.action-trail { font-family: monospace; font-size: 10pt; margin-right: 8px; color: #{theme_color(:action_trail_fg)}; }

    label.mode-badge {
      font-family: monospace; font-size: 9pt; font-weight: 800;
      padding: 1px 7px; margin: 2px 4px 2px 0;
      border-radius: 2px; min-width: 65px;
      color: #{theme_color(:badge_fg)}; background-color: #{theme_color(:badge_bg)};
      transition: background-color 120ms ease-out;
    }
    label.mode-badge.mode-command { background-color: #{theme_color(:badge_command)}; }
    label.mode-badge.mode-insert  { background-color: #{theme_color(:badge_insert)}; }
    label.mode-badge.mode-visual  { background-color: #{theme_color(:badge_visual)}; }
    label.mode-badge.mode-browse  { background-color: #{theme_color(:badge_browse)}; }
    label.mode-badge.mode-replace { background-color: #{theme_color(:badge_replace)}; }
    label.mode-badge.mode-other   { background-color: #{theme_color(:badge_other)}; }

    label.keytrail { font-family: monospace; font-size: 10pt; font-weight: bold; color: #{theme_color(:keytrail_fg)}; }
  CSS
end

# CSS for the minibuffer / command-line widgets (shared provider in gui.rb).
def minibuf_css
  "label.minibuf, textview.minibuf, entry.minibuf { color: #{theme_color(:minibuf_fg)}; font-family: Monospace; font-size: 10pt; padding: 3px 8px; background-color: #{theme_color(:minibuf_bg)}; }"
end

# CSS for the key log panel's highlighted newest row.
def keylog_row_css
  "row.keylog-newest { color:#fff; background-color: alpha(#000000, 0.12); border: 3px solid #{theme_color(:keylog_newest_border)}; }"
end

def cyber_rgba(hex, alpha)
  "rgba(#{hex[1, 2].to_i(16)}, #{hex[3, 2].to_i(16)}, #{hex[5, 2].to_i(16)}, #{alpha})"
end

def cyberpunk_css
  c = Hash.new { |_h, k| cyber_color(k) }
  base = c[:base]
  highlight = c[:highlight]
  # Neon-sign mode badge: transparent center, thin border + text glowing in
  # the mode's color (lightened tints of the baseline badge palette so they
  # read as lit neon tubes on the dark chrome).
  badge_glow = { "mode-command" => c[:badge_glow_command], "mode-insert" => c[:badge_glow_insert],
                 "mode-visual" => c[:badge_glow_visual], "mode-browse" => c[:badge_glow_browse],
                 "mode-replace" => c[:badge_glow_replace], "mode-other" => c[:badge_glow_other] }
    .map { |cls, col|
      <<~RULE
        label.mode-badge.#{cls} {
          color: #{col};
          border-color: #{col};
          background-color: transparent;
          text-shadow: 0 0 5px #{cyber_rgba(col, 0.8)};
          box-shadow: 0 0 6px #{cyber_rgba(col, 1.0)},
                      inset 0 0 5px #{cyber_rgba(col, 1.00)};
        }
      RULE
    }.join("\n  ")

  <<~CSS
  window {
    background: linear-gradient(180deg, #{c[:bg_start]} 0%, #{c[:bg_mid]} 55%, #{c[:bg_end]} 100%);
    color: #{c[:window_fg]};
  }

  headerbar, headerbar.titlebar, window > headerbar {
    background-color: #{c[:header_bg]};
    background-image: none;
    color: #fff;
    border-bottom: 1px solid #{cyber_rgba(base, 0.65)};
    box-shadow: inset 0 -1px 0 #{cyber_rgba(highlight, 0.18)};
  }

  headerbar .title {
    color: #fff;
    text-shadow: 0 0 12px #{cyber_rgba(highlight, 0.4)};
    font-family: "Oxanium", sans-serif;
  }

  box.menubar-row {
    background: #{c[:header_bg]};
    border-bottom: 1px solid #{cyber_rgba(base, 0.65)};
    box-shadow: inset 0 -1px 0 #{cyber_rgba(highlight, 0.18)};
  }

  menubar { background: transparent; font-family: "Oxanium", sans-serif; }
  menubar > item { color: #{base}; }
  menubar > item:hover {
    background: #{cyber_rgba(c[:base_bright], 0.18)};
    color: #{c[:base_bright]};
  }

  paned > separator {
    background: #{cyber_rgba(highlight, 0.34)};
    min-width: 1px;
    min-height: 1px;
  }

  .side-panel {
    background: #{cyber_rgba(c[:sidebar_bg], 0.95)};
    border-right: 1px solid #{cyber_rgba(base, 0.3)};
    box-shadow: inset -1px 0 0 #{cyber_rgba(highlight, 0.12)};
  }

  .side-panel treeview {
    background: transparent;
    color: #{base};
    font-family: "Oxanium", sans-serif;
  }

  .side-panel treeview:selected,
  .side-panel treeview:selected:focus {
    background: #{cyber_rgba(highlight, 0.24)};
    color: #{c[:tree_selection_fg]};
    box-shadow: 0 0 7px #{cyber_rgba(highlight, 0.3)};
  }

  .side-panel label { color: #{base}; font-family: "Oxanium", sans-serif; }

  .side-panel list, .side-panel list > row {
    background: transparent;
    color: #{base};
  }

  .side-panel row.keylog-newest {
    color: #fff;
    background-color: transparent;
    border: 1px solid #{cyber_rgba(c[:base_bright], 0.9)};
    border-radius: 5px;
    box-shadow: 0 0 8px #{cyber_rgba(c[:base_bright], 0.4)},
                inset 0 0 6px #{cyber_rgba(c[:base_bright], 0.15)};
  }

  scrolledwindow.editor-frame {
    border: 1px solid #{cyber_rgba(base, 0.34)};
    box-shadow: 0 0 7px #{cyber_rgba(highlight, 0.15)},
                0 0 28px #{cyber_rgba(base, 0.12)};
  }

  label.minibuf, textview.minibuf, entry.minibuf {
    background-color: #{c[:status_bg]};
    color: #{c[:status_fg]};
    border-top: 1px solid #{cyber_rgba(base, 0.34)};
    box-shadow: inset 0 1px 0 #{cyber_rgba(highlight, 0.08)};
  }

  label.keytrail {
    text-shadow: 0 0 8px #{cyber_rgba(highlight, 0.6)};
  }

  label.mode-badge {
    background-color: transparent;
    border: 1px solid #{base};
    border-radius: 2px;
    padding: 2px 12px;
    font-family: "Oxanium", monospace;
    font-size: 10pt;
    font-weight: 700;
    color: #{base};
  }

  #{badge_glow}

  button {
    background: #{cyber_rgba(c[:button_bg], 0.92)};
    color: #{base};
    border: 1px solid #{cyber_rgba(base, 0.72)};
    border-radius: 10px;
    box-shadow: 0 0 12px #{cyber_rgba(base, 0.18)};
  }

  button:hover {
    background: #{cyber_rgba(c[:button_hover_bg], 0.96)};
    color: #{c[:base_bright]};
    border-color: #{cyber_rgba(c[:base_bright], 0.9)};
    box-shadow: 0 0 16px #{cyber_rgba(c[:base_bright], 0.3)};
  }

  popover > contents {
    background: #{c[:bg_mid]};
    color: #{c[:window_fg]};
    border: 1px solid #{cyber_rgba(base, 0.34)};
  }

  window.vma-dialog {
    background: #{c[:bg_mid]};
    border: 1px solid #{cyber_rgba(base, 0.5)};
  }

  .vma-dialog entry {
    background: #{cyber_rgba(c[:button_bg], 0.92)};
    color: #{c[:window_fg]};
    border: 1px solid #{cyber_rgba(base, 0.4)};
    border-radius: 6px;
  }

  .vma-dialog entry:focus-within {
    border-color: #{cyber_rgba(c[:base_bright], 0.9)};
    box-shadow: 0 0 12px #{cyber_rgba(c[:base_bright], 0.25)};
  }

  .vma-dialog treeview {
    background: #{c[:stack_bg]};
    color: #{base};
  }

  .vma-dialog treeview:selected,
  .vma-dialog treeview:selected:focus {
    background: #{cyber_rgba(highlight, 0.24)};
    color: #{c[:tree_selection_fg]};
    box-shadow: 0 0 7px #{cyber_rgba(highlight, 0.3)};
  }

  .vma-dialog scrolledwindow { background: transparent; }

  .vma-dialog spinbutton {
    background: #{cyber_rgba(c[:button_bg], 0.92)};
    color: #{c[:window_fg]};
    border: 1px solid #{cyber_rgba(base, 0.4)};
    border-radius: 6px;
  }

  .vma-dialog spinbutton > text {
    background: transparent;
    color: #{c[:window_fg]};
  }

  .vma-dialog switch {
    background: #{cyber_rgba(c[:button_bg], 0.92)};
    border: 1px solid #{cyber_rgba(base, 0.4)};
  }

  .vma-dialog switch:checked {
    background: #{cyber_rgba(base, 0.45)};
    border-color: #{cyber_rgba(highlight, 0.9)};
    box-shadow: 0 0 10px #{cyber_rgba(highlight, 0.25)};
  }

  .vma-dialog switch > slider {
    background: #{c[:status_fg]};
    border: none;
  }

  .vma-dialog notebook > header {
    background: #{c[:header_bg]};
    border-bottom: 1px solid #{cyber_rgba(base, 0.34)};
  }

  .vma-dialog notebook > header tab { color: #{base}; }

  .vma-dialog notebook > header tab:checked {
    color: #{highlight};
    box-shadow: inset 0 -2px 0 #{cyber_rgba(highlight, 0.6)};
  }

  .vma-dialog notebook stack { background: transparent; }

  .vma-dialog frame > border { border-color: #{cyber_rgba(base, 0.34)}; }
  CSS
end

# Install or remove the cyberpunk theme according to cnf.theme.cyberpunk_glow.
# Called at startup (gui.rb) and when settings are saved (gui_settings.rb).
# PRIORITY_USER so the theme outranks the baseline display provider and the
# per-widget minibuf provider (both PRIORITY_APPLICATION); removing the
# provider restores the default look exactly.
def gui_refresh_theme
  return unless $vmag
  # Keep the buffer color scheme in step with the chrome: the navy
  # molokai_cyber variant goes with the theme, plain molokai_edit without it.
  # A scheme the user picked themselves is left alone.
  if cnf.theme.cyberpunk_glow? && cnf.style_scheme! == "molokai_edit"
    cnf.style_scheme = "molokai_cyber"
    gui_refresh_style_scheme
  elsif !cnf.theme.cyberpunk_glow? && cnf.style_scheme! == "molokai_cyber"
    cnf.style_scheme = "molokai_edit"
    gui_refresh_style_scheme
  end
  disp = Gdk::Display.default
  if $vmag.cyber_css_provider
    Gtk::StyleContext.remove_provider_for_display(disp, $vmag.cyber_css_provider)
    $vmag.cyber_css_provider = nil
  end
  if cnf.theme.cyberpunk_glow?
    prov = Gtk::CssProvider.new
    prov.load(data: cyberpunk_css)
    Gtk::StyleContext.add_provider_for_display(disp, prov, Gtk::StyleProvider::PRIORITY_USER)
    $vmag.cyber_css_provider = prov
  end
end

# Re-read every color from cnf and reload the CSS providers in place, so
# changing a cnf.theme.colors.* / cnf.theme.cyber.* value takes effect at
# runtime without restarting. Bound to :refresh_colors (see key_actions.rb)
# and called by the settings dialog on save.
def gui_refresh_colors
  return unless $vmag
  $vmag.chrome_css_provider&.load(data: base_chrome_css)
  $vmag.minibuf_css_provider&.load(data: minibuf_css)
  $vmag.keylog_panel&.refresh_css
  gui_refresh_theme   # rebuilds/reloads the cyberpunk provider from current cnf
end

# Re-`load` this source file, then refresh. Unlike gui_refresh_colors (which
# only re-reads cnf), this also picks up edits to the THEME_COLOR_DEFAULTS /
# CYBER_COLOR_DEFAULTS palette constants in the source — so tweaking the
# default colors and hitting :refresh_colors applies them without a restart.
# Warnings from redefining the palette constants are silenced during the load.
def gui_reload_theme_and_colors
  begin
    verbose, $VERBOSE = $VERBOSE, nil
    load GUI_THEME_FILE
  ensure
    $VERBOSE = verbose
  end
  gui_refresh_colors
  message("Theme colors reloaded from #{File.basename(GUI_THEME_FILE)}") if defined?(message)
end

end
