# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'syncnstore/version'

s = Gem::Specification.new

s.name          = "syncnstore"
s.version       = Syncnstore::VERSION
s.authors       = ["Ruben Jenster"]
s.email         = ["r.jenster@drachenfels.de"]
s.description   = %q{TODO: Write a gem description}
s.summary       = %q{TODO: Write a gem summary}
s.homepage      = "http://github.com/Drachenfels-GmbH/Thor::Sandbox::Gem::Base"

s.files         = `git ls-files`.split($/)
s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
s.test_files    = s.files.grep(%r{^(test|spec|features)/})
s.require_paths = ["lib"]
s.add_dependency "thor"
s.add_development_dependency "rake"

s.add_development_dependency "simplecov"
s.add_development_dependency "simplecov-rcov"

s

