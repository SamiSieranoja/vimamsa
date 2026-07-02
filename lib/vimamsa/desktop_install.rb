require "fileutils"

module Vimamsa

# Application id used both for the GTK application (see gui.rb) and as the
# StartupWMClass / desktop-file basename so desktop environments can match the
# running window to its launcher entry and icon.
VMA_APP_ID = "net.samiddhi.vimamsa"

# Install a desktop launcher entry + application icon into the user's data dir
# (~/.local/share). Runs on every startup but only writes when the installed
# copy is missing or differs from the bundled source, so a new logo / changed
# .desktop shipped by a gem upgrade is picked up automatically, while the common
# unchanged case does nothing (and never spawns the cache-refresh processes).
# Best-effort — any failure is logged and swallowed so it can never block startup.
def install_desktop_integration
  icon_src = ppath("icon.png")
  unless File.exist?(icon_src)
    debug "Desktop install: icon source not found at #{icon_src}"
    return
  end

  data_home = ENV["XDG_DATA_HOME"]
  data_home = File.expand_path("~/.local/share") if data_home.nil? || data_home.empty?

  icon_dir = File.join(data_home, "icons", "hicolor", "256x256", "apps")
  icon_dst = File.join(icon_dir, "vimamsa.png")
  apps_dir = File.join(data_home, "applications")
  desktop_dst = File.join(apps_dir, "#{VMA_APP_ID}.desktop")

  installed_something = false

  # Re-copy the icon whenever the bundled source differs (e.g. a new logo after
  # a gem upgrade). FileUtils.identical? compares contents, not just mtime.
  if !File.exist?(icon_dst) || !FileUtils.identical?(icon_src, icon_dst)
    FileUtils.mkdir_p(icon_dir)
    FileUtils.cp(icon_src, icon_dst)
    installed_something = true
    debug "Desktop install: copied icon to #{icon_dst}"
  end

  # The .desktop file is app-generated metadata; rewrite it when our generated
  # content changes (new fields / version). This is not a user-customization file.
  desktop_txt = desktop_entry_contents
  if !File.exist?(desktop_dst) || File.read(desktop_dst) != desktop_txt
    FileUtils.mkdir_p(apps_dir)
    File.write(desktop_dst, desktop_txt)
    installed_something = true
    debug "Desktop install: wrote #{desktop_dst}"
  end

  refresh_desktop_caches(File.join(data_home, "icons", "hicolor"), apps_dir) if installed_something
rescue => e
  # Never let desktop integration break startup.
  debug "Desktop install failed: #{e.class}: #{e.message}"
end

def desktop_entry_contents
  <<~DESKTOP
    [Desktop Entry]
    Type=Application
    Name=Vimamsa
    Comment=Vi/Vim-inspired GUI text editor
    Exec=vimamsa %F
    Icon=vimamsa
    Terminal=false
    Categories=Utility;TextEditor;
    StartupWMClass=#{VMA_APP_ID}
  DESKTOP
end

def refresh_desktop_caches(icon_theme_dir, apps_dir)
  if which("gtk-update-icon-cache")
    system("gtk-update-icon-cache", "-q", "-t", "-f", icon_theme_dir,
           out: File::NULL, err: File::NULL)
  end
  if which("update-desktop-database")
    system("update-desktop-database", apps_dir,
           out: File::NULL, err: File::NULL)
  end
end

end # module Vimamsa
