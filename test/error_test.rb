# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'

# tests that all the errors that should be raised are raised
class ErrorTest < Minitest::Test
  class NoLeaf
    extend Gullah
  end

  def test_no_leaves
    assert_raises Gullah::Error, 'leaves required' do |e|
      NoLeaf.parse 'foo'
      assert_match(/no leaves/, e.message, 'expected no-leaf message')
    end
  end

  class UndefinedRules1
    extend Gullah

    rule :foo, 'bar'
  end

  def test_undefined_rules_1
    assert_raises Gullah::Error, 'some rules undefined' do |e|
      UndefinedRules1.parse 'bar'
      assert_match(/no leaves/, e.message, 'remain undefined')
    end
  end

  class UndefinedRules2
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
  end

  def test_undefined_rules_2
    assert_raises Gullah::Error, 'some rules undefined' do |e|
      UndefinedRules2.parse 'bar'
      assert_match(/no leaves/, e.message, 'remain undefined')
    end
  end

  class AddAfterParse1
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true
  end

  def test_add_after_parse_1
    assert_raises Gullah::Error, 'definition after parse' do |e|
      AddAfterParse1.parse 'bar baz'
      AddAfterParse1.rule :plugh, 'plugh'
      assert_match(/must be defined before parsing/, e.message, 'cannot define rule after parsing')
    end
  end

  class AddAfterParse2
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true
  end

  def test_add_after_parse_2
    assert_raises Gullah::Error, 'definition after parse' do |e|
      AddAfterParse2.parse 'bar baz'
      AddAfterParse2.leaf :plugh, /plugh/
      assert_match(/must be defined before parsing/, e.message, 'cannot define leaf after parsing')
    end
  end

  class UndefinedTest
    extend Gullah

    rule :foo, 'bar baz', tests: %i[undefined]
    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true
  end

  def test_undefined_test
    assert_raises Gullah::Error, 'undefined test' do |e|
      UndefinedTest.parse 'bar baz'
      assert_match(/is not defined/, e.message, 'must define tests')
    end
  end

  class BadTest
    extend Gullah

    rule :foo, 'bar baz', tests: %i[bad]
    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true

    def bad
      puts 'I have no arguments at all!'
    end
  end

  def test_zero_arity
    assert_raises Gullah::Error, 'arity 0' do |e|
      BadTest.parse 'bar baz'
      assert_match(/must take either 1 or two arguments/, e.message, 'needs one arg')
    end
  end

  class AlsoBadTest
    extend Gullah

    rule :foo, 'bar baz', tests: %i[bad]
    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true

    def bad(_root, _node, _other, _things)
      puts 'I have too many arguments!'
    end
  end

  def test_excessive_arity
    assert_raises Gullah::Error, 'arity many' do |e|
      AlsoBadTest.parse 'bar baz'
      assert_match(/must take either 1 or two arguments/, e.message, 'no more than 2 args')
    end
  end

  class MisnamedRule
    extend Gullah

    leaf :'bar@', /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true
  end

  def test_misnamed_rule
    assert_raises Gullah::Error, 'rule name' do |e|
      MisnamedRule.rule :foo, 'bar@ baz'
      assert_match(/cannot parse/, e.message, 'bad rule name')
    end
  end

  class BadSuffix
    extend Gullah

    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true
  end

  def test_bad_suffix_rule
    assert_raises Gullah::Error, 'rule suffix' do |e|
      MisnamedRule.rule :foo, 'bar{2,1} baz'
      assert_match(/is greater than/, e.message, 'bad suffix')
    end
  end

  class Decent
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true
  end

  def test_filters
    assert_raises Gullah::Error, 'unknown filter' do |e|
      Decent.parse 'bar baz', filters: %i[foo]
      assert_match(/unknown filter/, e.message, 'unknown filter')
    end
  end

  class BadTestReturnValue
    extend Gullah

    rule :foo, 'bar baz', tests: %i[foo]
    leaf :bar, /bar/
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true

    def foo(_n)
      :foo
    end
  end

  def test_test_return_value
    assert_raises Gullah::Error, 'bad test return value' do |e|
      BadTestReturnValue.parse 'bar baz'
      assert_match(/unexpected value/, e.message, 'tests return values')
    end
  end

  class BadAncestorTestReturnValue
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/, tests: %i[foo]
    leaf :baz, /baz/
    leaf :ws, /\s+/, ignorable: true

    def foo(_root, _n)
      :foo
    end
  end

  def test_ancestor_test_return_value
    assert_raises Gullah::Error, 'bad ancestor test return value' do |e|
      BadAncestorTestReturnValue.parse 'bar baz'
      assert_match(/unexpected value/, e.message, 'tests return values')
    end
  end
end
