# frozen_string_literal: true

# a node just for trash
module Gullah
  class Trash < Node

    def initialize(*args)
      super
      # redundant, but maybe helpful in debugging
      attributes[:trash] = true
    end

    # does this node represent a character sequence no leaf rule matched?
    def trash?
      true
    end

  end
end
