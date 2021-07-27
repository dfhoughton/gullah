# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'

# :stopdoc:

class PreconditionTest < Minitest::Test
  class Balanced
    extend Gullah

    rule :a, 'a{2}', preconditions: %i[balanced]

    leaf :a, /\S+/

    # we only want a perfectly symmetrical tree
    def balanced(_name, children)
      left, *, right = children
      left.size == right.size
    end
  end

  def test_test
    parses = Balanced.parse 'foo bar baz plugh'
    assert_equal 1, parses.length, '1 optimal parse'
    parse = parses.first
    assert_equal 1, parse.roots.length, 'parse has a root node'
    root = parse.roots.first
    assertion = root.subtree
                    .select(&:nonterminal?)
                    .all? { |n| n.children.first.size == n.children.last.size }
    assert assertion, 'the nodes are all balanced'
  end
end
