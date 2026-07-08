# frozen_string_literal: true

# Install the fonts bundled under ./fonts (Oxanium, used by the cyberpunk-glow
# GUI theme) into the user font dir so fontconfig/Pango can resolve them by
# family name. Ported from the rterm terminal project's BundledFonts. Copies
# are skipped when the destination is already identical, so it is cheap to run
# on every startup and needs no fc-cache call (fontconfig scans the dir).

require "fileutils"

module Vimamsa
  module BundledFonts
    module_function

    def setup!
      bundled_dir = File.expand_path("../../fonts", __dir__)
      return unless Dir.exist?(bundled_dir)

      target_dir = File.expand_path("~/.local/share/fonts/vimamsa")
      FileUtils.mkdir_p(target_dir)

      Dir.glob(File.join(bundled_dir, "*.{ttf,otf,ttc,otc}")).each do |src|
        dest = File.join(target_dir, File.basename(src))
        next if File.exist?(dest) && FileUtils.identical?(src, dest)

        FileUtils.cp(src, dest)
      end
    rescue => ex
      warn "BundledFonts.setup! failed: #{ex}"
    end
  end
end
