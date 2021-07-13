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
    def add(s, e, rule, loop_check, trash = false)
      clone.tap do |b|
        b.instance_variable_set :@nodes, nodes.map(&:clone)
        cz = trash ? Trash : Node
        n = cz.new(b, s, e, rule)
        return nil if loop_check && n.send(:loop_check?)

        if n.leaf
          b.nodes << n
        else
          b.nodes[s...e] = [n]
        end
      end
    end

    # a simplified representation for debugging
    # "so" = "significant only"
    def dbg(so: false)
      nodes.map { |n| n.dbg so: so }
    end

    def clone
      super.tap do |c|
        if c.instance_variable_get :@summary
          c.remove_instance_variable :@summary
        end
      end
    end

    # the parse's syntactic structure represented as a string
    def summary
      @summary ||= nodes.map(&:summary).join(';')
    end
  end
end
