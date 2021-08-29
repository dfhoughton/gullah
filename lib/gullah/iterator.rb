# frozen_string_literal: true

module Gullah
  # for iterating over reductions of a given parse
  # @private
  class Iterator # :nodoc:
    attr_reader :parse

    def initialize(parse, hopper, starters, do_unary_branch_check)
      @parse = parse
      @hopper = hopper
      @starters = starters
      @do_unary_branch_check = do_unary_branch_check
      @returned_any = false
      # this iterator iterates over both node indices and rule indices
      @root_index = 0
      @rule_index = 0
      @node = parse.roots[0]
    end

    # return the next reduction, if any
    def next
      loop do
        return nil unless (a = current_rule)

        @rule_index += 1
        unless (offset = a.match(parse.roots, @root_index))
          next
        end

        if (p = @hopper.vet(parse, @root_index, offset, a.parent, @do_unary_branch_check))
          @returned_any = true
          return p
        end
      end
    end

    # number of nodes that need reduction
    def length
      @parse.length
    end

    # number of erroneous nodes in the parse
    def errors
      @parse.incorrectness_count
    end

    def never_returned_any?
      !@returned_any
    end

    private

    def current_rule
      while @node
        @rules ||= @starters[@node.name]
        r = @rules&.[] @rule_index
        return r if r

        # the rules for this node are used up; try the next one
        @rule_index = 0
        @root_index += 1
        @node = parse.roots[@root_index]
        @rules = nil
      end
    end
  end
end
