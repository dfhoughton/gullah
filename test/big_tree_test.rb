# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'

# :stopdoc:

# to verify that we can make one parse quickly even for a big tree
class BigTreeTest < Minitest::Test
  class Binary
    extend Gullah

    rule :a, 'a{2}'

    leaf :a, /\S+/
  end

  def test_this
    parses = Binary.parse '1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16', n: 1
    assert_equal 1, parses.length, 'got one parse'
    parse = parses.first
    assert_equal 1, parse.roots.length, 'the parse has a root'
    root = parse.roots.first
    assert_equal 31, root.subtree.reject(&:ignorable?).count, 'the tree has the expected number of nodes'
  end
end
