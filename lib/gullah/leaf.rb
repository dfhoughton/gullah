# frozen_string_literal: true

module Gullah
  # a rule used in string tokenization
  class Leaf # :nodoc:
    attr_reader :rx, :name, :ignorable, :boundary, :tests, :ancestor_tests

    def initialize(name, rx, ignorable: false, boundary: false, tests: [])
      @name = name
      @rx = rx
      @ignorable = ignorable
      @boundary = boundary
      @tests = tests
    end

    ## ADVISORILY PRIVATE

    def _post_init(tests)
      @tests, @ancestor_tests = tests.partition { |m| m.arity == 1 }
    end
  end
end
