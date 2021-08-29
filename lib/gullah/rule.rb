# frozen_string_literal: true

module Gullah
  # a non-terminal grammatical rule
  # @private
  class Rule # :nodoc:
    # name -- a symbol identifying the rule
    # body -- preserved for debugging
    # tests -- tests that must be run after a match to determine whether the node is a keeper
    # ancestor_tests -- tests that must be run after an ancestor match
    # subrules/atoms -- if you have no subrules, you have a sequence of atoms
    attr_reader :name, :body, :tests, :ancestor_tests, :subrules, :atoms, :preconditions

    def initialize(name, body, tests: [], preconditions: [])
      @name = name
      @body = body
      @tests = tests
      @preconditions = preconditions
      if body =~ /\|/
        @subrules = body.split(/ ?\| ?/).map do |subrule|
          Rule.new(name, subrule, tests: tests)
        end
      else
        @atoms = body.split(/ /).map do |a|
          Atom.new(a, self)
        end
        @atoms.each_with_index do |a, i|
          a._next = @atoms[i + 1]
        end
      end
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
        subrules.any?(&:potentially_unary?)
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

    # collect all the different rules some atom of this rule might match
    def seeking
      if subrules
        subrules.flat_map(&:seeking).uniq
      else
        atoms.map(&:seeking).uniq
      end
    end

    # obtain all the literals required by this rule
    def literals
      if subrules
        subrules.flat_map(&:literals).uniq
      else
        atoms.select(&:literal).map(&:seeking).uniq
      end
    end

    ## ADVISORILY PRIVATE

    def _post_init(tests, preconditions)
      @tests, @ancestor_tests = tests.partition { |m| m.arity == 1 }
      @preconditions = preconditions
    end
  end
end
