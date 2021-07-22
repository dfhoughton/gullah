# frozen_string_literal: true

module Gullah
  # a node just for trash
  class Boundary < Node # :nodoc:
    # is this node something that cannot be the child of another node?
    def boundary?
      true
    end
  end
end
