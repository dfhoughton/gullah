# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'
require 'date'

# :stopdoc:

# a test to make sure boundary rules work
class BoundaryTest < Minitest::Test
  class Bounded
    extend Gullah

    rule :S, 'word+'

    leaf :word, /\w+/
    boundary :term, /[.!?](?=\s*\z|\s+"?\p{Lu})|[:;]/
  end

  def test_example
    parses = Bounded.parse 'One sentence. Another sentence.'
    assert_equal 1, parses.length, 'Got one parse.'
    parse = parses.first
    puts parse.summary
    Gullah::Dotifier.dot parse, "boundaries", make_it: :so
    assert_equal 5, parse.length, 'One node per sentence plus one per boundary plus one space.'
    assert_equal 2, parse.nodes.count(&:boundary?), 'There are two boundary nodes.'
  end
end
