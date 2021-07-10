# frozen_string_literal: true

# a minimal rule fragment; this is where the actual matching occurs 
module Gullah
  class Atom
    attr_reader :seeking # the type of node sought
    attr_reader :min_repeats
    attr_reader :max_repeats
    attr_reader :parent
    attr_reader :next

    def initialize(atom, parent)
      @parent = parent
      rule, suffix = /\A([a-zA-Z_]+)([?+!]|\{\d+(?:,\d*)?\})\z/.match(atom)&.captures
      raise Gullah::Error.new("cannot parse #{atom}") unless rule

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
              if max < min
                raise Gullah::Error.new("cannot parse #{atom}: #{min} is greater than #{max}")
              end
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
      min_repeats > 0
    end

    # returns the new offset, or nil if the atom doesn't match
    def match(nodes, offset)
      return nil if offset >= nodes.length

      count = 0
      nodes[offset..].each_with_index do |n,i|
        next if n.ignorable?

        return returnable(nodes, i + offset) if i == max_repeats

        if !n.failed_test && n.name == seeking
          count++
          return returnable(nodes, i + offset) if count == max_repeats

          next
        end

        if count >= min_repeats
          return returnable(nodes, i + offset - 1)
        else
          return nil
        end
      end
      return returnable(nodes, nodes.length) # all nodes were consumed
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
