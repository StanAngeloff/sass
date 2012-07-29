require 'sass/tree/buffer_node'

module Sass::Tree
  # A static node representing a buffer include (flush).
  #
  # @see Sass::Tree
  class FlushNode < BufferNode
    # @see Node#bubbles?
    def bubbles?; false; end
  end
end
