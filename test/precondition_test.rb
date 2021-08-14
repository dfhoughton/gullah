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
    def balanced(_name, _start, _end, _text, children)
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

  class LeafPrecondition
    extend Gullah

    rule :phrase, 'word+'

    leaf :word, /\S+/, preconditions: [:not_foo]

    def not_foo(_name, s, e, text, _children)
      text[s...e] == 'foo' ? :fail : :pass
    end
  end

  def test_good_words
    parse = LeafPrecondition.first 'bar baz plugh'
    assert_equal 'phrase[word,_ws,word,_ws,word]', parse.summary
  end

  def test_bad_first
    parse = LeafPrecondition.first 'foo bar baz plugh'
    assert_equal ';_ws;phrase[word,_ws,word,_ws,word]', parse.summary
  end

  def test_bad_middle
    parse = LeafPrecondition.first 'bar foo baz plugh'
    assert_equal 'phrase[word,_ws];;_ws;phrase[word,_ws,word]', parse.summary
  end

  def test_bad_end
    parse = LeafPrecondition.first 'bar baz plugh foo'
    assert_equal 'phrase[word,_ws,word,_ws,word,_ws];', parse.summary
  end
end
