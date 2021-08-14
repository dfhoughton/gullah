# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'

# :stopdoc:

# to verify that if subrules have different tests the tests only apply to the
# appropriate subrule
class TestsPerSubruleTest < Minitest::Test
  class TestsPerLeaf
    extend Gullah

    rule :phrase, 'noun+'

    leaf :noun, /\bfoo\b/
    leaf :noun, /\bbar\b/, tests: [:preceding_foo]

    def preceding_foo(node)
      node.text_before =~ /\bfoo\s*\z/ ? :pass : :fail
    end
  end

  def test_just_foos
    parse = TestsPerLeaf.first 'foo foo foo'
    # basically, we should get one good parse
    assert_equal 'phrase[noun,_ws,noun,_ws,noun]', parse.summary
  end

  def test_just_bars
    parse = TestsPerLeaf.first 'bar bar bar'
    assert_equal 'noun;_ws;noun;_ws;noun', parse.summary
    assert parse.roots.select(&:significant?).all?(&:error?), 'all leaves are errors'
  end

  def test_foo_bar
    parse = TestsPerLeaf.first 'foo bar'
    # again, one good parse
    assert_equal 'phrase[noun,_ws,noun]', parse.summary
  end

  def test_foo_bar_bar
    parse = TestsPerLeaf.first 'foo bar bar'
    assert_equal 'phrase[noun,_ws,noun,_ws];noun', parse.summary
    assert_equal 1, parse.roots.select(&:significant?).count(&:error?)
  end
end
