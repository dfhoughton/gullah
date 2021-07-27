# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'

# :stopdoc:

# tests that all the errors that should be raised are raised
class ErrorTest < Minitest::Test
  class NoLeaf
    extend Gullah
  end

  def test_no_leaves
    e = assert_raises Gullah::Error, 'leaves required' do
      NoLeaf.parse 'foo'
    end
    assert_match(/no leaves/, e.message, 'expected no-leaf message')
  end

  class UndefinedRules1
    extend Gullah

    rule :foo, 'bar'
  end

  def test_undefined_rules_1
    e = assert_raises Gullah::Error, 'some rules undefined' do
      UndefinedRules1.parse 'bar'
    end
    assert_match(/no leaves/, e.message, 'remain undefined')
  end

  class UndefinedRules2
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
  end

  def test_undefined_rules_2
    e = assert_raises Gullah::Error, 'some rules undefined' do
      UndefinedRules2.parse 'bar'
    end
    assert_match(/remain undefined/, e.message, 'remain undefined')
  end

  class AddAfterParse1
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
    leaf :baz, /baz/
  end

  def test_add_after_parse_1
    e = assert_raises Gullah::Error, 'definition after parse' do
      AddAfterParse1.parse 'bar baz'
      AddAfterParse1.rule :plugh, 'plugh'
    end
    assert_match(/must be defined before parsing/, e.message, 'cannot define rule after parsing')
  end

  class AddAfterParse2
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
    leaf :baz, /baz/
  end

  def test_add_after_parse_2
    e = assert_raises Gullah::Error, 'definition after parse' do
      AddAfterParse2.parse 'bar baz'
      AddAfterParse2.leaf :plugh, /plugh/
    end
    assert_match(/must be defined before parsing/, e.message, 'cannot define leaf after parsing')
  end

  class UndefinedTest
    extend Gullah

    rule :foo, 'bar baz', tests: %i[undefined]
    leaf :bar, /bar/
    leaf :baz, /baz/
  end

  def test_undefined_test
    e = assert_raises Gullah::Error, 'undefined test' do
      UndefinedTest.parse 'bar baz'
    end
    assert_match(/is not defined/, e.message, 'must define tests')
  end

  class UndefinedProcessor
    extend Gullah

    rule :foo, 'bar baz', process: :undefined
    leaf :bar, /bar/
    leaf :baz, /baz/
  end

  def test_undefined_processor
    e = assert_raises Gullah::Error, 'undefined processor' do
      UndefinedProcessor.parse 'bar baz'
    end
    assert_match(/is not defined/, e.message, 'must define processors')
  end

  class UndefinedPrecondition
    extend Gullah

    rule :foo, 'bar baz', preconditions: [:undefined]
    leaf :bar, /bar/
    leaf :baz, /baz/
  end

  def test_undefined_precondition
    e = assert_raises Gullah::Error, 'undefined precondition' do
      UndefinedPrecondition.parse 'bar baz'
    end
    assert_match(/is not defined/, e.message, 'must define preconditions')
  end

  class BadTest
    extend Gullah

    rule :foo, 'bar baz', tests: %i[bad]
    leaf :bar, /bar/
    leaf :baz, /baz/

    def bad
      puts 'I have no arguments at all!'
    end
  end

  def test_zero_arity
    e = assert_raises Gullah::Error, 'arity 0' do
      BadTest.parse 'bar baz'
    end
    assert_match(/must take either one or two arguments/, e.message, 'needs one arg')
  end

  class AlsoBadTest
    extend Gullah

    rule :foo, 'bar baz', tests: %i[bad]
    leaf :bar, /bar/
    leaf :baz, /baz/

    def bad(_root, _node, _other, _things)
      puts 'I have too many arguments!'
    end
  end

  def test_excessive_arity
    e = assert_raises Gullah::Error, 'arity many' do
      AlsoBadTest.parse 'bar baz'
    end
    assert_match(/must take either one or two arguments/, e.message, 'no more than 2 args')
  end

  class MisnamedRule
    extend Gullah

    leaf :'bar@', /bar/
    leaf :baz, /baz/
  end

  def test_misnamed_rule
    e = assert_raises Gullah::Error, 'rule name' do
      MisnamedRule.rule :foo, 'bar@ baz'
    end
    assert_match(/cannot parse/, e.message, 'bad rule name')
  end

  class BadSuffix
    extend Gullah

    leaf :bar, /bar/
    leaf :baz, /baz/
  end

  def test_bad_suffix_rule
    e = assert_raises Gullah::Error, 'rule suffix' do
      MisnamedRule.rule :foo, 'bar{2,1} baz'
    end
    assert_match(/is greater than/, e.message, 'bad suffix')
  end

  class Decent
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/
    leaf :baz, /baz/
  end

  def test_filters
    e = assert_raises Gullah::Error, 'unknown filter' do
      Decent.parse 'bar baz', filters: %i[foo]
    end
    assert_match(/unknown filter/, e.message)
  end

  class BadTestReturnValue
    extend Gullah

    rule :foo, 'bar baz', tests: %i[foo]
    leaf :bar, /bar/
    leaf :baz, /baz/

    def foo(_n)
      :foo
    end
  end

  def test_test_return_value
    e = assert_raises Gullah::Error, 'bad test return value' do
      BadTestReturnValue.parse 'bar baz'
    end
    assert_match(/unexpected value/, e.message)
  end

  class BadAncestorTestReturnValue
    extend Gullah

    rule :foo, 'bar baz'
    leaf :bar, /bar/, tests: %i[foo]
    leaf :baz, /baz/

    def foo(_root, _n)
      :foo
    end
  end

  def test_ancestor_test_return_value
    e = assert_raises Gullah::Error, 'bad ancestor test return value' do
      BadAncestorTestReturnValue.parse 'bar baz'
    end
    assert_match(/unexpected value/, e.message)
  end

  class SkinnyRule
    extend Gullah
  end

  def test_skinny_rule
    e = assert_raises Gullah::Error, 'every rule must consume something' do
      SkinnyRule.rule :foo, 'bar? baz?'
    end
    assert_match(/can consume no nodes/, e.message)
  end
end
