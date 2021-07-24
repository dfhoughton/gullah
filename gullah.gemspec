# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gullah/version'

Gem::Specification.new do |s|
  s.name        = 'gullah'
  s.version     = Gullah::VERSION
  s.summary     = 'A bottom up parser generator'
  s.description = <<-DESC.strip.gsub(/\s+/, ' ')
    Gullah is a bottom-up parser generator than can
    handle errors, ambiguous syntax, and arbitrary matching
    conditions.
  DESC
  s.authors     = ['David F. Houghton']
  s.email       = 'dfhoughton@gmail.com'
  s.homepage    =
    'https://rubygems.org/gems/gullah'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.3'
  s.files                 = `git ls-files -z`.split("\x0")
  s.test_files            = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths         = ['lib']

  s.add_development_dependency 'bundler', '~> 1.7'
  s.add_development_dependency 'byebug', '~> 9.1.0'
  s.add_development_dependency 'json', '~> 2'
  s.add_development_dependency 'minitest', '~> 5'
  s.add_development_dependency 'rake', '~> 10.0'
end
