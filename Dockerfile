# Vimamsa test container
#
# Runs the full test suite headlessly via xvfb.
#
# Build:  docker build -t vimamsa-test .
# Run:    docker run --rm vimamsa-test
#
# Ruby version matches development environment (see Makefile in project root).

FROM ruby:3.1-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ruby-dev \
    git \
    pkg-config \
    libgtk-4-dev \
    libgtksourceview-5-dev \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libvte-2.91-gtk4-dev \
    xvfb \
    xauth \
    libssl-dev

WORKDIR /app

# COPY .git/ .git/
# COPY vimamsa.gemspec Gemfile ./
# COPY lib/vimamsa/version.rb lib/vimamsa/
# COPY ext/vmaext/ ext/vmaext/

RUN gem install bundler -v '~> 2.4'

RUN echo "alias ll='ls -ltrh'" >> ~/.bashrc
ARG CACHE_BUST=1
RUN git  clone https://github.com/SamiSieranoja/vimamsa.git && cd vimamsa && gem build vimamsa.gemspec  && gem install vimamsa-0.1.*.gem
RUN cp /usr/local/bundle/gems/vimamsa-0.1.23/ext/vmaext/vmaext.so vimamsa/lib/ 

WORKDIR /app/vimamsa
CMD ["bash", "-c", "xvfb-run -a ruby run_tests.rb 2>&1"]


