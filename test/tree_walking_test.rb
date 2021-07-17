# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'

# test all the tree walking methods on node
class TreeWalkingTest < Minitest::Test
  class Binary
    extend Gullah

    rule :b, 'a{4} | b{4}'

    leaf :a, /\S+/
  end

  def test_basic
    parses = Binary.parse '1 2 3 4  5 6 7 8  9 10 11 12  13 14 15 16'
    assert_equal 1, parses.length, 'only one optimal parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'parse has a root node'
    root = parse.nodes.first
    nine = root.leaves.find { |l| l.text == '9' }
    assert !nine.nil?, 'found node number 9'
    assert_equal root, nine.root
    assert_equal 0, nine.sibling_index
    assert_nil nine.prior_sibling
    assert nine.first_child?
    ls = nine.later_sibling
    assert !ls.nil?
    assert_equal ' ', ls.text
    assert_equal [10, 11, 12], collect(nine.siblings).map(&:to_i)
    assert_equal [10, 11, 12], collect(nine.later_siblings).map(&:to_i)
    assert_equal (1..8).to_a, collect(nine.prior.select(&:leaf?)).map(&:to_i)
    assert_equal (10..16).to_a, collect(nine.later.select(&:leaf?)).map(&:to_i)
    assert_equal %i[b b], nine.prior.reject(&:leaf?).map(&:name)
    assert_equal %i[b], nine.later.reject(&:leaf?).map(&:name)
    assert_equal (9..12).to_a, collect(nine.parent.leaves).map(&:to_i)
    assert_equal (1..16).to_a, collect(root.leaves).map(&:to_i)
    ten = root.leaves.find { |l| l.text == '10' }
    assert !ten.nil?, 'found node number 10'
    assert !ten.first_child?
    assert_equal 2, ten.sibling_index
    assert_equal ' ', ten.prior_sibling.text
    assert_equal nine, ten.prior_sibling.prior_sibling
    assert_equal ' ', ten.later_sibling.text
    assert_equal '11', ten.later_sibling.later_sibling.text
    assert_equal [9, 11, 12], collect(ten.siblings).map(&:to_i)
    assert_equal [11, 12], collect(ten.later_siblings).map(&:to_i)
    assert_equal ten.parent, ten.ancestors.first
    assert_equal root, ten.ancestors.last
    assert_equal %i[b b], ten.ancestors.map(&:name)
    assert root.subtree.include?(root)
    assert !root.descendants.include?(root)
    [nine, ten].each do |n|
      assert root.subtree.include?(n)
      assert root.descendants.include?(n)
      assert n.ancestors.include?(root)
      assert !n.siblings.include?(n)
    end
    last_node = nil
    root.subtree.each do |n|
      last_node = n
      assert n.ancestors.include?(root) unless n == root
      assert !n.ancestors.include?(n)
      next if n.leaf?

      first, *, last = n.children
      assert first.first_child?
      if last
        assert last.last_child?
      else
        assert first.last_child?
      end
    end
    assert_equal root.leaves.last, root.subtree.last
    assert_equal last_node, root.subtree.last
  end

  private

  def collect(nodes)
    nodes.reject(&:ignorable?).map(&:text)
  end
end
