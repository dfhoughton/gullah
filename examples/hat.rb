# frozen_string_literal: true

require 'gullah'

class Englishish
  extend Gullah

  rule :NP,         'NP PP'
  rule :NP,         'D N'
  rule :NP,         'Proper'
  rule :D,          'the | Possessive'
  rule :PP,         'prep NP'
  rule :Possessive, 'NP pe'

  leaf :the,    /\bthe\b/i
  leaf :pe,     /(?<=[a-rt-z])'s|(?<=s)'/i
  leaf :Proper, /\bE(?i)ngland\b/
  leaf :N,      /\b(?:queen|hat)\b/i
  leaf :prep,   /\bof\b/i
end

Englishish.parse("the queen of England's hat").each_with_index do |parse, i|
  puts parse.summary
  Gullah::Dotifier.dot parse, "hat#{i}", make_it: :so
end
