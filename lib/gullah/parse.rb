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
    # stringification.
    attr_reader :summary

    def initialize(text) # :nodoc:
      @roots = []
      @text = text
    end

    # produce a clone of this parse with a new node with the given offsets and rule
    def add(s, e, rule, loop_check, trash = false) # :nodoc:
      clone.tap do |b|
        b._roots = roots.map(&:clone)
        cz = trash ? Trash : Node
        n = cz.new(b, s, e, rule)
        return nil if loop_check && n._loop_check?

        if n.leaf?
          b.roots << n
        else
          b.roots[s...e] = [n]
        end
      end
    end

    # The number of root nodes in this parse. This is *not* the same as size.
    def length
      roots.length
    end

    # The total number of nodes in this parse. This is *not* the same as length.
    def size
      @size ||= roots.sum(&:size)
    end

    def correctness_count
      @correctness_count ||= roots.select(&:failed?).count
    end

    def pending_count
      @pending_count ||= roots.select(&:pending_tests?).count
    end

    def errors?
      correctness_count.positive?
    end

    # all leaves accounted for without errors; all tests passed
    def success?
      !errors? && roots.all? { |n| n.ignorable? || n.nonterminal? && !n.pending_tests? }
    end

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
      return NodeIterator.new self
    end

    def clone # :nodoc:
      super.tap do |c|
        %i[@summary @size @correctness_count @pending_count].each do |v|
          c.remove_instance_variable v if c.instance_variable_get v
        end
      end
    end

    ## ADVISORILY PRIVATE

    # :stopdoc:

    def _summary=(str)
      @summary = str
    end

    def _roots=(roots)
      @roots = roots
    end

    class NodeIterator # :nodoc:
      include Enumerable

      def initialize(parse)
        @parse = parse
      end

      def each
        @parse.roots.each do |root|
          root.subtree.each { |n| yield n }
        end
      end

      def last
        @parse.roots.last.leaves.last
      end
    end
  end
end
