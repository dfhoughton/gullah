# frozen_string_literal: true

module Gullah
  # a Hopper keeps completed parses, deleting inferior ones as better parses are found
  # this facilitates efficient memory use and parsing
  # @private
  class Hopper # :nodoc:
    def initialize(filters, number_sought)
      dross = filters - %i[completion correctness size pending]
      raise Error, "unknown filters: #{dross.join ', '}" if dross.any?

      # fix filter order
      @filters = %i[correctness completion size pending] & filters
      @number_sought = number_sought
      @thresholds = {}
      @bin = []
      @first = true
      @seen = Set.new
    end

    def size
      @bin.length
    end
    alias length size

    def satisfied?
      if @bin.length == @number_sought
        limits = @thresholds.values_at(:correctness, :pending).compact
        if limits.any? && limits.all?(&:zero?)
          # we could have accumulated some dross
          @bin.uniq!(&:summary)
          @bin.length == @number_sought
        end
      end
    end

    def <<(parse)
      if @bin.empty?
        set_thresholds parse
      else
        return unless adequate? parse
      end

      @bin << parse
    end

    def dump
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
                  parse.incorrectness_count
                when :size
                  parse.size
                when :pending
                  parse.pending_count
                end
        if value < limit
          # we have a new champion!
          set_thresholds(parse)
          @bin.select! { |p| adequate? p }
          return true
        end
        return false if value > limit
      end
      true
    end

    # is this parse worth improving further?
    def continuable?(parse)
      return true if @first || @filters.none?

      @thresholds.slice(:correctness, :size).each do |f, limit|
        # completion is more important than size, so ignore size unless we have
        # a single complete parse already
        # TODO if we *do* have a single completed parse, we should throw in more tests
        next if f == :size && @thresholds[:completion]&.>(1)

        value = case f
                when :correctness
                  parse.incorrectness_count
                when :size
                  parse.size
                end
        return true if value < limit
        return false if value > limit
      end
      true
    end

    def vet(parse, i, offset, rule, do_unary_branch_check)
      preconditions_satisfied = rule.preconditions.all? do |pc|
        # at this point, any prospective node will be non-terminal
        kids = parse.roots[i...offset]
        pc.call rule.name, kids.first.start, kids.last.end, kids.first.text, kids
      end
      return unless preconditions_satisfied

      candidate = "#{rule.name}[#{parse.roots[i...offset].map(&:summary).join(',')}]"
      unvetted_summary = [
        parse.roots[0...i].map(&:summary) +
          [candidate] +
          parse.roots[offset..].map(&:summary)
      ].join(';')
      unless @seen.include? unvetted_summary
        @seen << unvetted_summary
        parse.add(i, offset, rule, do_unary_branch_check).tap do |new_parse|
          if new_parse
            new_parse._summary = unvetted_summary
            new_parse.roots[i]._summary = candidate
          end
        end
      end
    end

    private

    def set_thresholds(parse)
      @filters.each do |f|
        value = case f
                when :completion
                  parse.length
                when :correctness
                  parse.incorrectness_count
                when :size
                  parse.size
                when :pending
                  parse.pending_count
                end
        @thresholds[f] = value
      end
      @first = false
    end
  end
end
