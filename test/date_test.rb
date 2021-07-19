# frozen_string_literal: true

require 'minitest/autorun'

require 'gullah'
require 'byebug'
require 'date'

# :stopdoc:

class DateTest < Minitest::Test
  class DateGrammar
    extend Gullah

    rule :iso, 'year "/" month "/" day', tests: %i[sane]
    rule :american, 'month "/" day "/" year', tests: %i[sane]
    rule :euro, 'day "/" month "/" year', tests: %i[sane]

    leaf :day, /\b\d{1,2}\b/, tests: %i[day], process: :to_i
    leaf :month, /\b\d{1,2}\b/, tests: %i[month], process: :to_i
    # to confirm that we can pass a proc as a processor
    leaf :year, /\b\d+\b/, process: ->(n) { n.atts[:value] = n.text.to_i }

    def to_i(n)
      n.atts[:value] = n.text.to_i
    end

    def month(root, n)
      if root == n.parent
        month = n.atts[:value]
        if month < 1
          [:fail, 'month must be greater than 0']
        elsif month > 12
          [:fail, 'month cannot be greater than 12']
        else
          :pass
        end
      end
    end

    def day(root, n)
      if root == n.parent
        day = n.atts[:value]
        if day < 1
          [:fail, 'day must be greater than 0']
        elsif day > 31
          [:fail, 'day cannot be greater than 31']
        else
          :pass
        end
      end
    end

    def sane(n)
      day = n.descendants.find { |o| o.name == :day }
      month = n.descendants.find { |o| o.name == :month }
      year = n.descendants.find { |o| o.name == :year }
      if day && month && year
        begin
          Date.new year.atts[:value], month.atts[:value], day.atts[:value]
        rescue ArgumentError
          return [
            :fail,
            "month #{month.text} does not have a day #{day.text} in #{year.text}"
          ]
        end
        :pass
      else
        [:fail, "we don't have all parts of a date"]
      end
    end
  end

  def test_iso
    parses = DateGrammar.parse '2010/5/6'
    assert_equal 1, parses.length, 'one parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'one root node'
    root = parse.nodes.first
    assert_equal :iso, root.name, 'got an iso date'
  end

  def test_american
    parses = DateGrammar.parse '10/31/2021'
    assert_equal 1, parses.length, 'one parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'one root node'
    root = parse.nodes.first
    assert_equal :american, root.name, 'got an American date'
  end

  def test_euro
    parses = DateGrammar.parse '31/10/2021'
    assert_equal 1, parses.length, 'one parse'
    parse = parses.first
    assert_equal 1, parse.nodes.length, 'one root node'
    root = parse.nodes.first
    assert_equal :euro, root.name, 'got a euro date'
  end

  def test_ambiguous
    parses = DateGrammar.parse '5/6/1969'
    assert_equal 2, parses.length, 'two parses'
    options = %i[euro american]
    parses.each do |p|
      assert_equal 1, p.nodes.length
      options -= [p.nodes.first.name]
    end
    assert_equal [], options, 'one is american and one euro'
  end
end
