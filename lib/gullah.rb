# frozen_string_literal: true

%w[version atom error hopper leaf node trash parse rule iterator dotifier].each do |s|
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
module Gullah
  # create a rule in an extending class
  #
  # rule :noun, "det n_bar"
  def rule(name, body, tests: [], process: nil)
    init
    init_check(name)
    name = name.to_sym
    body = body.to_s.strip.gsub(/\s+/, ' ')
    return if dup_check(:rule, name, body, tests)

    tests << [process] if process
    r = Rule.new name, body, tests: tests
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
  def leaf(name, rx, tests: [], process: nil)
    _leaf name, rx, ignorable: false, tests: tests, process: process
  end

  ##
  # A tokenization rule like +leaf+, but whose tokens are invisible to other rules.
  # The +ignore+ method is otherwise identical to +leaf+.
  #
  # Unless +keep_whitespace+ is called, an +ignore+ rule covering whitespace will be
  # generated automatically. It's name will be "_ws", or, if that is taken, "_wsN", where
  # N is an integer sufficient to make this name unique among the rules of the grammar.
  def ignore(name, rx, tests: [], process: nil)
    _leaf name, rx, ignorable: true, tests: tests, process: process
  end

  def parse(text, filters: %i[correctness completion pending size], n: nil)
    commit
    hopper = Hopper.new(filters, n)
    bases = lex(text).map do |p|
      Iterator.new(p, hopper, @starters, @do_unary_branch_check)
    end
    while (iterator = bases.pop)
      unless hopper.continuable?(iterator.parse)
        hopper << iterator.parse
        return hopper.dump if hopper.satisfied?

        next
      end

      if (p = iterator.next)
        bases << iterator
        bases << Iterator.new(p, hopper, @starters, @do_unary_branch_check)
      elsif iterator.never_returned_any?
        # it looks this iterator was based on an unreducible parse
        hopper << iterator.parse
        return hopper.dump if hopper.satisfied?
      end
    end
    hopper.dump
  end

  # :stopdoc:

  private

  def init
    return if @rules

    @rules = []
    @leaves = []
    @starters = {}
    @tests = {}
    @committed = false
    @do_unary_branch_check = nil
  end

  # do some sanity checking, initialization, and optimization
  def commit
    return if @committed
    raise Error, "#{name} has no leaves" unless @leaves&.any?

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
      r._post_init(vetted_tests)
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
  def _leaf(name, rx, ignorable: false, tests: [], process: nil)
    init
    init_check(name)
    name = name.to_sym
    return if dup_check(:leaf, name, rx, tests)

    tests << [process] if process
    @leaves << Leaf.new(name, rx, ignorable: ignorable, tests: tests)
  end

  # convert raw text into one or more strings of leaf nodes
  def lex(text)
    bases = [[0, Parse.new(text)]]
    done = []
    while bases.any?
      offset, parse = bases.shift
      added_any = false
      @leaves.each do |leaf|
        # can this leaf rule extract a leaf at this offset?
        next unless (md = leaf.rx.match(text, offset)) && md.begin(0) == offset

        added_any = true
        e = md.end(0)
        new_parse = parse.add(offset, e, leaf, @do_unary_branch_check)
        if e == text.length
          done << initialize_summaries(new_parse)
        else
          bases << [e, new_parse]
        end
      end
      next if added_any

      # try to eliminate trash
      trash_offset = text.length
      @leaves.each do |leaf|
        if (md = leaf.rx.match(text, offset)) && (md.begin(0) < trash_offset)
          trash_offset = md.begin(0)
        end
      end
      new_parse = parse.add(offset, trash_offset, trash_rule, false, true)
      if trash_offset == text.length
        done << initialize_summaries(new_parse)
      else
        bases << [trash_offset, new_parse]
      end
    end
    done
  end

  # it would be conceptually simpler to lazily initialize summaries, but this
  # gives us a speed boost
  def initialize_summaries(parse)
    summary = parse.roots.each { |n| n._summary = n.name }.map(&:summary).join(';')
    parse._summary = summary
    parse
  end

  def trash_rule
    @trash_rule ||= Leaf.new(:"", nil, ignorable: true)
  end

  def singleton
    @singleton ||= new
  end

  # check for duplicate rule/leaf
  # return true if perfect duplicate, false if novel
  def dup_check(type, name, body, tests)
    set = type == :leaf ? (@leaf_dup_check ||= Set.new) : (@rule_dup_check ||= Set.new)
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
      raise Error, "#{test} must take either 1 or two arguments" unless (1..2).include? m.arity

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

# TODOS
#
# sausagify the parsing; boundary
