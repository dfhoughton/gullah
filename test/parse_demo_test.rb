# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'
require 'date'

# :stopdoc:

# a test to make sure the demo code for the parse class is telling the truth
class ParseDemoTest < Minitest::Test
  class Example
    extend Gullah

    rule :S, 'NP VP'
    rule :NP, 'D N'
    rule :VP, 'V'

    leaf :D, /the/
    leaf :N, /cat/
    leaf :V, /sat/
  end

  def test_example
    parses = Example.parse 'the cat sat', n: 1

    parse = parses.first
    assert_equal 1, parse.length
    assert_equal 8, parse.size
    assert_equal 'S[NP[D,_ws,N],_ws,VP[V]]', parse.summary
  end

  class Cat
    extend Gullah

    rule :S, 'NP VP'
    rule :NP, 'D NB'
    rule :NB, 'A* N'
    rule :VP, 'VP PP'
    rule :VP, 'V'
    rule :PP, 'P NP'
    rule :P, 'prepositions'
    rule :V, 'verbs'
    rule :D, 'determiners'
    rule :N, 'nouns'
    rule :A, 'adjectives'

    leaf :determiners, /\b(the|an?)\b/i
    leaf :nouns, /\b(cat|mat)\b/i
    leaf :prepositions, /\b(on|in|around|above|beside)\b/i
    leaf :verbs, /\b(sat|slept|moped)\b/
    leaf :adjectives, /\b(big|small|hairy|bald|fat)\b/i

    ignore :whatever, /[^\w\s]+/
  end

  def test_cat
    parses = Cat.parse 'The fat cat sat on the mat.'
    assert_equal 1, parses.length, 'there is only one parse of this sentence'
    parse = parses.first
    assert_equal 1, parse.roots.reject(&:ignorable?).length, 'there is a root node for this parse'
    root = parse.roots.reject(&:ignorable?).first
    assert_equal :S, root.name, 'the root node is a sentence'
    verb = root.descendants.find { |d| d.name == :VP }&.descendants&.find { |d| d.name == :V }
    assert_equal 'sat', verb&.text, 'we have the expected verb'
  end
end
