# frozen_string_literal: true

module Gullah
  # a rule used in string tokenization
  class Leaf # :nodoc:
    attr_reader :rx, :name, :ignorable, :boundary, :tests, :ancestor_tests, :preconditions

    def initialize(name, rx, ignorable: false, boundary: false, tests: [], preconditions: [])
      @name = name
      @rx = rx
      @ignorable = ignorable
      @boundary = boundary
      @tests = tests
      @preconditions = preconditions
    end

    ## ADVISORILY PRIVATE

    def _post_init(tests, preconditions)
      @tests, @ancestor_tests = tests.partition { |m| m.arity == 1 }
      @preconditions = preconditions
    end
  end
end
