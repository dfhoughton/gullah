# frozen_string_literal: true

module Gullah
  # to be regarded as a non-public class
  # a segment handles the portion of a string between boundaries
  # or a boundary itself
  class Segment # :nodoc:
    attr_reader :start, :end, :done
    attr_accessor :continuations

    def initialize(lexes, filters, starters, do_unary_branch_check, n)
      sample = lexes.first
      @start = sample.start
      @end = sample.end
      @continuations = []
      @mass = lexes.map(&:length).sum
      @done = false
      @hopper = Hopper.new(filters, n)
      @starters = starters
      @do_unary_branch_check = do_unary_branch_check
      @bases = lexes.map do |p|
        Iterator.new(p, @hopper, starters, do_unary_branch_check)
      end
    end

    def total_parses
      if @hopper.size.zero?
        0
      elsif continuations.any?
        continuations.map { |c| c.total_parses * @hopper.size }.sum
      else
        @hopper.size
      end
    end

    # used to pick the next segment to iterate
    def weight
      @mass * @hopper.size
    end

    # try to add one parse to the hopper
    # returns whether or not this succeeded
    def next
      return false if @done

      start_size = @hopper.size
      catch :done do
        while (iterator = @bases.pop)
          unless @hopper.continuable?(iterator.parse)
            @hopper << iterator.parse
            throw :done if @hopper.satisfied?

            next
          end

          if (p = iterator.next)
            @bases << iterator
            @bases << Iterator.new(p, @hopper, @starters, @do_unary_branch_check)
          elsif iterator.never_returned_any?
            # it looks this iterator was based on an unreducible parse
            @hopper << iterator.parse
            throw :done if @hopper.satisfied?
          end
        end
      end
      end_size = @hopper.size
      if end_size == start_size
        @done = true
        false
      else
        true
      end
    end

    def results
      @results ||= if continuations.any?
                     @hopper.dump.flat_map do |parse|
                       continuations.flat_map do |c|
                         c.results.flat_map do |p|
                           parse.merge(p)
                         end
                       end
                     end
                   else
                     @hopper.dump
                   end
    end
  end
end
