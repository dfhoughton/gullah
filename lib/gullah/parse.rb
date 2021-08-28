# frozen_string_literal: true

module Gullah
  ##
  # A parse is the collection of root nodes produced by parsing a text.
  #
  #   class Example
  #     extend Gullah
  #
  #     rule :S, 'NP VP'
  #     rule :NP, 'D N'
  #     rule :VP, 'V'
  #
  #     leaf :D, /the/
  #     leaf :N, /cat/
  #     leaf :V, /sat/
  #   end
  #
  #   parses = Example.parse 'the cat sat', n: 1
  #
  #   # this is a Parse
  #   parse = parses.first
  #   puts parse.length  # => 1
  #   puts parse.size    # => 8
  #   puts parse.summary # => S[NP[D,_ws,N],_ws,VP[V]]
  #
  class Parse
    ##
    # The root nodes of all subtrees found in this parse in sequence. This is an array.
    attr_reader :roots

    # The text parsed by this parse.
    attr_reader :text

    # A concise stringification of the syntactic structure of this parse.
    # For a given string and grammar all the parses will have a unique
    # summary.
    attr_reader :summary

    def initialize(text) # :nodoc:
      @roots = []
      @text = text
    end

    # produce a clone of this parse with a new node with the given offsets and rule
    def add(s, e, rule, loop_check, trash = false, boundary = false) # :nodoc:
      clone.tap do |b|
        b._roots = roots.map(&:clone)
        cz = if trash
               Trash
             elsif boundary
               Boundary
             else
               Node
             end
        n = cz.new(b, s, e, rule)
        return nil if loop_check && n._loop_check?

        if n.leaf?
          b.roots << n
        else
          b.roots[s...e] = [n]
        end
      end
    end

    ##
    # The number of root nodes in this parse. This is *not* the same as size.
    def length
      roots.length
    end

    ##
    # The total number of nodes in this parse. This is *not* the same as length.
    def size
      @size ||= roots.sum(&:size)
    end

    ##
    # The count of nodes that failed some test. Structure tests mark both the child
    # and the ancestor node where the test was run as erroneous,
    # so they will increase the +incorrectness_count+ by 2.
    def incorrectness_count
      @incorrectness_count ||= roots.select(&:failed?).count
    end

    ##
    # The count of nodes which have some structure test which was never
    # successfully run.
    def pending_count
      @pending_count ||= roots.select(&:pending_tests?).count
    end

    ##
    # Are there any nodes in the parse that are erroneous, either because
    # some test failed or because they correspond to "trash" -- characters
    # that matched no leaf rule?
    def errors?
      incorrectness_count.positive?
    end

    ##
    # Are all leaves accounted for without errors and have all tests passed?
    def success?
      !errors? && roots.all? { |n| n.ignorable? || n.nonterminal? && !n.pending_tests? }
    end

    ##
    # Not a +success?+
    def failure?
      !success?
    end

    # a simplified representation for debugging
    # "so" = "significant only"
    def dbg(so: false)
      roots.map { |n| n.dbg so: so }
    end

    ##
    # return an enumeration of all the nodes in the parse.
    #
    #   parses = Grammar.parse "this grammar uses the usual whitespace rule"
    #
    #   parses.first.nodes.select { |n| n.name == :_ws }.count  # => 6
    def nodes
      NodeIterator.new self
    end

    def clone # :nodoc:
      super.tap do |c|
        %i[@summary @size @incorrectness_count @pending_count].each do |v|
          c.remove_instance_variable v if c.instance_variable_defined?(v)
        end
      end
    end

    ##
    # The start offset of the first leaf in the parse.
    def start
      roots.first.start
    end

    ##
    # The end offset of the last leaf in the parse.
    def end
      roots.last.end
    end

    ## ADVISORILY PRIVATE

    # :stopdoc:

    # for debugging
    def own_text
      text[start...self.end]
    end

    # make a new parse whose first part is this parse's nodes and whose
    # second part is the later parse's nodes
    def merge(later)
      self.class.new(text).tap do |merged|
        merged._roots = roots + later.roots
      end
    end

    # split the parse into segments and boundaries
    def split
      last_index = 0
      splits = []

      # look for traversible sequences and boundaries
      roots.each_with_index do |n, i|
        next if n.traversible?

        if i > last_index
          # sometimes you can have two boundaries in a row,
          # or you can begin with a boundary
          segment = Parse.new text
          segment._roots = roots[last_index...i]
          splits << segment.initialize_summaries
        end

        # create boundary element
        segment = Parse.new text
        segment._roots = [n]
        splits << segment.initialize_summaries
        last_index = i + 1
      end
      return [initialize_summaries] if last_index.zero?

      if last_index < roots.length
        segment = Parse.new text
        segment._roots = roots[last_index...roots.length]
        splits << segment.initialize_summaries
      end
      splits
    end

    def _roots=(roots)
      @roots = roots
    end

    # it would be conceptually simpler to lazily initialize the summary, but this
    # gives us a speed boost
    def initialize_summaries
      @summary = roots.each { |n| n._summary = n.name unless n.summary }.map(&:summary).join(';')
      self
    end

    def _summary=(str)
      @summary = str
    end

    class NodeIterator # :nodoc:
      include Enumerable

      def initialize(parse)
        @parse = parse
      end

      def each(&block)
        @parse.roots.each do |root|
          root.subtree.each(&block)
        end
      end

      def last
        @parse.roots.last.leaves.last
      end
    end
  end
end
