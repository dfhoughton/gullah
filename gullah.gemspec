# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'gullah'
  s.version     = '0.0.0'
  s.summary     = 'A bottom up parser generator'
  s.description = 'A bottom-up parser generator than can handle errors and ambiguous syntax'
  s.authors     = ['David F. Houghton']
  s.email       = 'dfhoughton@gmail.com'
  s.files       = ['lib/gullah.rb', 'lib/gullah/node.rb']
  s.homepage    =
    'https://rubygems.org/gems/gullah'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.7'
end
