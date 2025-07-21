
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "vimamsa/version"

Gem::Specification.new do |spec|
  spec.name          = "vimamsa"
  spec.version       = Vimamsa::VERSION # in lib/vimamsa/version.rb
  spec.authors       = ["Sami Sieranoja"]
  spec.email         = ["sami.sieranoja@gmail.com"]

  spec.summary       = %q{Vimamsa}
  spec.description   = %q{Vi/Vim -inspired experimental GUI-oriented text editor written with Ruby and GTK.}
  spec.homepage = "https://github.com/SamiSieranoja/vimamsa"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(refcode|spec|features)/})
  end
  # spec.files         = Dir["{ext}/**/*"]

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib","ext"]

  spec.add_development_dependency "bundler", "~> 2.4.21"
  spec.add_development_dependency "rake", "~> 13.1.0"
  
  spec.add_runtime_dependency 'rufo', '~> 0.16.2'
  
  spec.add_runtime_dependency 'ripl', '~> 0.7.1'
  spec.add_runtime_dependency 'ripl-multi_line', '~> 0.3.1'
  spec.add_runtime_dependency 'gdk4', '~> 4.2.1'
  spec.add_runtime_dependency 'gtk4', '~> 4.2.1'
  spec.add_runtime_dependency 'gtksourceview5', '~> 4.2.1'
  spec.add_runtime_dependency 'gstreamer', '~> 4.2.1'
  spec.add_runtime_dependency 'rambling-trie', '~> 2.3.1'
  
  spec.add_runtime_dependency 'differ', '~>  0.1.2'
  spec.add_runtime_dependency 'parallel', '~> 1.14' #TODO: update?
  spec.add_runtime_dependency 'listen', '~> 3.4'  #TODO: update?
  spec.add_runtime_dependency 'StrIdx', '~> 0.1.1'
  spec.add_runtime_dependency 'language_server-protocol', '~> 3.17.0.3'

  spec.extensions = ["ext/vmaext/extconf.rb"]
  spec.licenses    = ['GPL-3.0+']
end
