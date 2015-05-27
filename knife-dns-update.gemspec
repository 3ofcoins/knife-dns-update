# -*- mode: ruby; coding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knife-dns-update/version'

Gem::Specification.new do |spec|
  spec.name          = "knife-dns-update"
  spec.version       = KnifeDnsUpdate::VERSION
  spec.authors       = ["Maciej Pasternacki"]
  spec.email         = ["maciej@pasternacki.net"]
  spec.description   = "Updates DNS based on Chef database"
  spec.summary       = "Updates Route 53 DNS entries based on Chef database contents"
  spec.homepage      = "https://github.com/3ofcoins/knife-dns-update/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "chef"
  spec.add_dependency "fog", "~> 1.9"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency "rake", "~> 10.4"
  spec.add_development_dependency "wrong", ">= 0.7.0"
end
