# frozen_string_literal: true

require 'gullah'

# some random rules to experiment with and where
# it's easy to make trash -- !@#$%@#$ is trash, for instance
class Sanitation
  extend Gullah

  rule :ping, 'foo bar | bar foo'
  rule :pang, 'bar baz+ | plugh'
  rule :pong, 'foo{2,} | bar{2,} | baz{2,} | plugh{2,}'
  rule :peng, 'ping | pang | pong'
  rule :pung, 'peng+'

  leaf :foo,   /\b\w\b/
  leaf :bar,   /\b\w{2}\b/
  leaf :baz,   /\b\w{3}\b/
  leaf :plugh, /\b\w{4,}\b/

  boundary :stop, /[.!?;:]/
end

text = <<-PROFUNDITY
  A Riddle (somewhat German)

  The beginning of Eternity.
  The end of Time and Space.
  The beginning of every End.
  The end of every Place.

  There once was a girl who had a little curl
    Right in the middle of her forehead.
  And when she was good, she was very, very good
    But when she was bad she was horrid!
PROFUNDITY

poetry = Sanitation.first text
puts poetry.summary
Gullah::Dotifier.dot poetry, 'poem', make_it: :so
