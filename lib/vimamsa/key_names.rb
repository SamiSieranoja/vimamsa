module Vimamsa
# The editor's names for GTK key events ("j", "ctrl-r", "shift-tab", "esc",
# "ctrl" for the key alone), used by the editor window (VSourceView#
# handle_key_event) and by forms (form_input.rb), so both feed the key
# bindings the same names.

GUI_KEYVAL_NAMES = {
  Gdk::Keyval::KEY_Control_L => "ctrl",
  Gdk::Keyval::KEY_Control_R => "ctrl",
  Gdk::Keyval::KEY_Escape => "esc",
  Gdk::Keyval::KEY_Return => "enter",
  Gdk::Keyval::KEY_ISO_Enter => "enter",
  Gdk::Keyval::KEY_KP_Enter => "enter",
  Gdk::Keyval::KEY_Alt_L => "alt",
  Gdk::Keyval::KEY_Alt_R => "alt",
  Gdk::Keyval::KEY_Caps_Lock => "caps",
  Gdk::Keyval::KEY_BackSpace => "backspace",
  Gdk::Keyval::KEY_KP_Page_Down => "pagedown",
  Gdk::Keyval::KEY_KP_Page_Up => "pageup",
  Gdk::Keyval::KEY_Page_Down => "pagedown",
  Gdk::Keyval::KEY_Page_Up => "pageup",
  Gdk::Keyval::KEY_Left => "left",
  Gdk::Keyval::KEY_Right => "right",
  Gdk::Keyval::KEY_Down => "down",
  Gdk::Keyval::KEY_Up => "up",
  Gdk::Keyval::KEY_space => "space",
  Gdk::Keyval::KEY_Shift_L => "shift",
  Gdk::Keyval::KEY_Shift_R => "shift",
  Gdk::Keyval::KEY_Tab => "tab",
  Gdk::Keyval::KEY_ISO_Left_Tab => "tab",
  Gdk::Keyval::KEY_Home => "home",
  Gdk::Keyval::KEY_KP_Home => "home",
  Gdk::Keyval::KEY_End => "end",
  Gdk::Keyval::KEY_KP_End => "end",
  Gdk::Keyval::KEY_Delete => "delete",
  Gdk::Keyval::KEY_KP_Delete => "delete",
}

# The key name for a key event: keyval (Gdk keyval), keystr (its character,
# Gdk::Keyval.to_unicode), modifiers (vma.kbd.modifiers: :ctrl, :alt, :shift,
# :meta, :super). "" for a key with no name.
def gui_key_name(keyval, keystr, modifiers = vma.kbd.modifiers)
  keyname = GUI_KEYVAL_NAMES[keyval] || keystr
  parts = []
  parts << "ctrl" if modifiers[:ctrl]
  parts << "alt" if modifiers[:alt]
  parts << "shift" if modifiers[:shift]
  parts << "meta" if modifiers[:meta]
  parts << "super" if modifiers[:super]
  parts << keyname

  # After remapping capslock to control in gnome-tweak tool, pressing and
  # immediately releasing the capslock (control) key gives first "caps" on
  # keydown and ctrl-"caps" on keyup (keyval 65509, KEY_Caps_Lock). Mapping
  # capslock to ctrl in hardware gives keyval 65507 (KEY_Control_L) instead.
  parts.delete_at(1) if parts[0] == "ctrl" && parts[1] == "caps"

  # No "ctrl-ctrl" or "alt-alt"
  parts.delete_at(0) if parts[0] == parts[1]

  # "shift-P" is just "P", but shift-tab stays
  parts.delete_at(0) if parts[0] == "shift" && parts.size == 2 && parts[1].size == 1

  key_str = parts.join("-")
  key_str == "\u0000" ? "" : key_str
end

# vma.kbd.modifiers from a key controller's "modifiers" signal (modtype:
# Gdk::ModifierType), for the editor window and forms
def gui_set_modifiers(modtype)
  m = vma.kbd.modifiers
  m[:ctrl] = modtype.control_mask?
  m[:alt] = modtype.alt_mask?
  m[:hyper] = modtype.hyper_mask?
  m[:lock] = modtype.lock_mask?
  m[:meta] = modtype.meta_mask?
  m[:shift] = modtype.shift_mask?
  m[:super] = modtype.super_mask?
end
end # module Vimamsa
