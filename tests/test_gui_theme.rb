# Theme CSS (lib/vimamsa/gui_theme.rb)
class TestGuiTheme < VmaTest
  # Blurred shadows get stronger by the factor (at most opacity 1); shadows
  # without blur (inset 1px edge lines) stay as they are
  def test_scale_glows
    css = <<~CSS
      a { box-shadow: 0 0 12px rgba(61, 203, 184, 0.18); }
      b { box-shadow: inset 0 -1px 0 rgba(1, 2, 3, 0.18); }
      c { text-shadow: 0 0 5px rgba(1, 2, 3, 0.8); box-shadow: 0 0 6px rgba(1, 2, 3, 1.0),
          inset 0 0 5px rgba(1, 2, 3, 0.2); }
      d { -gtk-icon-shadow: 0 0 6px rgba(1, 2, 3, 0.45); }
    CSS
    out = scale_glows(css, 2.5)
    assert out.include?("0 0 12px rgba(61, 203, 184, 0.45)"), out
    assert out.include?("inset 0 -1px 0 rgba(1, 2, 3, 0.18)"), "edge line changed: #{out}"
    assert out.include?("text-shadow: 0 0 5px rgba(1, 2, 3, 1.0)"), "not capped at 1: #{out}"
    assert out.include?("inset 0 0 5px rgba(1, 2, 3, 0.5)"), out
    assert out.include?("-gtk-icon-shadow: 0 0 6px rgba(1, 2, 3, 1.0)"), out
    assert_eq css, scale_glows(css, 1.0)
  end

  # GTK 4.16+ draws the glows weaker (gui_theme.rb glow_scale): stronger there,
  # unchanged on older GTK
  def test_glow_scale_follows_gtk_version
    assert_eq (Gtk::Version.or_later?(4, 16) ? 2.5 : 1.0), gtk_glow_correction
    css = cyberpunk_css
    button_glow = css[/\bbutton \{[^}]*box-shadow: 0 0 12px (rgba\([^)]*\))/m, 1]
    assert button_glow, "no button glow in the theme CSS"
    want = Gtk::Version.or_later?(4, 16) ? "0.45" : "0.18"
    assert button_glow.end_with?(", #{want})"), "button glow #{button_glow}, want alpha #{want}"
  end

  # cnf.theme.glow_strength (conf.rb) multiplies every glow; 0 turns them off
  def test_glow_strength_setting
    old = cnf.theme.glow_strength!
    assert_eq 1.0, old, "default strength"
    cnf.theme.glow_strength = 0.5
    assert_eq 0.5 * gtk_glow_correction, glow_scale
    want = (0.18 * 0.5 * gtk_glow_correction).round(3).to_s
    assert cyberpunk_css.include?("0 0 12px rgba(61, 203, 184, #{want})"), "button glow not at #{want}"
    cnf.theme.glow_strength = 0
    assert cyberpunk_css.include?("0 0 12px rgba(61, 203, 184, 0.0)"), "glow not off at 0"
  ensure
    cnf.theme.glow_strength = old
  end
end
