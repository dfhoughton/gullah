# frozen_string_literal: true

# a set of nodes
module Gullah
  class Parse
    attr_reader :nodes, :text

    def initialize(text)
      @nodes = []
      @text = text
    end

    # produce a clone of this parse with a new node with the given offsets and rule
    def add(s, e, rule, loop_check)
      clone.tap do |b|
        b.instance_variable_set :@nodes, nodes.map(&:clone)
        n = Node.new(b, s, e, rule)
        n.instance_variable_set :@failed_test, true if loop_check && n.send(:loop_check?)
        if n.leaf
          b.nodes << n
        else
          b.nodes[s...e] = [n]
        end
      end
    end
  end
end
