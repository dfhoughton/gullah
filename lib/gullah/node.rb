# frozen_string_literal: true

# a node in an AST
module Gullah
  class Node
    # TODO: fix this documentation
    attr_reader :parent, :rule, :leaf, :failed_test, :attributes, :children

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
          result, *extra = Array(t.call(self))
          case result
          when :ignore
            # no-op test
          when :pass
            (attributes[:satisfied] ||= []) << [t.name, *extra]
          when :fail
            @failed_test = true
            (attributes[:failures] ||= []) << [t.name, *extra]
          else
            raise Error, <<~MSG
              test #{t.name} returned an unexpected value:
                #{result.inspect}
              expected values: #{%i[ignore pass fail].inspect}
            MSG
          end
        end
      end
      unless failed_test
        # if any test failed, this node will not be the child of another node
        rule.ancestor_tests.each do |t|
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

    # not ignorable
    def significant?
      !ignorable?
    end

    # not a leaf?
    def nonterminal?
      !leaf
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

    # depth -- distance from root -- is only useful when the parse is complete
    def depth
      parent ? 1 + parent.depth : 0
    end

    # distance from first leaf
    def height
      @height ||= leaf ? 0 : 1 + children[0].height
    end

    # unique identifier of a node in a particular parse
    def position
      @position ||= [start, height]
    end

    # does this node contain the given text offset?
    def contains?(offset)
      start <= offset && offset < self.end
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
      @size ||= leaf ? 1 : @children.map(&:size).sum + 1
    end

    # the root of this node's current parse tree
    def root
      parent ? parent.root : self
    end

    def ancestors
      _ancestors self
    end

    def descendants
      _descendants self
    end

    def subtree
      _descendants nil
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

    def leaves
      leaf ? [self] : descendants.select(&:leaf)
    end

    def prior
      root.descendants.select { |n| n.start < start }
    end

    def later
      root.descendants.select { |n| n.start >= self.end }
    end

    def clone
      super.tap do |c|
        c.instance_variable_set :@attributes, deep_clone(attributes)
        c.instance_variable_set :@children, deep_clone(children) unless c.leaf
      end
    end

    # a simplified representation of the node
    # written to facilitate debugging
    # "so" = "significant only"
    def dbg(so: false)
      {
        name: name,
        pos: {
          start: start,
          end: self.end,
          depth: depth
        }
      }.tap do |simpleton|
        simpleton[:failed] = true if failed_test
        simpleton[:attributes] = deep_clone attributes if attributes.any?
        if leaf
          simpleton[:ignorable] = true unless so || significant?
          simpleton[:text] = own_text
        else
          simpleton[:children] = children.map { |c| c.dbg so: so }
        end
      end
    end

    # the node's syntactic structure represented as a string
    def summary
      @summary ||= leaf ? name : "#{name}[#{children.map(&:summary).join(',')}]"
    end

    protected

    def deep_clone(obj)
      case obj
      when String, Method
        obj
      when Array
        obj.map { |o| deep_clone o }
      when Hash
        obj.map { |k, v| [deep_clone(k), deep_clone(v)] }.to_h
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
        unless @n.leaf
          @n.children.each do |c|
            c.send(:_descendants, @skip).each(&block)
          end
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
          result, *extra = Array(r.call(self, child))
          case result
          when :ignore
            # nothing to do
          when nil
            # the test doesn't apply, this node inherits it
            (attributes[:pending] ||= []) << pair
          when :pass
            # mark the results on the parent and the child
            record = [r.name, position, l, *extra]
            (attributes[:satisfied_ancestor] ||= []) << record
            (child.attributes[:satisfied_descendant] ||= []) << record
          when :fail
            record = [r.name, position, l, *extra]
            @failed_test = true
            (attributes[:failed_ancestor] ||= []) << record
            (attributes[:failed_descendant] ||= []) << record
          else
            raise Error, <<~MSG
              ancestor test #{r.name} returned an unexpected value:
                #{result.inspect}
              expected values: #{[:ignore, :pass, :fail, nil].inspect}
            MSG
          end
        end
      end
    end

    # used during parsing
    # make sure we don't have any repeated symbols in a unary branch
    def loop_check?(seen = nil)
      return true if seen == name

      return false if !leaf && children.length > 1

      if seen.nil?
        # this is the beginning of the check
        # the only name we need look for is this rule's name, since
        # all those below it must have passed the check
        seen = name
      end
      leaf ? false : children.first.loop_check?(seen)
    end
  end
end
