# frozen_string_literal: true

# to be regarded as a non-public class
# a Hopper keeps completed parses, dumping inferior ones as desired
# this facilitates efficient memory use and parsing
module Gullah
  class Hopper
    def initialize(filters, batch)
      dross = filters - %i[completion correctness size pending]
      raise Error, "unknown filters: #{dross.join ', '}" if dross.any?

      # fix filter order
      @filters = %i[correctness completion size pending] & filters
      @batch = batch
      @count = 0
      @thresholds = {}
      @bin = []
      @first = true
      @seen = Set.new
    end

    def size
      @bin.length
    end
    alias length size

    def <<(parse)
      return unless adequate? parse

      @bin << parse
      @count += 1
      filter if @filters.any? && (@count == @batch)
      init_thresholds(parse) if @first
    end

    def dump
      if @count.positive? && @filters.any?
        filter
      else
        @bin.uniq!(&:summary)
      end
      @bin
    end

    # is this parse at least as good as any in the bin?
    def adequate?(parse)
      return true if @filters.none?

      @thresholds.each do |f, limit|
        value = case f
                when :completion
                  parse.length
                when :correctness
                  parse.correctness_count
                when :size
                  parse.size
                when :pending
                  parse.pending_count
                end
        return true if value < limit
        return false if value > limit
      end
      true
    end

    # is this parse worth improving further?
    def continuable?(parse)
      return false if seen?(parse)

      @seen << parse.summary
      return true if @first || @filters.none?

      @thresholds.slice(:correctness, :size).each do |f, limit|
        value = case f
                when :correctness
                  parse.correctness_count
                when :size
                  parse.size
                end
        return true if value < limit
        return false if value > limit
      end
      true
    end

    def seen?(parse)
      @seen.include? parse.summary
    end

    private

    def init_thresholds(parse)
      @filters.each do |f|
        value = case f
                when :completion
                  parse.length
                when :correctness
                  parse.correctness_count
                when :size
                  parse.size
                when :pending
                  parse.pending_count
                end
        @thresholds[f] = value
      end
      @first = false
    end

    # set new minimal thresholds and cull the losers
    def filter
      @bin.uniq!(&:summary)
      @filters.each do |f|
        break if @bin.length == 1

        case f
        when :completion
          # find the parses with the fewest terminal nodes
          candidates = @bin.map { |p| [p, p.length] }
        when :correctness
          # find the parses with the fewest failures
          candidates = @bin.map { |p| [p, p.correctness_count] }
        when :size
          # find the parses with the fewest nodes
          candidates = @bin.map { |p| [p, p.size] }
        when :pending
          # find the parses with the fewest pending ancestor tests
          candidates = @bin.map { |p| [p, p.pending_count] }
        end
        limit = candidates.map(&:last).min
        @thresholds[f] = limit
        @bin = candidates.reject { |_p, l| l > limit }.map(&:first)
      end
      @count = 0
    end
  end
end
