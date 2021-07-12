# frozen_string_literal: true

# a non-terminal grammatical rule
module Gullah
  class Rule
    # name -- a symbol identifying the rule
    # body -- preserved for debugging
    # tests -- tests that must be run after a match to determine whether the node is a keeper
    # ancestor_tests -- tests that must be run after an ancestor match
    # subrules/atoms -- if you have no subrules, you have a sequence of atoms
    attr_reader :name, :body, :tests, :ancestor_tests, :subrules, :atoms, :next

    def initialize(name, body, tests: [])
      @name = name
      @body = body
      @tests = tests
      if body =~ /\|/
        @subrules = body.split(/ ?\| ?/).map do |subrule|
          Rule.new(name, subrule, tests: tests)
        end
      else
        @atoms = body.split(/ /).map do |a|
          Atom.new(a, self)
        end
        @atoms.each_with_index do |a, i|
          a.instance_variable_set :@next, @atoms[i + 1]
        end
      end
    end

    def post_init
      @tests, @ancestor_tests = tests.partition { |m| m.arity == 1 }
    end

    # the subrules that may start a match and their atoms
    def starters
      if subrules
        subrules.flat_map(&:starters)
      else
        ar = []
        atoms.each do |a|
          ar << [a.seeking, a]
          break if a.required?
        end
        ar
      end
    end

    # could this rule participate in a loop?
    def potentially_unary?
      if subrules
        subrules.any?(&:potentially_unary)
      else
        atoms.sum(&:min_repeats) < 2
      end
    end

    # collect all links from a sought symbol to the new name
    # used in testing for potential infinite loops
    def branches
      if subrules
        subrules.select(&:potentially_unary?).flat_map(&:branches)
      else
        atoms.map { |a| [a.seeking, name] }
      end
    end
  end
end
