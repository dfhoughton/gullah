# frozen_string_literal: true

# a node in an AST
module Gullah
  class Node
    # TODO fix this documentation
    attr_reader :parent, :rule, :leaf, :failed_test, :attributes

    def initialize(parse, s, e, rule)
      @rule = rule
      @leaf = rule.is_a?(Leaf) || trash?
      @text = parse.text
      @attributes = {}
      if leaf
        @start = s
        @end = e
      else
        @children = parse.nodes[s...e]
        @children.each { |n| adopt n }
      end
      if trash?
        @failed_test = true
        attributes[:failures] = [:"?"]
      else
        rule.tests.each do |t|
          unless t.call(self)
            @failed_test = true
            (attributes[:failures] ||= []) << t.name
          end
        end
      end
      unless failed_test
        # if any test failed, this node will not be the child of another node
        rule.parent_tests.each do |t|
          # use position rather than node itself for the sake of clonability
          (attributes[:pending] ||= []) << [t, position]
        end
      end
    end

    def name
      rule.name
    end

    # does this node represent a character sequence no leaf rule matched?
    def trash?
      name == :"?"
    end

    # does this node's subtree contain unsatisfied syntactic requirements?
    def pending_tests?
      !!attributes[:pending]
    end

    # whitespace, punctuation, or comments, for example
    def ignorable?
      leaf && rule.ignorable
    end

    # the portion of the original text dominated by this node
    def own_text
      @text[start...self.end]
    end

    # the entire text parsed
    def full_text
      @text
    end

    # the node's start text offset
    def start
      @start ||= @children[0].start
    end

    # the node's end text offset
    def end
      @end ||= @children[-1].end
    end

    def depth
      parent ? 1 + parent.depth : 0
    end

    # depth -- distance from root -- is only useful when the parse is complete
    def height
      @height ||= leaf ? 0 : 1 + children[0].height
    end

    # unique identifier of a node in a particular parse
    def position
      @position ||= [start, height]
    end

    # does this node contain the given text offset?
    def contains?(offset)
      start <= offset && offset < end
    end

    # find the node at the given position within this node's subtree
    def find(pos)
      offset = pos.first
      return nil unless contains?(offset)

      return self if pos == position

      if (child = children&.find { |c| c.contains? offset })
        child.find(pos)
      end
    end

    def size
      @size ||= leaf ? 1 : @children.map(&:size).sum
    end

    # the root of this node's current parse tree
    # useful in parent rules, where the node triggering the rule will be the root
    def root
      parent ? parent.root : self
    end

    def ancestors
      _ancestors self
    end

    def descendants
      _descendants self
    end

    def siblings
      parent ? parent.children : []
    end

    def prior_siblings
      siblings.select { |n| n.start < start }
    end

    def later_siblings
      siblings.select { |n| n.start > start }
    end

    def clone
      super.tap do |c|
        c.instance_variable_set :@attributes, deep_clone(attributes)
        unless c.leaf
          c.instance_variable_set :@children, deep_clone(children)
        end
      end
    end

    private

    def deep_clone(obj)
      case obj
      when String, Method
        obj
      when Array
        obj.map { |o| deep_clone o }
      when Hash
        obj.map { |k, v| [ deep_clone(k), deep_clone(v) ] }.to_h
      when Set
        obj.map { |v| deep_clone v }.to_set
      else
        obj.clone
      end
    end

    def _ancestors(skip)
      Ancestors.new(self, skip)
    end

    class Ancestors
      include Enumerable
      def initialize(n, skip)
        @n = n
        @skip = skip
      end
      def each(&block)
        yield @n unless @n == @skip
        @n.parent&.send(:_ancestors, @skip)&.each(&block)
      end
    end

    def _descendants(skip)
      Descendants.new(self, skip)
    end

    class Descendants
      include Enumerable
      def initialize(n, skip)
        @n = n
        @skip = skip
      end
      def each(&block)
        yield @n unless @n == @skip
        @n.children.each do |c|
          c.send(:_descendants, @skip).each(&block)
        end
      end
    end

    # establish parent-child relationship and migrate needs from child to self
    def adopt(n)
      n.instance_variable_set :@parent, self
      if (pending = n.attributes.delete :pending)
        pending.each do |pair|
          r, l = pair
          child = find(l) # this will necessarily find some child
          result = r.call(self, child)
          if result.nil?
            # the test doesn't apply, this node inherits it
            (attributes[:pending] ||= []) << pair
          else
            # the test applies
            # mark the results on the parent and the child
            id = [r.name, position, l]
            if result
              # the test was satisfied
              (attributes[:satisfied_ancestor ||= []) << id
              (child.attributes[:satisfied_descendant] ||= []) << id
            else
              # the test failed
              @failed_test = true
              (attributes[:failed_ancestor] ||= []) << id
              (attributes[:failed_descendant] ||= []) << id
            end
          end
        end
      end
    end

    # used during parsing
    def loop_check?(seen=nil)
      return false if failed_test || children.length > 1
      seen ||= Set.new
      if seen.include?(name)
        true
      else
        seen << name
        children.first&.loop_check(seen)
      end
    end
  end
end
