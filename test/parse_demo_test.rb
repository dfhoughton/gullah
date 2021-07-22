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
end
