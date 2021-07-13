# frozen_string_literal: true

module Gullah
  # a minimal rule fragment; this is where the actual matching occurs
  class Atom
    attr_reader :seeking, :min_repeats, :max_repeats, :parent, :next # the type of node sought

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

      @seeking = rule.to_sym

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
      return nil if offset >= nodes.length

      count = 0
      nodes[offset...nodes.length].each_with_index do |n, i|
        next if n.ignorable?

        return returnable(nodes, i + offset + 1) if count == max_repeats

        if !n.failed_test && n.name == seeking
          count += 1
          return returnable(nodes, i + offset + 1) if count == max_repeats

          next
        end

        return count >= min_repeats ? returnable(nodes, i + offset) : nil
      end
      count < min_repeats ? nil : returnable(nodes, nodes.length) # all nodes were consumed
    end

    private

    def returnable(nodes, offset)
      if self.next
        self.next.match(nodes, offset)
      else
        offset
      end
    end
  end
end
