
module Vimamsa

# Optional "cyberpunk glow" chrome theme: neon teal/amber accents with glow
# shadows on near-black navy, ported from the rterm terminal project.
# Off by default; toggled via cnf.theme.cyberpunk_glow (Settings > Appearance).
# Only window chrome is themed — source view text colors stay with the
# GtkSourceView style scheme.

# Palette mirrors the user's live rterm colors (~/.config/rterm/settings.json),
# not the rterm repo defaults.
CYBER_COLORS = {
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
}

def cyber_rgba(hex, alpha)
  "rgba(#{hex[1, 2].to_i(16)}, #{hex[3, 2].to_i(16)}, #{hex[5, 2].to_i(16)}, #{alpha})"
end

def cyberpunk_css
  c = CYBER_COLORS
  base = c[:base]
  highlight = c[:highlight]
  # Neon-sign mode badge: transparent center, thin border + text glowing in
  # the mode's color (lightened tints of the baseline badge palette in gui.rb
  # so they read as lit neon tubes on the dark chrome).
  badge_glow = { "mode-command" => "#a99aff", "mode-insert" => "#9fe8a4",
                 "mode-visual" => "#ffc890", "mode-browse" => "#dda3e4",
                 "mode-replace" => "#ff9d94", "mode-other" => "#c3a4ff" }
    .map { |cls, col|
      <<~RULE
        label.mode-badge.#{cls} {
          color: #{col};
          border-color: #{col};
          background-color: transparent;
          text-shadow: 0 0 5px #{cyber_rgba(col, 0.8)};
          box-shadow: 0 0 6px #{cyber_rgba(col, 0.5)},
                      inset 0 0 5px #{cyber_rgba(col, 0.25)};
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
    border-radius: 5px;
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

end
