# frozen_string_literal: true

module Gullah
  # a node in an AST
  class Node
    ##
    # The parent node of this node, if any.
    attr_reader :parent

    attr_reader :rule # :nodoc:

    ##
    # A hash of attributes, including indicators of tests that passed or failed.
    # The +atts+ alias of +attributes+ exists for when a more telegraphic coding style is useful.
    attr_reader :attributes # TODO: collect the keys users shouldn't use and document them

    ##
    # The children of this node, if any, as an array.
    attr_reader :children

    ##
    # A concise stringification of the structure of this node's subtree.
    attr_reader :summary

    ##
    # An alternative method for when a more telegraphic coding style is useful.
    alias atts attributes

    def initialize(parse, s, e, rule) # :nodoc:
      @rule = rule
      @leaf = rule.is_a?(Leaf) || trash?
      @text = parse.text
      @attributes = {}
      @failed_test = false
      if @leaf
        @start = s
        @end = e
      else
        @children = parse.roots[s...e]
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
            break
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

    ##
    # The name of the rule that created this node.
    def name
      rule.name
    end

    ##
    # Does this node represent a character sequence no leaf rule matched?
    def trash?
      false
    end

    ##
    # Is this node one that cannot be the child of another node?
    def boundary?
      false
    end

    ##
    # Is this a leaf node?
    def leaf?
      @leaf
    end

    ##
    # Does this node have some failed test or does it represent characters no leaf rule mached?
    def failed?
      trash? || error?
    end

    # is this node some sort of boundary to further matching
    def traversible? # :nodoc:
      !(boundary? || trash? || error?)
    end

    ##
    # Does this node have some failed test?
    def error?
      @failed_test
    end

    ##
    # Does this node's subtree contain unsatisfied syntactic requirements?
    # These are tests that depend on nodes not in the node's own subtree.
    def pending_tests?
      !!attributes[:pending]
    end

    ##
    # Was this node created by an +ignore+ rule?
    def ignorable?
      @leaf && rule.ignorable
    end

    ##
    # Was this node created by something other than an +ignore+ rule?
    def significant?
      !ignorable?
    end

    ##
    # Is this a node that has other nodes as children?
    def nonterminal?
      !@leaf
    end

    ##
    # The portion of the original text covered by this node. This is in effect
    # the text of the leaves of its subtree.
    def text
      @text[start...self.end]
    end

    ##
    # A reference to the full text the node's text is embedded in.
    def full_text
      @text
    end

    ##
    # The text preceding this node's text. Useful for lookaround tests and preconditions.
    def text_before
      @text[0...start]
    end

    ##
    # The text following this node's text. Useful for lookaround tests and preconditions.
    def text_after
      @text[self.end..]
    end

    ##
    # The node's start text offset. For a non-terminal node, this will be
    # the same as the start of the first leaf node of its subtree.
    def start
      @start ||= @children[0].start
    end

    ##
    # The node's end text offset. For a non-terminal node, this will be the
    # same as the end of the last leaf node of its subtree.
    def end
      @end ||= @children[-1].end
    end

    ##
    # Distance of the node from the root node of the parse tree.
    # During parsing, while nodes are being added, this distance may change, unlike
    # the height.
    #
    # The root node has a depth of 0. It's children have a depth of 1. Their
    # children have a depth of 2. And so forth.
    def depth
      parent ? 1 + parent.depth : 0
    end

    ##
    # The distance of a node from the first leaf node in its subtree. If the node
    # is the immediate parent of this leaf, its distance will be one. Leaves have
    # a height of zero.
    def height
      @height ||= @leaf ? 0 : 1 + children[0].height
    end

    ##
    # A pair consisting of the nodes start and height. This will be a unique
    # identifier for the node in its parse and is constant at all stages of parsing.
    def position
      @position ||= [start, height]
    end

    ##
    # Does this node contain the given text offset?
    def contains?(offset)
      start <= offset && offset < self.end
    end

    ##
    # Finds the node at the given position within this node's subtree.
    def find(pos)
      offset = pos.first
      return nil unless contains?(offset)

      return self if pos == position

      if (child = children&.find { |c| c.contains? offset })
        child.find(pos)
      end
    end

    ##
    # The number of nodes in this node's subtree. Leaves always have a size of 1.
    def size
      @size ||= @leaf ? 1 : @children.map(&:size).sum + 1
    end

    ##
    # The root of this node's current parse tree.
    #
    # Note, if you use this in a node test
    # the root will always be the same as the node itself because these tests are run
    # when the node is being added to the tree. If you use it in structure tests, it
    # will be some ancestor of the node but not necessarily the final root. The current
    # root is always the first argument to structure tests. Using this argument is more
    # efficient than using the root method. Really, the root method is only useful in
    # completed parses.
    def root
      parent ? parent.root : self
    end

    ##
    # Does this node have any parent? If not, it is a root.
    def root?
      parent.nil?
    end

    ##
    # Returns an Enumerable enumerating the nodes immediately above this node in the
    # tree: its parent, its parent's parent, etc.
    def ancestors
      _ancestors self
    end

    ##
    # Returns an Enumerable over the descendants of this node: its children, its children's
    # children, etc. This enumeration is depth-first.
    def descendants
      _descendants self
    end

    ##
    # Returns an Enumerable over this node and its descendants. The node itself is the first
    # node returned.
    def subtree
      _descendants nil
    end

    ##
    # Returns the children of this node's parent's children minus this node itself.
    def siblings
      parent&.children&.reject { |n| n == self }
    end

    ##
    # The index of this node among its parent's children.
    def sibling_index
      @sibling_index ||= parent.children.index self if parent
    end

    ##
    # Returns the children of this node's parent that precede it.
    def prior_siblings
      parent && siblings[0...sibling_index]
    end

    ##
    # Returns the children of this node's parent that follow it.
    def later_siblings
      parent && siblings[(sibling_index + 1)..]
    end

    ##
    # Is this node the last of its parent's children?
    def last_child?
      parent && sibling_index == parent.children.length - 1
    end

    ##
    # Is this node the first of its parent's children?
    def first_child?
      sibling_index.zero?
    end

    ##
    # The immediately prior sibling to this node.
    def prior_sibling
      if parent
        first_child? ? nil : parent.children[sibling_index - 1]
      end
    end

    ##
    # The immediately following sibling to this node.
    def later_sibling
      parent && parent.children[sibling_index + 1]
    end

    ##
    # The leaves of this node's subtree. If the node is a leaf, this returns a
    # single-member array containing the node itself.
    def leaves
      @leaf ? [self] : descendants.select(&:leaf?)
    end

    ##
    # The collection of nodes in the subtree containing this node that do not +contain+
    # the node and whose start offset precedes its start offset.
    def prior
      root.descendants.reject { |n| n.contains? start }.select { |n| n.start < start }
    end

    ##
    # The collection of nodes in the subtree containing this node whose start offset
    # is at or after its end offset.
    def later
      root.descendants.select { |n| n.start >= self.end }
    end

    def clone # :nodoc:
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

    # Produces a simplified representation of the node to facilitate debugging. The +so+
    # named parameter, if true, will cause the representation to drop ignored nodes.
    # The name "so" stands for "significant only".
    #
    #   > pp root.dbg
    #
    #   {:name=>:S,
    #    :pos=>{:start=>0, :end=>11, :depth=>0},
    #    :children=>
    #     [{:name=>:NP,
    #       :pos=>{:start=>0, :end=>7, :depth=>1},
    #       :children=>
    #        [{:name=>:D, :pos=>{:start=>0, :end=>3, :depth=>2}, :text=>"the"},
    #         {:name=>:_ws,
    #          :pos=>{:start=>3, :end=>4, :depth=>2},
    #          :ignorable=>true,
    #          :text=>" "},
    #         {:name=>:N, :pos=>{:start=>4, :end=>7, :depth=>2}, :text=>"cat"}]},
    #      {:name=>:_ws,
    #       :pos=>{:start=>7, :end=>8, :depth=>1},
    #       :ignorable=>true,
    #       :text=>" "},
    #      {:name=>:VP,
    #       :pos=>{:start=>8, :end=>11, :depth=>1},
    #       :children=>
    #        [{:name=>:V, :pos=>{:start=>8, :end=>11, :depth=>2}, :text=>"sat"}]}]}
    #
    #   > pp root.dbg so: true
    #
    #   {:name=>:S,
    #    :pos=>{:start=>0, :end=>11, :depth=>0},
    #    :children=>
    #     [{:name=>:NP,
    #       :pos=>{:start=>0, :end=>7, :depth=>1},
    #       :children=>
    #        [{:name=>:D, :pos=>{:start=>0, :end=>3, :depth=>2}, :text=>"the"},
    #         {:name=>:_ws, :pos=>{:start=>3, :end=>4, :depth=>2}, :text=>" "},
    #         {:name=>:N, :pos=>{:start=>4, :end=>7, :depth=>2}, :text=>"cat"}]},
    #      {:name=>:_ws, :pos=>{:start=>7, :end=>8, :depth=>1}, :text=>" "},
    #      {:name=>:VP,
    #       :pos=>{:start=>8, :end=>11, :depth=>1},
    #       :children=>
    #        [{:name=>:V, :pos=>{:start=>8, :end=>11, :depth=>2}, :text=>"sat"}]}]}
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
          simpleton[:trash] = true if trash?
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
