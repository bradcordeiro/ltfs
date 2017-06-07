# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ltfs_gem/version'

Gem::Specification.new do |s|
  s.name          = "ltfs"
  s.version       = "0.1"
  s.authors       = ["Brad Cordeiro"]
  s.email         = ["me@bradc.com"]

  s.summary       = "Parser for LTFS index schema files"
  s.homepage      = "https://github.com/bradcordeiro/ltfs"
  s.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = 'http://rubygems.org'
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  s.files         = ["lib/ltfs.rb"]

  s.add_dependency "xml-simple"

  s.add_development_dependency "bundler", "~> 1.12"
  s.add_development_dependency "rake", "~> 10.0"
end
