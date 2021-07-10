# frozen_string_literal: true

# to be regarded as a non-public class
# a Hopper keeps completed parses, dumping inferior ones as desired
# this facilitates efficient memory use and parsing
module Gullah
  class Hopper
    def initialize(filters, batch)
      @filters = filters
      @batch = batch
      @count = 0
      @thresholds = {}
      @bin = []
    end

    def <<(parse)
      return unless adequate? parse, ignore_pending: false

      @bin << parse
      if @filters.any? && (@count == @batch)
        @count + +
        filter
      end
    end

    def dump
      filter if @count.positive? && @filters.any?
      @bin
    end

    # is this parse at least as good as any in the bin?
    def adequate?(parse, ignore_pending: true)
      return true if @filters.none?

      @thresholds.each do |f, limit|
        next if ignore_pending && f == :pending

        value = case f
                when :completion
                  parse.nodes.length
                when :correctness
                  parse.nodes.select(&:failed_test).count
                when :size
                  parse.nodes.map(&:size).sum
                when :pending
                  parse.nodes.select(&:pending_tests?).count
                end
        return false if value > limit
      end
      true
    end

    private

    # set new minimal thresholds and cull the losers
    def filter
      @filters.uniq.each do |f|
        break if @bin.length == 1

        case f
        when :completion
          # find the parses with the fewest terminal nodes
          candidates = @bin.map { |p| [p, p.nodes.length] }
        when :correctness
          # find the parses with the fewest failures
          candidates = @bin.map { |p| [p, p.nodes.select(&:failed_test).count] }
        when :size
          # find the parses with the fewest nodes
          candidates = @bin.map { |p| [p, p.nodes.map(&:size).sum] }
        when :pending
          # find the parses with the fewest pending ancestor tests
          candidates = @bin.map { |p| [p, p.nodes.select(&:pending_tests?).count] }
        else
          raise Gullah::Error, "unknown filter: #{f}"
        end
        limit = candidates.map(&:last).min
        @thresholds[f] = limit
        @bin = candidates.reject { |_p, l| l > limit }.map(&:first)
      end
      set_thresholds
      @count = 0
    end

    def set_thresholds; end
  end
end
