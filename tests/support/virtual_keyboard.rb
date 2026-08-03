# frozen_string_literal: true

# A minimal Linux uinput virtual keyboard. Creates a real kernel input device and
# emits genuine evdev key events, which flow kernel -> libinput -> compositor ->
# the focused GTK app — i.e. as realistic as a physical keyboard, including
# separate, precisely-timed key down/up events.
#
# Talks to /dev/uinput directly with Ruby's built-in IO#ioctl (no FFI needed).
# Requires write access to /dev/uinput (e.g. granted to the user via an ACL).
#
# References: linux/uinput.h, linux/input.h, linux/input-event-codes.h.
class VirtualKeyboard
  # event types
  EV_SYN = 0x00
  EV_KEY = 0x01
  SYN_REPORT = 0x00

  KEY_LEFTSHIFT = 42
  KEY_RIGHTALT  = 100 # AltGr on international layouts

  # _IOC encoding (asm-generic/ioctl.h)
  IOC_NONE  = 0
  IOC_WRITE = 1
  NRBITS    = 8
  TYPEBITS  = 8
  SIZEBITS  = 14
  NRSHIFT    = 0
  TYPESHIFT  = NRSHIFT + NRBITS
  SIZESHIFT  = TYPESHIFT + TYPEBITS
  DIRSHIFT   = SIZESHIFT + SIZEBITS
  UINPUT_IOCTL_BASE = "U".ord

  def self._ioc(dir, type, nr, size)
    (dir << DIRSHIFT) | (type << TYPESHIFT) | (nr << NRSHIFT) | (size << SIZESHIFT)
  end

  UI_SET_EVBIT  = _ioc(IOC_WRITE, UINPUT_IOCTL_BASE, 100, 4) # int arg
  UI_SET_KEYBIT = _ioc(IOC_WRITE, UINPUT_IOCTL_BASE, 101, 4) # int arg
  # struct uinput_setup: input_id(8) + char name[80] + __u32 ff_effects_max = 92
  UINPUT_SETUP_SIZE = 8 + 80 + 4
  UI_DEV_SETUP   = _ioc(IOC_WRITE, UINPUT_IOCTL_BASE, 3, UINPUT_SETUP_SIZE)
  UI_DEV_CREATE  = _ioc(IOC_NONE, UINPUT_IOCTL_BASE, 1, 0) # 0x5501
  UI_DEV_DESTROY = _ioc(IOC_NONE, UINPUT_IOCTL_BASE, 2, 0) # 0x5502

  BUS_USB = 0x03

  # Advertise every standard key code so any character can be typed.
  KEYS = (1..248).to_a.freeze

  def self.available?
    File.writable?("/dev/uinput")
  end

  def initialize
    @fd = nil
  end

  def open
    @fd = File.open("/dev/uinput", File::WRONLY | File::NONBLOCK)
    @fd.sync = true # unbuffered: nothing to flush at close (avoids EINVAL)

    @fd.ioctl(UI_SET_EVBIT, EV_KEY)
    @fd.ioctl(UI_SET_EVBIT, EV_SYN)
    KEYS.each { |code| @fd.ioctl(UI_SET_KEYBIT, code) }

    # struct uinput_setup { struct input_id id; char name[80]; __u32 ff_effects_max; }
    # struct input_id { __u16 bustype, vendor, product, version; }
    name = "vimamsa-virtual-kbd"
    setup = [BUS_USB, 0x1234, 0x5678, 1].pack("S<4")          # input_id
    setup << name.ljust(80, "\x00")[0, 80]                     # name[80]
    setup << [0].pack("L<")                                    # ff_effects_max
    @fd.ioctl(UI_DEV_SETUP, setup)
    @fd.ioctl(UI_DEV_CREATE, 0)

    sleep 0.4 # let udev/libinput/the compositor enumerate the new device
    self
  end

  # struct input_event { struct timeval time; __u16 type, code; __s32 value; }
  # timeval = { __kernel_long_t tv_sec, tv_usec } -> 2 x 64-bit on x86_64.
  def emit(type, code, value)
    @fd.write([0, 0, type, code, value].pack("q<q<S<S<l<"))
  end

  def syn
    emit(EV_SYN, SYN_REPORT, 0)
  end

  def key(code, value)
    emit(EV_KEY, code, value)
    syn
  end

  def key_down(code) = key(code, 1)
  def key_up(code)   = key(code, 0)

  # Press and immediately release a key (a "tap").
  def tap(code, pause: 0.02)
    key_down(code)
    sleep pause
    key_up(code)
    sleep pause
  end

  # Hold `mods` (one code or an array, e.g. AltGr+Shift), tap `code` inside them,
  # release in reverse order (e.g. Shift-; or AltGr-q).
  def chord(mods, code, pause: 0.02)
    mods = Array(mods)
    mods.each { |m| key_down(m); sleep pause }
    key_down(code)
    sleep pause
    key_up(code)
    sleep pause
    mods.reverse_each { |m| key_up(m); sleep pause }
  end

  def close
    return unless @fd
    begin
      @fd.ioctl(UI_DEV_DESTROY, 0)
    rescue SystemCallError
      # device may already be gone
    end
    begin
      @fd.close
    rescue SystemCallError
      # closing /dev/uinput can report EINVAL on the final flush; harmless.
    end
    @fd = nil
  end
end

# Types characters through a VirtualKeyboard using the *active* keyboard layout,
# so shifted symbols like ":" and "!" land on the right physical key regardless
# of keymap. The layout is read from `xmodmap -pke` (keysym -> X keycode + shift
# level; evdev code = X keycode - 8). Character -> keysym name comes from
# Gdk::Keyval.to_name (for ASCII, keyval == codepoint).
#
# (Gdk::Display#map_keyval would be the native way, but Gdk::KeymapKey field
# readers segfault in the current ruby-gnome binding.)
class KeyTyper
  def self.available?
    system("which xmodmap > /dev/null 2>&1")
  end

  def initialize(vkb)
    @vkb = vkb
    @map = parse_xmodmap
  end

  # Type an ASCII string, e.g. type(":!ls")
  def type(str)
    str.each_char { |c| tap_keysym(Gdk::Keyval.to_name(c.ord)) }
  end

  # Tap a key by keysym name, e.g. tap_keysym("Return"), tap_keysym("Escape"),
  # tap_keysym("adiaeresis") (AltGr-q on an us(altgr-intl) layout).
  def tap_keysym(name)
    code, mods = @map[name]
    raise "no keycode found for keysym #{name.inspect}" if code.nil?
    if mods.empty?
      @vkb.tap(code)
    else
      @vkb.chord(mods, code)
    end
  end

  # True if this keyboard layout can produce `str` at all (all its characters
  # have a keycode). Lets a test skip cleanly on a layout that lacks e.g. "ä".
  def can_type?(str)
    str.each_char.all? { |c| @map.key?(Gdk::Keyval.to_name(c.ord)) }
  end

  private

  SHIFT = VirtualKeyboard::KEY_LEFTSHIFT
  ALTGR = VirtualKeyboard::KEY_RIGHTALT

  # Modifiers for each keysym column of a `xmodmap -pke` row. XKB maps a 4-level
  # layout into the core keymap as [g1l1, g1l2, g2l1, g2l2, g1l3, g1l4], so the
  # AltGr levels sit at 4/5 when a second group is present (the usual case: the
  # single configured layout is duplicated into group 2) and at 2/3 when not.
  COLUMN_MODS_6 = { 0 => [], 1 => [SHIFT], 4 => [ALTGR], 5 => [ALTGR, SHIFT] }.freeze
  COLUMN_MODS_4 = { 0 => [], 1 => [SHIFT], 2 => [ALTGR], 3 => [ALTGR, SHIFT] }.freeze

  # Parse lines like "keycode  47 = semicolon colon semicolon colon ..." into
  # { "semicolon" => [39, []], "colon" => [39, [SHIFT]] }. When a keysym appears
  # in several positions, the one needing the fewest modifiers wins.
  def parse_xmodmap
    map = {}
    `xmodmap -pke`.each_line do |line|
      m = line.match(/\Akeycode\s+(\d+) = (.*)$/) or next
      code = m[1].to_i - 8
      next if code <= 0
      syms = m[2].split
      cols = syms.length > 4 ? COLUMN_MODS_6 : COLUMN_MODS_4
      cols.each do |i, mods|
        sym = syms[i]
        next if sym.nil? || sym == "NoSymbol"
        map[sym] = [code, mods] if !map.key?(sym) || map[sym][1].length > mods.length
      end
    end
    map
  end
end

# Mixin for VmaTest subclasses that drive the editor with a real virtual
# keyboard: `with_vkb { |kb| … }` guards the preconditions, opens the uinput
# device, and closes it again.
module VkbTest
  # Guard preconditions, open/close the uinput device around the block.
  def with_vkb
    # uinput events go to the real seat's focused window. Only type when this
    # app is itself on the real Wayland session — never on a headless backend
    # (Broadway/Xvfb), where the keystrokes would land in some other program.
    # gtype.name: ruby-gnome has no named Ruby class for some backends.
    backend = Gdk::Display.default&.gtype&.name.to_s
    if !backend.include?("Wayland")
      skip "not on a real Wayland seat (#{backend})"
    end
    skip "no writable /dev/uinput" if !VirtualKeyboard.available?
    skip "xmodmap not available" if !KeyTyper.available?
    vkb = nil
    vma.gui.window.present
    # Wayland won't let a non-interactively launched window steal focus. In the
    # semi-interactive VM mode (VMA_E2E_INTERACTIVE), wait longer and prompt for a
    # single click; a real user click legitimately focuses the window, after which
    # every following test in the run finds it already active (no more clicks).
    focus_wait = ENV["VMA_E2E_INTERACTIVE"] ? 90 : 3
    if ENV["VMA_E2E_INTERACTIVE"] && !vma.gui.window.active?
      puts "\n>>> [E2E] Click the vimamsa window in the VM to give it focus " \
           "(waiting up to #{focus_wait}s)…"
      $stdout.flush
    end
    if !wait_until(focus_wait) { vma.gui.window.active? }
      skip "editor window is not focused; typing would go to another window"
    end
    vkb = VirtualKeyboard.new.open
    yield KeyTyper.new(vkb)
  ensure
    vkb&.close
  end

  # Poll cond while letting the GTK main loop process the incoming key events.
  def wait_until(timeout)
    t0 = Time.now
    loop do
      drain_idle
      return true if yield
      return false if Time.now - t0 > timeout
      sleep 0.05
    end
  end
end
