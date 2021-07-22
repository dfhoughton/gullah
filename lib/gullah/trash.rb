# frozen_string_literal: true

module Gullah
  # a node just for trash
  class Trash < Node # :nodoc:
    # does this node represent a character sequence no leaf rule matched?
    def trash?
      true
    end
  end
end
