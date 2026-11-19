# Build environment for the Vimamsa AppImage (see doc/bundling_plan.md).
# Ubuntu 24.04: the bundle carries this GTK (4.14) and needs glibc >= 2.39.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git pkg-config wget ca-certificates file patchelf binutils \
      autoconf bison libssl-dev libyaml-dev zlib1g-dev libffi-dev libreadline-dev \
      libgdbm-dev libgmp-dev libatk1.0-dev \
      libgtk-4-dev libgtksourceview-5-dev libvte-2.91-gtk4-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgirepository1.0-dev \
      gir1.2-gtk-4.0 gir1.2-gtksource-5 gir1.2-vte-3.91 gir1.2-gstreamer-1.0 \
      gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
      adwaita-icon-theme hicolor-icon-theme librsvg2-common shared-mime-info \
      dconf-gsettings-backend libglib2.0-bin \
      xvfb xauth
# (apt lists kept: Ruby-GNOME gems apt-get a -dev package they find missing)
RUN git config --system --add safe.directory '*'
