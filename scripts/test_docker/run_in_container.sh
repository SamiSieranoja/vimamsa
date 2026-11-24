#!/bin/bash
# Runs INSIDE a test container (run_tests_docker.rb): unpacks the source,
# takes the native extension from the shared cache (building it there first
# if it isn't), and runs the given test files on an invisible display.
#   /in/src.tgz   the packed working tree (read-only mount)
#   /cache        shared between containers: vmaext-<key>.so
#   VMA_TEST_ARGS test files and filters for exe/run_tests.rb
#   VMA_BUILD_ONLY=1  only build the extension into the cache
set -euo pipefail

mkdir -p "$HOME/vimamsa"
cd "$HOME/vimamsa"
tar xzf /in/src.tgz --warning=no-timestamp

# The extension, keyed by its tracked sources and the Ruby version
key="$( (ruby -v; git ls-files -z ext/vmaext | sort -z | xargs -0 cat) | sha256sum | cut -c1-16)"
so="/cache/vmaext-$key.so"
if [ ! -f "$so" ]; then
  echo ">> Building the native extension ($key)"
  # From the tracked files only, as gem build does (ext/vmaext may hold
  # untracked work files, e.g. a vmaext.cpp next to vmaext.c)
  b="$(mktemp -d)"
  git ls-files -z ext/vmaext | xargs -0 cp -t "$b"
  (cd "$b" && ruby extconf.rb >/dev/null && make -s >/dev/null)
  cp "$b/vmaext.so" "$so.tmp.$$" && mv "$so.tmp.$$" "$so"
fi
cp "$so" lib/vmaext.so
[ "${VMA_BUILD_ONLY:-}" = 1 ] && exit 0

# The host's lockfile pins versions the image may not have: resolve against
# the image's gems (the ruby-lsp tests run `bundle exec ruby-lsp`)
rm -f Gemfile.lock

set +e
# shellcheck disable=SC2086  # word-splitting of VMA_TEST_ARGS is intentional
ruby exe/run_tests.rb --headless ${VMA_TEST_ARGS:-}
rc=$?
echo "VMA_SUITE_EXIT=$rc"
exit $rc
