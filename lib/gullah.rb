# frozen_string_literal: true

require 'set'
%w[version atom error hopper leaf node trash boundary parse rule iterator dotifier segment picker].each do |s|
  require "gullah/#{s}"
end

# A collection of class methods that can be added into a class to make it parser.
# For example:
#
#   class Foo
#     extend Gullah
#
#     rule :plugh, 'foo bar+ | bar foo{1,3}'
#     rule :foo, 'number word'
#     rule :bar, 'punctuation "wow!"'
#     leaf :word, /[a-z]+/i
#     leaf :number, /\d+(?:\.\d+)?/
#     leaf :punctuation, /[^\w\s]+/
#   end
#
# Having defined a grammar like this, one can apply it to arbitrary strings to
# generate parse trees:
#
#   Foo.parse "123 cat @#$ wow! ___wow!"
#
# Gullah can produce parse trees from incomplete or ambiguous grammars. It can handle
# noisy data. One can apply arbitrary tests to parse nodes, including tests that
# depend on other nodes in the parse tree. In the case of test failure the nature
# of the failure is marked on the corresponding nodes in the parse tree.
#
# = Syntax
#
# This second describes only the syntax of Gullah rules, not the entire API. Gullah
# syntax is generally the more familiar subset of the rules of regular expressions.
#
# - sequence
#
#     rule :foo, 'bar baz' # one thing follows another
#
# - alternation
#
#     rule :foo, 'bar | baz' # separate alternates with pipes
#     rule :foo, 'plugh+'    # or simply define it additional times (not regex grammar)
#
# - repetition
#
#     rule :option,  'foo?'     # ?     means "one or none"
#     rule :plural,  'foo+'     # +     means "one or more"
#     rule :options, 'foo*'     # *     means "zero or more"
#     rule :n,       'foo{2}'   # {n}   means "exactly n"
#     rule :n_plus,  'foo{2,}'  # {n,}  means "n or more"
#     rule :n_m,     'foo{2,3}' # {n,m} means "between n and m"
#
#   Note, though you can define rules like +option+ and +options+, a rule can't add
#   a node to the parse tree if it matches nothing. These repetition suffixes are
#   are more useful as part of a sequence. In practice <tt>foo?<tt> will be a less
#   efficient version of <tt>foo</tt>, and <tt>foo*</tt>, a less efficient version of
#   <tt>foo+</tt>.
#
# - literals
#
#     rule :foo,  '"(" bar ")"'
#
#   Literals allow you to avoid defining simple leaf rules. The above is basically
#   shorthand for
#
#     rule :foo, 'left_paren bar right_paren'
#     leaf :left_paren, /\(/
#     leaf :right_paren, /\)/
#
#   You may use either single or double quotes to define literals. You may also use
#   escape sequences to include random characters in literals. Literals may have
#   repetition suffixes.
#
# - grouping
#
#     rule :foo, 'bar baz'
#
#   Surprise! There is no grouping syntax in Gullah. Every rule is in effect a named group.
#   So it might be better said that there are no anonymous groups in Gullah and grouping
#   doesn't involve parentheses.
#
# You may be wondering about whitespace handling. See +ignore+ and +keep_whitespace+ below.
# The short version of it is that Gullah creates an ignorable whitespace leaf rule by
# default.
#
# = Preconditions
#
# The first step in adding a node to a parse tree is collecting a sequence of child
# nodes that match some rule. If the rule is
#
#   rule :foo, 'bar+'
#
# you've collected a sequence of +bar+ nodes. If there is some condition you need this
# node to respect *which is dependent only on the rule and the child nodes* which you
# can't express, or not easily, in the rule itself, you can define one or more
# preconditions. E.g.,
#
#   rule :foo, 'bar+', preconditions: %i[fibonacci]
#
#   def fibonacci(_name, _start, _end, _text, children)
#     is_fibonacci_number? children.length # assumes we've defined is_fibonacci_number?
#   end
#
# A precondition is just an instance method defined in the Gullah-fied class with an arity
# of two: it takes the rule's name, a symbol, as its first argument, and the prospective
# child nodes, an array, as its second. If it returns a truthy value, the precondition holds
# and the node can be made. Otherwise, Gullah tries the next thing.
#
# == Preconditions versus Tests
#
# Preconditions are like tests (see below). They are further conditions on the building of
# nodes in a parse tree. Why does Gullah provide both? There are several reasons:
#
# - Preconditions are tested before the node is built, avoiding the overhead of cloning
#   nodes, so they are considerably lighter-weight.
# - Because they are tested *before* the node is built, they result in no partially erroneous
#   parse in the event of failure, so they leave nothing Gullah will attempt to improve further
#   at the cost of time.
# - But they don't leave a trace, so there's nothing to examine in the event of failure.
# - And they concern only the subtree rooted at the prospective node, so they cannot express
#   structural relationships between this node and nodes which do not descend from it.
#
#   *Note*, they cannot tests relationships between *nodes* outside the prospective node's
#   subtree, but they can test its relationships to adjoining *characters*, so they can
#   implement lookarounds. For instance:
#
#     def colon_after(_rule_or_leaf_name, _start_offset, end_offset, text, _children)
#       text[end_offset..-1] =~ /\A\s*:/ # equivalent to (?=\s*:)
#     end
#
# = Tests
#
#   rule :all, 'baz+',   tests: %i[half_even]
#   rule :baz, 'foo | bar'
#
#   leaf :foo, /\d+/,    tests: %i[xenophilia]
#   leaf :bar, /[a-z]/i, tests: %i[xenophilia]
#
#   # node test!
#
#   # half the digit characters under this node must be even, half, odd
#   def half_even(node)
#     even, odd = node.text.chars.select { |c| c =~ /\d/ }.partition { |c| c.to_i.even? }
#     even.length == odd.length ? :pass : :fail
#   end
#
#   # structure test!
#
#   # foos need bars and bars need foos
#   def xenophilia(root, node)
#     if root.name == :all
#       sought = node.name == :foo ? :bar : :foo
#       root.descendants.any? { |n| n.name == sought } ? :pass : :fail
#     end
#   end
#
# A special feature of Gullah is that you can add arbitrary tests to its rules. For example
# you can use a simple regular expression to match a date and then a test to do a sanity
# check to confirm that the parts of the date, the year, month, and day, combine to produce
# a real date on the calendar. This is better than simply writing a thorough regular expression
# because it gives you the opportunity to tell the user *how* a match failed rather than simply
# that it failed. This feature is Gullah's answer to such things as lookarounds and back
# references: you've matched a simple pattern; now does this pattern fit sanely with its context?
#
# There are two sorts of tests: node tests and structure tests. Node tests are tests that need
# only the node itself and its subtree as inputs. Structure tests are tests that depend on
# elements of the parse tree outside of the subtree rooted at the node itself.
#
# Tests are implemented as instance methods of the Gullah-fied class. If the method has an arity
# of one, it is a node test. Its single argument is the node matched. If it has an arity of two,
# it is a structure test. The first argument is an ancestor node of the node corresponding to the
# rule. The second argument is the node itself. Because structure tests cannot be run until the
# node has some ancestor, and then they might not apply to all ancestors, they can be in a "pending"
# state, where the test is queued to run but has not yet run.
#
# Tests must return one of four values: +:pass+, +:fail+, +:ignore+, or +nil+. Only structure
# tests may return +nil+, which indicates that the preconditions for the test have not yet been
# met. If a structure test returns +nil+, the test remains in a pending state and it will be run
# again when the node acquires a new ancestor.
#
# If a node test passes, the node is accepted into the parse tree. If it fails, the node is marked
# as erroneous and the particular cause of its failure is marked in the abstract syntax tree. If
# this tree is returned to the user, they will see this information. In addition to +:fail+, the rule
# may return more specific explanatory information:
#
#   rule :word, /\w+/, tests: %i[we_want_foo!]
#
#   def we_want_foo!(n)
#     if n.text =~ /foo/
#       :pass
#     else
#       [:fail, %Q[we really wanted to see "foo" but all we got was #{n.text.inspect}]]
#     end
#   end
#
# The test may simply return +:fail+, or it may return a array beginning with +:fail+ and
# continuing with whatever else one wishes to stash in the +attribute+ hash of the node in
# the AST.
#
# If a node returns +:pass+, the fact that the node passed the rule in question will be added to
# its +attributes+ hash in the AST.
#
# If a rule returns +:ignore+, this will constitute a pass, but no edits will be made to the AST.
#
# Only structure rules may return +nil+. This indicates that the preconditions for the test are not
# present, in which case the test will be deferred until the node acquires a new ancestor.
#
# Tests short-circuit! If a node has many tests, they run until one fails.
#
# == Disadvantages of Tests
#
# All this being said, when tests *fail* they do so after their node has been built and added
# to a parse. This means their partially broken parse remains a candidate as Gullah tries to
# find the least bad way to parse the text it was given. This can be computationally expensive.
# If you can make do with preconditions (see above), they are the better choice.
#
# = Processors
#
#   rule :word, /[a-z]+/i, process: :abbrv
#   leaf :integer, /[1-9]\d*/, process: ->(n) { n.atts[:val] = n.text.to_i }
#
#   def abbrv(node)
#     node.attributes[:abbreviation] = node.text.gsub(/(?<!^)[aeiou]/, '')[0...5]
#   end
#
# Any rule may have a +process+ named argument whose value is either a proc or a symbol.
# If it is a symbol, it must be the name of an instance method of the Gullah-fied class.
# In either case, the arity of the code in question must be one: its single argument will
# be the node created by the rule.
#
# The processing code may do anything -- log the event, provide a breakpoint -- but its
# expected use is to calculate and store some attribute of the node or its subtree in the
# node's attribute hash, most likely to accelerate other tests that will depend on this
# value. You may use this mechanism for other purposes, of course, to compile the text
# parsed into a more useful object, say, but because processing may occur on nodes which
# are later discarded in failed parses, it may be more efficient to defer such handling
# of the AST until the parse completes.
#
# Processors run after any tests have completed and only if they all pass.
#
# = Motivation
#
# Why does Gullah exist? Well, mostly because it seemed like fun to make it. I have made
# other grammar-adjacent things -- a recursive descent parser in Java inspired by the grammars
# of Raku, various regular expression optimization libraries in various languages, a simple
# grammar-esque regular expression enhancer for Rust that produces abstract syntax trees but
# can't handle recursion -- so I was thinking about the topic. A problem I faced with the recursive
# descent parser, which I later learned was a well-known problem, is that of infinite left-recursion.
# If you have a rule such as <tt>X -> X Y | Z</tt>, where an +X+ can be made of other +X+ es, your recursive
# descent parser constructs an infinitely long plan that never touches the data -- "I'll try an X, which
# means I'll first try an X, which means I'll first try an X..." The solution to this is to create an
# arbitrary, perhaps adjustable, recursion limit, recognize this pattern of recursion, and bail out
# when you find you've planned too long without executing anything. This is how I solved the problem in
# the library I wrote, but I found this unsatisfactory.
#
# An alternative solution, it occurred to me, was to start with the data rather than the plan. "I have
# an +X+. What can I make with this?" This instantly solves the left recursion problem, because the application
# of a rule must consume nodes, and it seems like a more
# reasonable way to parse things generally. As a latent linguist, this appealed to me as more psychologically
# realistic. Certainly people understand words in part by approaching language with expectations -- the top-down
# pattern you see in recursive descent -- but people are constantly confronted with text begun in the middle or
# interrupted or repaired mid-sentence, so they must be able as well to take the words they hear and try to
# make something from them. So I wanted to make a data-driven, bottom-up parser.
#
# (One thing I should say up front is that the design of Gullah is based entirely on my own pondering. I am not
# a very enthusiastic reader of other people's research. I am aware that a lot of work has been done on
# parsing and parser design, but the fun for me is in coming up with the ideas more than doing the background
# reading, so I have just dived in. I am sure I have reinvented some wheels in this, mostly likely badly.)
#
# (Another aside: The left-recursion problem disappears with a bottom-up parser, which must consume data to proceed, but it
# is replaced with a unary-branching problem. If you have a rule that says an +A+ can be relabeled +B+ -- that
# is, you can add a node with a single child -- you risk an infinite loop. You may define rules such that +A+ becomes
# +B+, and another rule, or series of rules, which turns this +B+ back into an +A+. So this bottom-up parser has
# a somewhat unsatisfactory loop check as well, but only when it determines that some set of rules allow this pattern.)
#
# A side benefit of bottom-up parsing is that it is robust against ill-formed data. If you can't make what you
# set out to make at least you can make something. And the structure you build out of the data can show very
# clearly where it has gone wrong. As a linguist, this appealed to my desire to model natural languages with
# all their noise and redundancy. As a programmer, this appealed to me as a way to make data problems
# transparent and solvable.
#
# = Efficiency
#
# I have taken care to make rules fail fast and have followed a dynamic programming model in which I cache
# information which would otherwise be recalculated in many recursions, but Gullah is certainly not as
# efficient as a parser custom designed for a particular language. A SAX parser of XML, for example, can
# process its input in linear time by pushing half-processed constructs onto a stack. The general mechanism
# underlying Gullah is worst-case quadratic, because events already seen may have to be scanned again to
# see whether recent decisions have changed whether they can be handled. If every node added to a
# provisional parse tree reduces the unprocessed node count by one and every scan on average finishes
# halfway through the unhandled nodes, this would mean n(n - 1)/2 comparisons to complete the tree. I doubt,
# though I cannot prove, that one could improve on this while maintaining one's parser's ability to handle
# broken data or ambiguous grammars. Ranking rules to try next based on past experience in the tree
# might improve the speed of parse discovery, but at the cost of greater complexity in the handling of any
# single scan.
#
# So if you have a particular data format or language you want to handle efficiently and you expect in most
# cases you will succeed without ambiguity on a single pass, Gullah is not the tool you want. But if you
# want to recover gracefully, it may be that a second pass with Gullah to produce the least bad parse and
# some information about how things went wrong is useful.

module Gullah
  ##
  # Define a tree structure rule. This specifies how tree nodes may be grouped under
  # another node. The required arguments are +name+ and +body+. The former is a label
  # for the node under which the others are grouped. The latter is a string defining
  # the rule.
  #
  #   rule :sequence, 'this then this'
  #
  #   rule :quantifiers, 'foo bar? baz* plugh+ qux{2} quux{3,} corge{4,5}'
  #
  #   rule :alternates, 'this | or | that'
  #   # you may also add alternates like so
  #   rule :alternates, 'also | these | and | those'
  #   rule :alternates, 'etc'
  #
  #   rule :literals, %['this' "that"]
  #
  #   rule :escapes, 'foo\\? "bar\\""'
  #
  #   # the optional named arguments:
  #
  #   rule :process, 'aha', process: ->(n) { log "Aha! we just matched #{n.text}!" }
  #   rule :or_maybe, 'oho', process: :some_arity_one_method_in_class_extending_gullah
  #
  #   rule :tests, 'test me', tests: %i[node structure]
  def rule(name, body, tests: [], preconditions: [], process: nil)
    raise Error, 'tests must be an array' unless tests.is_a? Array
    raise Error, 'preconditions must be an array' unless preconditions.is_a? Array

    init
    init_check(name)
    name = name.to_sym
    body = body.to_s.strip.gsub(/\s+/, ' ')
    return if dup_check(:rule, name, body, tests + preconditions)

    tests << [process] if process
    r = Rule.new name, body, tests: tests, preconditions: preconditions
    subrules = r.subrules || [r]
    subrules.each do |sr|
      @rules << sr
      sr.starters.each do |r, n|
        (@starters[r] ||= []) << n
      end
    end
    r.literals.each do |sym|
      leaf sym.to_s, Regexp.new(quotemeta(sym.to_s))
    end
  end

  ##
  # Don't make whitespace automatically ignorable.
  #
  #   class Foo
  #     extend Gullah
  #
  #     keep_whitespace
  #
  #     rule :a, 'a+'
  #     leaf :a, /a/
  #   end
  #
  #   Foo.parse "aaa aaa"
  #
  # In this example, the parse tree would consist of two a nodes, each parent to three 'a' leaves,
  # separated by a "trash" node corresponding to the whitespace, for which no leaf rule was provided.
  def keep_whitespace
    @keep_whitespace = true
  end

  ##
  # A tokenization rule to divide the raw text into tokens to by matched by rules.
  #
  # The required arguments are a name and a regular expression. The name is what other
  # rules will refer to. The regular expression of course defines the character sequence
  # the rule matches. The more precise the regular expression the fewer false possibilities
  # Gullah will have to sort through to find the best parse(s). Boundary markers in
  # particular, +\b+ or lookarounds such as +(?<!\d)+, are helpful in this regard.
  #
  # The optional arguments are +tests+ and +process+. See +rule+ for more regarding these.
  #
  #   leaf :word, /\b\w+\b/
  #   leaf :integer, /(?<!\d)[1-9]\d*(?!=\d)/, process: ->(n) { n.atts[:val] = n.text.to_i }
  #   leaf :name, /Bob/, tests: [:not_bobbing]
  #
  #   def not_bobbing(n)
  #     /bing/.match(n.full_text, n.end) ? :fail : :pass
  #   end
  def leaf(name, rx, tests: [], preconditions: [], process: nil)
    _leaf name, rx, ignorable: false, tests: tests, process: process, preconditions: preconditions
  end

  ##
  # A tokenization rule like +leaf+, but whose tokens are invisible to other rules.
  # The +ignore+ method is otherwise identical to +leaf+.
  #
  # Unless +keep_whitespace+ is called, an +ignore+ rule covering whitespace will be
  # generated automatically. It's name will be "_ws", or, if that is taken, "_wsN", where
  # N is an integer sufficient to make this name unique among the rules of the grammar.
  def ignore(name, rx, tests: [], preconditions: [], process: nil)
    _leaf name, rx, ignorable: true, tests: tests, process: process, preconditions: []
  end

  ##
  # A tokenization rule like +leaf+, but whose tokens cannot be the children of other nodes.
  # The +ignore+ method is otherwise identical to +leaf+.
  #
  # Boundaries are extremely valuable for reducing the complexity of parsing, because Gullah
  # knows no parse can span a boundary. Trash nodes -- nodes that correspond to character
  # sequences unmatched by any leaf rule -- are also boundaries, though most likely erroneous
  # ones.
  #
  #   # clause boundary pattern
  #   boundary :terminal, /[.!?](?=\s*\z|\s+"?\p{Lu})|[:;]/
  def boundary(name, rx, tests: [], preconditions: [], process: nil)
    _leaf name, rx, boundary: true, tests: tests, preconditions: preconditions, process: process
  end

  ##
  # Obtain the set of optimal parses of the given text. Optimality is determined
  # by four criteria. In every case the smaller the number the better.
  #
  # correctness:: The count of node or structure tests that have failed.
  # completion:: The count of root nodes.
  # pending:: The count of structure tests that were not applied.
  # size:: The total number of nodes.
  #
  # You can adjust the optimality conditions only by removing them via the optional
  # +filters+ argument. If you supply this argument, only the optimality criteria you
  # specify will be applied. The order of application is fixed: if parse A is more
  # correct than parse B, it will be kept and B discarded even if B is more complete,
  # has fewer pending tests, and fewer nodes.
  #
  # The optional +n+ parameter can be used to specify the desired number of parses.
  # This is useful if your parse rules are ambiguous. For example, consider the grammar
  #
  #   class Binary
  #     extend Gullah
  #     rule :a, 'a{2}'
  #     leaf :a, /\S+/
  #   end
  #
  # If you ask this to parse the string "a b c d e f g h i j k l" it will produce
  # 58,786 equally good parses. These will consume a lot of memory and producing them
  # will consume a lot of time. The +n+ parameter will let you get on with things faster.
  #
  # A caveat: Because of the way Gullah works you may not get exactly +n+ parses
  # back when you ask for +n+. There may not be sufficiently many parses, of course, but
  # you may also get back more than +n+ parses if the text you are parsing contains
  # parsing boundaries. Gullah parses the portions of text inside the boundaries separately,
  # so the number of possible parses will be the product of the number of parses of
  # each bounded segment. If you have a sentence boundary in the middle of your text,
  # and thus two segments, the number of parses of the entire text will be the number
  # of parses of the first segment times the number of parses of the second. If the first
  # has two parses and the second also has two but you ask for 3, the number of parses
  # Gullah will find as it goes will be 1, then 2, then 4. There is no iteration of the
  # process in which Gullah has found exactly 3 parses. The 4 it has found are necessarily
  # all equally good, so rather than arbitrarily choosing 3 and discarding one, Gullah
  # will return all 4.
  def parse(text, filters: %i[correctness completion pending size], n: nil)
    raise Error, 'n must be positive' if n&.zero?

    commit
    segments = segment(text.to_s, filters, n)
    initial_segments = segments.select { |s| s.start.zero? }
    if n
      # iterate till all segments done or we get >= n parses
      # another place to start parallelization
      while (s = segments.reject(&:done).min_by(&:weight))
        break if s.next && initial_segments.sum(&:total_parses) >= n
      end
    else
      # iterate till all segments done
      # NOTE: could be parallelized
      while (s = segments.find { |s| !s.done })
        s.next
      end
    end
    if segments.length > 1
      # pass the results through a new hopper to filter out duds
      hopper = Hopper.new filters, nil
      initial_segments.flat_map(&:results).each { |p| hopper << p }
      hopper.dump.each(&:initialize_summaries)
    else
      segments.first.results
    end
  end

  ##
  # The first parse found. This takes the same arguments as +parse+ minus +n+.
  # If there are no parses without errors or unsatisfied pending tree structure
  # tests, it will be the first erroneous or incomplete parse.
  #
  # If you expect the parse to succeed and be unambiguous, this is the method you
  # want.
  def first(text, filters: %i[correctness completion pending size])
    parse(text, filters: filters, n: 1).first
  end

  # :stopdoc:

  private

  def init
    return if @rules

    @rules = []
    @leaves = []
    @starters = {}
    @tests = {}
    @preconditions = {}
    @committed = false
    @do_unary_branch_check = nil
  end

  # do some sanity checking, initialization, and optimization
  def commit
    return if @committed
    raise Error, "#{name} has no leaves" unless @leaves&.any?

    # add the whitespace rule unless told otherwise
    if @keep_whitespace
      remove_instance_variable :@keep_whitespace
    else
      used_rules = (@rules.map(&:name) + @leaves.map(&:name)).to_set
      base = '_ws'
      count = nil
      count = count.to_i + 1 while used_rules.include? "#{base}#{count}".to_sym
      _leaf "#{base}#{count}".to_sym, /\s+/, ignorable: true
    end

    # vet on commit so rule definition is order-independent
    [@leaves, @rules].flatten.each do |r|
      vetted_tests = r.tests.map { |t| vet t }
      vetted_preconds = r.preconditions.map { |pc| vet_precondition pc }
      r._post_init(vetted_tests, vetted_preconds)
    end
    completeness_check
    loop_check
    # arrange things so we first try rules that can complete more of the parse;
    # better would be sorting by frequency in parse trees, but we don't have
    # that information
    @starters.transform_values { |atoms| atoms.sort_by(&:max_consumption).reverse }
    remove_instance_variable :@leaf_dup_check if @leaf_dup_check
    remove_instance_variable :@rule_dup_check if @rule_dup_check
    @committed = true
  end

  # has every rule/leaf required by some rule been defined?
  def completeness_check
    available = (@rules + @leaves).map(&:name).to_set
    sought = @rules.flat_map(&:seeking).uniq.to_set
    problems = sought.reject { |s| available.include? s }
    raise Error, "the following rules or leaves remain undefined: #{problems.join(', ')}" if problems.any?
  end

  # define the @do_unary_branch_check variable
  def loop_check
    @do_unary_branch_check = false
    links = @rules.select(&:potentially_unary?).flat_map(&:branches).uniq
    if links.any?
      potential_loops = links.map { |l| LoopCheck.new l }
      catch :looped do
        while potential_loops.any?
          new_potential_loops = []
          links.each do |l|
            potential_loops.each do |pl|
              if (npl = pl.add(l, self))
                new_potential_loops << npl
              end
            end
          end
          potential_loops = new_potential_loops
        end
      end
    end
  end

  class LoopCheck
    def initialize(link)
      @seen = Set.new(link)
      @seeking = link.last
    end

    def add(link, grammar)
      if @seeking == link.first
        if @seen.include? link.last
          grammar.instance_variable_set :@do_unary_branch_check, true
          throw :looped
        end
        LoopCheck.new(@seen.to_a + [link.last])
      end
    end
  end

  def init_check(name)
    raise Error, "cannot define #{name}; all rules must be defined before parsing" if @committed
  end

  # a tokenization rule to divide the raw text into tokens and separators ("ignorable" tokens)
  def _leaf(name, rx, ignorable: false, boundary: false, tests: [], preconditions: [], process: nil)
    raise Error, 'tests must be an array' unless tests.is_a? Array
    raise Error, 'preconditions must be an array' unless preconditions.is_a? Array

    init
    init_check(name)
    name = name.to_sym
    return if dup_check(:leaf, name, rx, tests + preconditions)

    tests << [process] if process
    @leaves << Leaf.new(name, rx, ignorable: ignorable, boundary: boundary, tests: tests, preconditions: preconditions)
  end

  # convert raw text into one or more arrays of leaf nodes -- maximally unreduced parses
  def lex(text)
    bases = [[0, Parse.new(text)]]
    done = []
    while bases.any?
      offset, parse = bases.shift
      added_any = false
      @leaves.each do |leaf|
        # can this leaf rule extract a leaf at this offset?
        next unless (md = leaf.rx.match(text, offset)) && md.begin(0) == offset

        e = md.end(0)
        next if leaf.preconditions.any? { |pc| pc.call(leaf.name, offset, e, text, []) == :fail }

        added_any = true
        new_parse = parse.add(offset, e, leaf, @do_unary_branch_check, false, leaf.boundary)
        if e == text.length
          done << new_parse
        else
          bases << [e, new_parse]
        end
      end
      next if added_any

      # try to eliminate trash
      trash_offset = text.length
      @leaves.each do |leaf|
        # is there a leaf like this closer to the current offset?
        next unless
          (md = leaf.rx.match(text, offset)) &&
          (b = md.begin(0)) &&
          (b < trash_offset) &&
          (e = md.end(0)) &&
          leaf.preconditions.none? { |pc| pc.call(leaf.name, b, e, text, []) == :fail }

        trash_offset = b
      end
      new_parse = parse.add(offset, trash_offset, trash_rule, false, true)
      if trash_offset == text.length
        done << new_parse
      else
        bases << [trash_offset, new_parse]
      end
    end
    done # an array of Parses
  end

  # slice text into independent segments
  def segment(text, filters, n)
    uncollected_segments = lex(text).flat_map(&:split)
    segments = uncollected_segments.group_by { |s| [s.start, s.end] }.values.map do |segs|
      Segment.new segs, filters, @starters, @do_unary_branch_check, n
    end
    segments.group_by(&:end).each do |final_offset, segs|
      continuations = segments.select { |s| s.start == final_offset }
      segs.each { |s| s.continuations = continuations }
    end
    segments
  end

  def trash_rule
    @trash_rule ||= Leaf.new(:"", nil)
  end

  def singleton
    @singleton ||= new
  end

  # check for duplicate rule/leaf
  # return true if perfect duplicate, false if novel
  def dup_check(type, name, body, tests)
    set = type == :leaf ? (@leaf_dup_check ||= ::Set.new) : (@rule_dup_check ||= ::Set.new)
    key = [name, body, tests.sort]
    if set.include? key
      true
    else
      set << key
      false
    end
  end

  # vet tests
  def vet(test)
    if test.is_a? Array
      # this is a processing function, not a real test
      return procify(test.first)
    end

    @tests[test] ||= begin
      begin
        m = singleton.method(test)
      rescue ::NameError
        raise Error, "#{test} is not defined"
      end
      raise Error, "#{test} must take either one or two arguments" unless (1..2).include? m.arity

      m
    end
  end

  # vet preconditions
  def vet_precondition(precond)
    @preconditions[precond] ||= begin
      begin
        m = singleton.method(precond)
      rescue ::NameError
        raise Error, "#{precond} is not defined"
      end
      raise Error, <<-MESSAGE.strip.gsub(/\s+/, ' ') unless m.arity == 5
        #{precond} must take four arguments:
          the rule or leaf name,
          the start character offset,
          the end character offset,
          the text being parsed,
          and the prospective children
      MESSAGE

      m
    end
  end

  # escape a string literal for use in a regex
  def quotemeta(str)
    quoted = ''
    (0...str.length).each do |i|
      c = str[i]
      quoted += '\\' if c =~ /[{}()\[\].?+*\\^$]/
      quoted += c
    end
    quoted
  end

  def procify(processor)
    case processor
    when Symbol
      @tests[processor] ||= begin
        begin
          m = singleton.method(processor)
        rescue ::NameError
          raise Error, "#{processor} is not defined"
        end
        raise Error, "#{processor} can only take a single argument" unless m.arity == 1

        lambda { |n|
          m.call(n) unless n.error?
          return :ignore
        }
      end
    when Proc
      lambda { |n|
        processor.call(n) unless n.error?
        return :ignore
      }
    else
      raise Error, 'a node processor can only be a proc or a symbol'
    end
  end
end
