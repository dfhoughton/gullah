# frozen_string_literal: true

module Gullah
  # a minimal rule fragment; this is where the actual matching occurs
  # @private
  class Atom # :nodoc:
    attr_reader :seeking, :min_repeats, :max_repeats, :parent, :next, :literal

    def initialize(atom, parent)
      @parent = parent
      rule, suffix =
        /\A
          (
            (?:[a-zA-Z_]|\\.)(?:\w|\\.)* # decent identifier, maybe with escaped bits
            |
            "(?:[^"\\]|\\.)+"        # double-quoted string, maybe with escaped characters
            |
            '(?:[^'\\]|\\.)+''       # single-quoted string, maybe with escaped characters
          )
          ([?*+!]|\{\d+(?:,\d*)?\})? # optional repetition suffix
        \z/x
        .match(atom)&.captures
      raise Error, "cannot parse #{atom}" unless rule

      @literal = rule[0] =~ /['"]/
      @seeking = clean(rule).to_sym

      if suffix
        case suffix[0]
        when '?'
          @min_repeats = 0
          @max_repeats = 1
        when '+'
          @min_repeats = 1
          @max_repeats = Float::INFINITY
        when '*'
          @min_repeats = 0
          @max_repeats = Float::INFINITY
        else
          min, comma, max = /(\d+)(?:(,)(\d+)?)?/.match(suffix).captures
          min = min.to_i
          @min_repeats = min
          if comma
            if max
              max = max.to_i
              raise Error, "cannot parse #{atom}: #{min} is greater than #{max}" if max < min

              @max_repeats = max
            else
              @max_repeats = Float::INFINITY
            end
          else
            @max_repeats = min
          end
        end
      else
        @min_repeats = @max_repeats = 1
      end
    end

    # whether this atom must match at least once
    def required?
      min_repeats.positive?
    end

    # returns the new offset, or nil if the atom doesn't match
    def match(nodes, offset)
      if offset >= nodes.length
        return min_repeats.zero? ? offset : nil
      end

      count = 0
      nodes[offset...nodes.length].each_with_index do |n, i|
        next if n.ignorable?

        return returnable(nodes, i + offset + 1) if count == max_repeats

        if n.traversible? && n.name == seeking
          count += 1
          return returnable(nodes, i + offset + 1) if count == max_repeats

          next
        end

        return count >= min_repeats ? returnable(nodes, i + offset) : nil
      end
      count < min_repeats ? nil : returnable(nodes, nodes.length) # all nodes were consumed
    end

    # used to order rules so greedier ones go first
    def max_consumption
      @max_consumption ||= begin
        augment = max_repeats == Float::INFINITY ? 10 : max_repeats
        self.next&.max_consumption.to_i + augment
      end
    end

    ## ADVISORILY PRIVATE

    def _next=(nxt)
      @next = nxt
    end

    private

    def returnable(nodes, offset)
      if self.next
        self.next.match(nodes, offset)
      else
        offset
      end
    end

    # remove quotes and escapes
    def clean(str)
      str = str[1...(str.length - 1)] if literal
      escaped = false
      cleaned = ''
      (0...str.length).each do |i|
        c = str[i]
        if escaped
          cleaned += c
          escaped = false
        elsif c == '\\'
          escaped = true
        else
          cleaned += c
        end
      end
      cleaned
    end
  end
end
