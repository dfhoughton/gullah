# frozen_string_literal: true

module Gullah

  # create a rule in an extending class
  #
  # rule :noun, "det n_bar"
  def rule(name, body, tests: [])
    init
    init_check(name)
    name = name.to_sym
    @any_parent_tests ||= !parent_test.nil?
    raise Error, "#{name} is already a leaf; it cannot be a rule" unless validate(name)

    r = Rule.new name, body, self, tests: tests
    @rules << r
    r.starters.each do |r, n|
      (@starters[r] ||= []) << n
    end
  end

  # a tokenization rule to divide the raw text into tokens and separators ("ignorable" tokens)
  def leaf(name, rx, ignorable: false, tests: [])
    init
    init_check(name)
    name = name.to_sym
    raise Error, "#{name} is already a rule; it cannot be a leaf" unless validate(name, is_rule: false)

    @leaves << Leaf.new name, rx, ignorable: ignorable, tests: tests
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
          if (offset = a.match(parse.nodes, i))
            any_found = true
            parse = parse.add(i, offset, a.parent, @do_unary_branch_check)
            if hopper.adequate?(parse)
              bases.push parse
            end
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
    raise Error, "#{name} has no rules" if @rules.empty?
    raise Error, "#{name} has no leaves" if @leaves.empty?
    # vet on commit so rule definition is order-independent
    [@leaves, @rules].flatten.each do |r|
      vetted_tests = r.tests.map { |t| vet t }
      r.instance_variable_set :@tests vetted_tests
    end
    @any_parent_tests = @tests.values.any?{ |m| m.arity == 2 }
    loop_check
    @committed = true
  end

  # define the @do_unary_branch_check variable
  def loop_check
    @do_unary_branch_check = false
    links = @rules.select(&:potentially_unary?).flat_map(&:branches).uniq
    if links.any?
      potential_loops = links.map { |l| LoopCheck.new l }
      while potential_loops.any? do
        new_potential_loops = []
        links.each do |l|
          potential_loops.each do |pl|
            if (npl = pl.add(l))
              new_potential_loops << npl
            end
          end
        end
        potential_loops = new_potential_loops
      catch :looped
        @do_unary_branch_check = true
      end
    end
  end

  class LoopCheck
    def initialize(link)
      @seen = Set.new(link)
      @seeking = link.last
    end
    def add(link)
      if seeking == link.first
        throw :looped if @seen.include? link.last
        LoopCheck.new(@seen.to_a + [link.last])
      end
    end
  end

  def init_check(name)
    if @initialized
      raise Gullah::Error.new("cannot define #{name}; all rules must be defined before parsing")
    end
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
        new_parse = parse.add(offset, e, leaf)
        if e == text.length
          done << new_parse
        else
          bases << [e, new_parse]
        end
      end
      unless added_any
        # try to eliminate trash
        trash_offset = text.length
        @leaves.each do |leaf|
          if (md = leaf.rx.match(text, offset)) && (md.begin(0) < trash_offset)
            trash_offset = md.begin(0)
          end
        end
        new_parse = parse.add(offset, e, trash_rule)
        if trash_offset == text.length
          done << new_parse
        else
          bases << [trash_offset, new_parse]
        end
      end
    end
  end

  def trash_rule
    @trash_rule ||= Rule.new(:"?", nil)
  end

  def validate(name, is_rule: true)
    @rules ||= Set.new
    @leaves ||= Set.new
    if (is_rule ? @leaves : @rules).include?(name)
      false
    else
      (is_rule ? @rules : @leaves) << name
      true
    end
  end

  def singleton
    @singleton ||= new
  end

  # vet tests
  def vet(test)
    @tests[test] ||= begin
      m = singleton.method(test)
      case m&.arity
      when nil
        raise Error.new("#{test} is not defined")
      when 1, 2
        # acceptable
      else
        raise Error.new("#{test} must take either 1 or two arguments")
      end
      m 
    end
  end
end

%w[ atom error hopper leaf node parse rule ].each { |s| require "gullah/#{s}" }
