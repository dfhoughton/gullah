# frozen_string_literal: true

# for iterating over reductions of a given parse
# THIS CLASS SHOULD BE TREATED AS PRIVATE
module Gullah
  class Iterator
    attr_reader :parse

    def initialize(parse, hopper, starters, do_unary_branch_check)
      @parse = parse
      @hopper = hopper
      @starters = starters
      @do_unary_branch_check = do_unary_branch_check
      @returned_any = false
      # this iterator iterates over both node indices and rule indices
      @node_index = 0
      @rule_index = 0
      @node = parse.nodes[0]
    end

    # return the next reduction, if any
    def next
      loop do
        return nil unless (a = current_rule)

        @rule_index += 1
        unless (offset = a.match(parse.nodes, @node_index))
          next
        end

        if (p = @hopper.vet(parse, @node_index, offset, a.parent, @do_unary_branch_check))
          @returned_any = true
          return p
        end
      end
    end

    def never_returned_any?
      !@returned_any
    end

    private

    def current_rule
      while @node
        @rules ||= @starters[@node.name]
        r = @rules&.[] @rule_index
        return r if r && r.seeking == @node.name

        # the rules for this node are used up; try the next one
        @rule_index = 0
        @node_index += 1
        @node = parse.nodes[@node_index]
        @rules = nil
      end
    end
  end
end
