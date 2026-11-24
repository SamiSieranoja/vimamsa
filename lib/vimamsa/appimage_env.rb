module Vimamsa

# From the AppImage, AppRun points GI_TYPELIB_PATH, GIO_MODULE_DIR, GST_*, ...
# at the bundle and unsets GEM_HOME, RUBYOPT, ... (scripts/appimage/AppRun). It
# lists those names in VMA_APPIMAGE_ENV and keeps each one's previous value in
# VMA_HOST_<name>. GLib, GIO, GObject Introspection and GStreamer read them once
# and keep what they read, so after startup the host's values go back into ENV.
# Programs the editor starts (git, a terminal, the user's own Ruby or Python
# GTK programs) then get the user's environment, not the bundle's typelibs,
# modules and gem settings. PATH keeps the bundle's ruby-lsp/rufo wrappers.
def restore_host_env
  names = ENV["VMA_APPIMAGE_ENV"]
  return if names.nil?
  # Read on first use, so use them before the bundle paths go away
  GdkPixbuf::Pixbuf.formats if defined?(GdkPixbuf::Pixbuf)
  Gio::SettingsSchemaSource.default
  Gio::Vfs.default
  # GStreamer may only be loaded later (the audio and dictation modules), but
  # finds the bundled plugins only through GST_* (the plugin registry is
  # cached in ~/.cache/vimamsa, so this is quick after the first start)
  require "gstreamer"
  Gst.init if Gst.respond_to?(:init)
  names.split.each { |n|
    host = "VMA_HOST_#{n}"
    if ENV.key?(host)
      ENV[n] = ENV.delete(host)
    else
      ENV.delete(n)
    end
  }
  ENV.delete("VMA_APPIMAGE_ENV")
  debug "Restored the host environment for child processes: #{names}"
end

# The command that starts another editor (restart_editor, tests that start
# one): from the AppImage its AppRun, which sets up the bundle's environment
# again (the editor has put the host's back, see restore_host_env, and the
# bundled ruby alone doesn't find the typelibs then). AppRun runs the image's
# vimamsa, or $VMA_SOURCE's exe/vimamsa when that is set (still set here).
# Otherwise the ruby running this editor with script.
def vma_editor_command(script = File.expand_path("../../exe/vimamsa", __dir__))
  apprun = ENV["APPDIR"] && File.join(ENV["APPDIR"], "AppRun")
  return [apprun] if apprun && File.executable?(apprun)
  [RbConfig.ruby, script]
end

end # module Vimamsa
