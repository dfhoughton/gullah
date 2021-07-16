# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'

class BasicTest < Minitest::Test
  class Simple
    extend Gullah

    rule :a, 'a+'

    leaf :a, /\S+/
  end

  def test_basic
    # byebug
    parses = Simple.parse 'foo bar baz'
    assert_equal 1, parses.length, 'only one optimal parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'parse has a root node'
    root = parse.nodes.first
    assert_equal :a, root.name, 'root node has the right label'
    assert_equal 6, root.subtree.count, 'parse has the expected number of nodes'
    assert_equal 4, root.subtree.count(&:significant?),
                 'parse has the expected balance of significant and ignorable nodes'
  end

  class FixedCount
    extend Gullah

    rule :a, 'a{2}'

    leaf :a, /\S+/
  end

  def test_fixed_count
    parses = FixedCount.parse 'foo bar baz'
    assert_equal 2, parses.length, '2 optimal parses'
    parses.each do |p|
      assert_equal 1, p.nodes.length, 'parse has a root node'
      root = p.nodes.first
      assert_equal 2, root.subtree.select(&:nonterminal?).count, 'parse has 2 nonterminal nodes'
      assert root.subtree.select(&:nonterminal?).each do |_n|
        assert_equal 2, b.children.length, 'nonterminal nodes each have 2 children'
      end
    end
  end

  class Balanced
    extend Gullah

    rule :a, 'a{2}', tests: %i[balanced]

    leaf :a, /\S+/

    # we only want a perfectly symmetrical tree
    def balanced(n)
      if n.children.first.size == n.children.last.size
        :pass
      else
        :fail
      end
    end
  end

  def test_test
    parses = Balanced.parse 'foo bar baz plugh'
    assert_equal 1, parses.length, '1 optimal parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'parse has a root node'
  end

  class Trash
    extend Gullah

    keep_whitespace

    leaf :word, /\w+/
    leaf :ws, /\s+/, ignorable: true
  end

  def test_trash
    parses = Trash.parse 'There may be punctuation.'
    assert_equal 1, parses.length, 'only one parse'
    parse = parses.first
    assert_equal 8, parse.nodes.length, 'there are 8 nodes in the parse'
    assert parse.nodes.all?(&:leaf), 'all nodes are leaf nodes'
    assert_equal 3, parse.nodes.select { |n| n.name == :ws }.count, 'there are 3 whitespace nodes'
    assert_equal 4, parse.nodes.select(&:ignorable?).count, 'there are 4 ignorable nodes'
    assert_equal 4, parse.nodes.select { |n| n.name == :word }.count, 'there are 4 word nodes'
    assert_equal 1, parse.nodes.select(&:trash?).count, 'there is 1 trash node'
    assert parse.nodes.last.trash?, 'the last node is the trash node'
  end

  # TODO: order dependence problem
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

    leaf :determiners, /\b(the|a)\b/i
    leaf :nouns, /\b(cat|mat)\b/i
    leaf :prepositions, /\b(on|in|around|above|beside)\b/i
    leaf :verbs, /\b(sat|slept|moped)\b/
    leaf :adjectives, /\b(big|small|hairy|bald)\b/i
    leaf :whatever, /[^\w\s]+/, ignorable: true
  end

  def test_cat
    parses = Cat.parse 'The cat sat on the mat.'
    assert_equal 1, parses.length, 'there is only one parse of this sentence'
    parse = parses.first
    assert_equal 1, parse.nodes.reject(&:ignorable?).count, 'there is a root node for this parse'
    root = parse.nodes.first
    assert_equal :S, root.name, 'the root node is a sentence'
    vp = root.descendants.find { |d| d.name == :VP }&.descendants&.find { |d| d.name == :V }
    assert_equal 'sat', vp&.text, 'we have the expected verb'
  end

  class SubRules
    extend Gullah

    rule :s, 'thing+'
    rule :thing, 'word | integer'

    leaf :word, /[a-z]+/i
    leaf :integer, /\d+/
  end

  def test_subrules
    parses = SubRules.parse '123 word'
    assert_equal 1, parses.length, 'there is only one parse of this sentence'
    parse = parses.first
    assert_equal 1, parse.nodes.reject(&:ignorable?).count, 'there is a root node for this parse'
    root = parse.nodes.first
    assert_equal :s, root.name, 'found expected root'
    assert_equal 2, root.subtree.select { |n| n.name == :thing }.count, 'two things'
    assert_equal 1, root.subtree.select { |n| n.name == :word }.count, 'one word'
    assert_equal 1, root.subtree.select { |n| n.name == :integer }.count, 'one integer'
  end

  class SubRulesWithTest
    extend Gullah

    rule :s, 'thing+'
    rule :thing, 'word | integer', tests: %i[foo]

    leaf :word, /[a-z]+/i
    leaf :integer, /\d+/

    def foo(_n)
      :pass
    end
  end

  def test_subrules_with_test
    parses = SubRulesWithTest.parse '123 word'
    assert_equal 1, parses.length, 'there is only one parse of this sentence'
    parse = parses.first
    assert_equal 1, parse.nodes.reject(&:ignorable?).count, 'there is a root node for this parse'
    root = parse.nodes.first
    assert_equal :s, root.name, 'found expected root'
    assert_equal 2, root.subtree.select { |n| n.name == :thing }.count, 'two things'
    assert_equal 1, root.subtree.select { |n| n.name == :word }.count, 'one word'
    assert_equal 1, root.subtree.select { |n| n.name == :integer }.count, 'one integer'
  end

  class SubRulesWithAncestorTest
    extend Gullah

    rule :s, 'thing+'
    rule :thing, 'word | integer', tests: %i[foo]

    leaf :word, /[a-z]+/i
    leaf :integer, /\d+/

    def foo(_root, _n)
      :pass
    end
  end

  def test_subrules_with_ancestor_test
    parses = SubRulesWithAncestorTest.parse '123 word'
    assert_equal 1, parses.length, 'there is only one parse of this sentence'
    parse = parses.first
    assert_equal 1, parse.nodes.reject(&:ignorable?).count, 'there is a root node for this parse'
    root = parse.nodes.first
    assert_equal :s, root.name, 'found expected root'
    assert_equal 2, root.subtree.select { |n| n.name == :thing }.count, 'two things'
    assert_equal 1, root.subtree.select { |n| n.name == :word }.count, 'one word'
    assert_equal 1, root.subtree.select { |n| n.name == :integer }.count, 'one integer'
  end

  class LeftAncestor
    extend Gullah

    rule :s, 'word+'
    rule :word, 'foo | bar'

    leaf :foo, /foo/, tests: %i[preceded_by_bar]
    leaf :bar, /bar/

    def preceded_by_bar(root, n)
      if n.prior.any? { |other| other.name == :bar }
        :pass
      elsif root.name == :s
        :fail
      end
    end
  end

  def test_left_ancestor
    parses = LeftAncestor.parse 'bar foo'
    assert_equal 1, parses.length, 'one parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'one root for parse'
    root = parse.nodes.first
    assert_equal 1, root.subtree.count { |n| n.name == :foo }, 'one foo'
  end

  class RightAncestor
    extend Gullah

    rule :s, 'word+'
    rule :word, 'foo | bar'

    leaf :foo, /foo/, tests: %i[followed_by_bar]
    leaf :bar, /bar/

    def followed_by_bar(root, n)
      if n.later.any? { |other| other.name == :bar }
        :pass
      elsif root.name == :s
        :fail
      end
    end
  end

  def test_right_ancestor
    parses = RightAncestor.parse 'bar foo'
    assert_equal 1, parses.length, 'one parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'one root for parse'
    root = parse.nodes.first
    assert_equal 0, root.subtree.reject(&:failed_test).count { |n| n.name == :foo }, 'no foos'
  end

  class LowerLimit
    extend Gullah

    rule :s, 'a{2,}'
    leaf :a, /a/
  end

  def test_lower_limit
    parses = LowerLimit.parse 'a'
    assert_equal 0, parses.select(&:success?).length, 'we need at least one'
    parses = LowerLimit.parse 'a a'
    assert_equal 1, parses.length, 'two is enough'
    parses = LowerLimit.parse 'a a a'
    assert_equal 1, parses.length, 'more than two is fine'
  end

  class TwoLimits
    extend Gullah

    rule :s, 'a{2,3}'
    leaf :a, /a/
  end

  def test_two_limits
    parses = LowerLimit.parse 'a'
    assert_equal 0, parses.select(&:success?).length, 'we need at least one'
    parses = LowerLimit.parse 'a a'
    assert_equal 1, parses.length, 'two is enough'
    parses = LowerLimit.parse 'a a a'
    assert_equal 1, parses.length, 'three is also good'
    parses = LowerLimit.parse 'a a a a'
    assert_equal 1, parses.length, 'four is too many'
  end

  class HoweverMany
    extend Gullah

    rule :s, 'b a*'
    leaf :a, /a/
    leaf :b, /b/
  end

  def test_however_many
    parses = HoweverMany.parse 'b'
    assert_equal 1, parses.length, "we don't even need one"
    parses = HoweverMany.parse 'b a'
    assert_equal 1, parses.length, 'but we can take one'
    parses = HoweverMany.parse 'b a a'
    assert_equal 1, parses.length, 'and we can take moer than one'
  end

  class OneOrNone
    extend Gullah

    rule :s, 'b a?'
    leaf :a, /a/
    leaf :b, /b/
  end

  def test_one_or_none
    parses = OneOrNone.parse 'b'
    assert_equal 1, parses.length, "we don't even need one"
    parses = OneOrNone.parse 'b a'
    assert_equal 1, parses.length, 'but we can take one'
    parses = OneOrNone.parse 'b a a'
    assert_equal 0, parses.select(&:success?).length, "and we can't take more than one"
  end

  class Literal
    extend Gullah

    rule :money, '"$" digits'
    leaf :digits, /\d+/
  end

  def test_literal
    parses = Literal.parse '$12'
    assert_equal 1, parses.length, 'it parses'
    parse = parses.first
    assert_equal 1, parse.length, "there's a root node"
    root = parse.nodes.first
    assert_equal 2, root.leaves.count, 'there are two leaves'
    assert_equal '$', root.leaves.first.text, "the first leaf is '$'"
    assert_equal '12', root.leaves.last.text, "the last leaf is '12'"
  end

  # TODO
  # attribute stashing
  # returning extras from tests
  # ambiguous lexical rules -- run/run, bill/bill
  # filters
end
