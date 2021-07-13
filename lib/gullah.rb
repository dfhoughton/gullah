# frozen_string_literal: true

%w[version atom error hopper leaf node trash parse rule].each { |s| require "gullah/#{s}" }

module Gullah
  # create a rule in an extending class
  #
  # rule :noun, "det n_bar"
  def rule(name, body, tests: [])
    init
    init_check(name)
    name = name.to_sym
    body = body.to_s.strip.gsub(/\s+/, ' ')
    return if dup_check(:rule, name, body, tests)

    r = Rule.new name, body, tests: tests
    subrules = r.subrules || [r]
    subrules.each do |sr|
      @rules << sr
      sr.starters.each do |r, n|
        (@starters[r] ||= []) << n
      end
    end
  end

  # a tokenization rule to divide the raw text into tokens and separators ("ignorable" tokens)
  def leaf(name, rx, ignorable: false, tests: [])
    init
    init_check(name)
    name = name.to_sym
    return if dup_check(:leaf, name, rx, tests)

    @leaves << Leaf.new(name, rx, ignorable: ignorable, tests: tests)
  end

  def parse(text, filters: %i[correctness completion pending size], batch: 10)
    commit
    bases = lex(text)
    hopper = Hopper.new(filters, batch)
    while (parse = bases.pop) # use stack for depth-first parsing
      next unless hopper.adequate?(parse)

      any_found = false
      parse.nodes.each_with_index do |n, i|
        next unless (rules = @starters[n.name])

        rules.each do |a|
          next unless (offset = a.match(parse.nodes, i))

          if (p = parse.add(i, offset, a.parent, @do_unary_branch_check))
            any_found = true
            bases.push p if hopper.adequate?(p)
          end
        end
      end
      hopper << parse unless any_found
    end
    hopper.dump
  end

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

  # do some sanity checking and initialization
  def commit
    return if @committed
    raise Error, "#{name} has no leaves" unless @leaves&.any?

    # vet on commit so rule definition is order-independent
    [@leaves, @rules].flatten.each do |r|
      vetted_tests = r.tests.map { |t| vet t }
      r.instance_variable_set :@tests, vetted_tests
      r.post_init
    end
    completeness_check
    loop_check
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
          done << new_parse
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
        done << new_parse
      else
        bases << [trash_offset, new_parse]
      end
    end
    done
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
end
