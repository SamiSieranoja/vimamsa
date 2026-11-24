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

end # module Vimamsa
