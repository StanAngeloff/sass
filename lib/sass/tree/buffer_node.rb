require 'sass/tree/node'

module Sass::Tree
  # A dynamic node representing a buffer group.
  # `@buffer` directives, when nested within rules, bubble up to the top-level.
  #
  # @see Sass::Tree
  class BufferNode < Node
    # The buffer name.
    # @return [String]
    attr_accessor :name

    # The name for this buffer, without any unresolved interpolation.
    # It's only set once {Tree::Visitors::Perform} has been called.
    #
    # @return [String]
    attr_accessor :resolved_name

    # @param name [String] The buffer name
    def initialize(name = nil)
      @name = name
      super()
    end

    # @see Node#bubbles?
    def bubbles?; true; end
  end
end
