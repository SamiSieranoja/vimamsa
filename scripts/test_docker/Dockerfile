# Test image for run_tests_docker.rb: the test VM's packages and gems on
# Ubuntu 24.04, for running the tests that don't need a real desktop on an
# invisible display (xvfb). The source is not in the image: each run unpacks
# the working tree's (scripts/lib/source_pack.rb) into the container.
#
# gems.txt (written by run_tests_docker.rb from vimamsa.gemspec): one
# "name requirement" per line. The image tag is a hash of this file and
# gems.txt, so it is rebuilt when either changes.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
      ruby ruby-dev build-essential git pkg-config ca-certificates \
      libgtk-4-dev libgtksourceview-5-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      libvte-2.91-gtk4-dev libssl-dev \
      ack clang-format x11-xserver-utils vim xvfb xauth \
      fonts-dejavu-core dbus-x11 \
      libgirepository1.0-dev gir1.2-gtk-4.0 gir1.2-gtksource-5 gir1.2-vte-3.91 \
      gir1.2-gstreamer-1.0 gir1.2-gst-plugins-base-1.0 gir1.2-pango-1.0 \
      gir1.2-gdkpixbuf-2.0 gir1.2-graphene-1.0 gir1.2-harfbuzz-0.0 gir1.2-atk-1.0

# The ruby-gnome gems install the system packages they still miss with apt
# (as in the VM), so the apt lists stay until they are done
COPY gems.txt /tmp/gems.txt
RUN while read -r name req; do \
      gem install --no-document "$name" -v "$req" || exit 1; \
    done < /tmp/gems.txt \
    && rm -rf /var/lib/apt/lists/*

# Tools the tests use. In a layer of their own after the gems, so adding one
# doesn't recompile the gems.
RUN apt-get update && apt-get install -y --no-install-recommends \
      file shared-mime-info xdg-utils clangd \
    && rm -rf /var/lib/apt/lists/* \
    && gem install --no-document syntax_tree

# Tests run as a normal user (some check file permissions), with the host
# user's uid so files in the shared cache mount are writable by both
ARG UID=1000
RUN userdel -r ubuntu 2>/dev/null; useradd -m -s /bin/bash -u "$UID" vma
USER vma
WORKDIR /home/vma
