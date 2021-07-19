# frozen_string_literal: true

# a node in an AST
module Gullah
  class Node
    # TODO: fix this documentation
    attr_reader :parent, :rule, :attributes, :children, :summary

    # an alternative method for when a more telegraphic coding style is useful
    alias_method :atts, :attributes

    def initialize(parse, s, e, rule) # :nodoc:
      @rule = rule
      @leaf = rule.is_a?(Leaf) || trash?
      @text = parse.text
      @attributes = {}
      if @leaf
        @start = s
        @end = e
      else
        @children = parse.nodes[s...e]
        @children.each { |n| adopt n }
      end
      unless trash?
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
      unless failed?
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
      false
    end

    def leaf?
      @leaf
    end

    def failed?
      trash? || error?
    end

    def error?
      @failed_test
    end

    # does this node's subtree contain unsatisfied syntactic requirements?
    def pending_tests?
      !!attributes[:pending]
    end

    # whitespace, punctuation, or comments, for example
    def ignorable?
      @leaf && rule.ignorable
    end

    # not ignorable
    def significant?
      !ignorable?
    end

    # not a leaf?
    def nonterminal?
      !@leaf
    end

    # the portion of the original text dominated by this node
    def text
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
      @height ||= @leaf ? 0 : 1 + children[0].height
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
      @size ||= @leaf ? 1 : @children.map(&:size).sum + 1
    end

    # the root of this node's current parse tree
    def root
      parent ? parent.root : self
    end

    def root?
      parent.nil?
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
      parent.children.reject { |n| n == self } if parent
    end

    def sibling_index
      if parent
        @sibling_index ||= parent.children.index self
      end
    end

    def prior_siblings
      parent && siblings[0...sibling_index]
    end

    def later_siblings
      parent && siblings[(sibling_index+1)..]
    end

    def last_child?
      parent && sibling_index == parent.children.length - 1
    end

    def first_child?
      sibling_index == 0
    end

    # the immediately prior sibling to this node
    def prior_sibling
      if parent
        first_child? ? nil : parent.children[sibling_index-1]
      end
    end

    # the immediately following sibling to this node
    def later_sibling
      parent && parent.children[sibling_index+1]
    end

    def leaves
      @leaf ? [self] : descendants.select(&:leaf?)
    end

    def prior
      root.descendants.reject { |n| n.contains? start }.select { |n| n.start < start }
    end

    def later
      root.descendants.select { |n| n.start >= self.end }
    end

    def clone
      super.tap do |c|
        c._attributes = deep_clone(attributes)
        unless c.leaf?
          c._children = deep_clone(children)
          c.children.each do |child|
            child._parent = c
          end
        end
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
        simpleton[:failed] = true if @failed_test
        simpleton[:attributes] = deep_clone attributes if attributes.any?
        if leaf?
          simpleton[:ignorable] = true unless so || significant?
          simpleton[:text] = text
        else
          simpleton[:children] = children.map { |c| c.dbg so: so }
        end
      end
    end

    ## ADVISORILY PRIVATE

    # :stopdoc:

    def _summary=(str) # :nodoc:
      @summary = str
    end

    # used during parsing
    # make sure we don't have any repeated symbols in a unary branch
    def _loop_check?(seen = nil) # :nodoc:
      return true if seen == name

      return false if !@leaf && children.length > 1

      if seen.nil?
        # this is the beginning of the check
        # the only name we need look for is this rule's name, since
        # all those below it must have passed the check
        seen = name
      end
      @leaf ? false : children.first._loop_check?(seen)
    end

    def _attributes=(attributes) # :nodoc:
      @attributes = attributes
    end

    def _parent=(other) # :nodoc:
      @parent = other
    end

    def _children=(children) # :nodoc:
      @children = children
    end

    def _descendants(skip) # :nodoc:
      Descendants.new(self, skip)
    end

    def _ancestors(skip) # :nodoc:
      Ancestors.new(self, skip)
    end

    def _failed_test=(bool) # :nodoc:
      @failed_test = bool
    end

    private

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

    class Ancestors
      include Enumerable
      def initialize(n, skip)
        @n = n
        @skip = skip
      end

      def each(&block)
        yield @n unless @n == @skip
        @n.parent&._ancestors(@skip)&.each(&block)
      end

      def last
        @n.root? ? @n : @n.root
      end
    end

    class Descendants
      include Enumerable
      def initialize(n, skip)
        @n = n
        @skip = skip
      end

      def each(&block)
        yield @n unless @n == @skip
        unless @n.leaf?
          @n.children.each do |c|
            c._descendants(@skip).each(&block)
          end
        end
      end

      def last
        @n.root.leaves.last
      end
    end

    # establish parent-child relationship and migrate needs from child to self
    def adopt(n)
      n._parent = self
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
            (attributes[:satisfied_ancestor] ||= []) << [r.name, l, *extra]
            (child.attributes[:satisfied_descendant] ||= []) << [r.name, position, *extra]
          when :fail
            @failed_test = true
            (attributes[:failed_ancestor] ||= []) << [r.name, l, *extra]
            (child.attributes[:failed_descendant] ||= []) << [r.name, position, *extra]
            child._failed_test = true
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
  end
end
