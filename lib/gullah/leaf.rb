# frozen_string_literal: true

# a rule used in string tokenization
module Gullah
  class Leaf
    attr_reader :rx, :name, :ignorable, :tests, :ancestor_tests

    def initialize(name, rx, ignorable: false, tests: [])
      @name = name
      @rx = rx
      @ignorable = ignorable
      @tests, @ancestor_tests = tests.partition { |m| m.arity == 1 }
    end
  end
end
