#!/usr/bin/env ruby
require 'test/unit'
require File.dirname(__FILE__) + '/../test_helper.rb'

require 'sass/engine'

class SassBufferTest < Test::Unit::TestCase
  def test_buffer_node
    node = Sass::Tree::BufferNode.new
    assert(node.is_a?(Sass::Tree::Node), 'BufferNode expected to inherit from Node')
    assert_respond_to(node, :name, 'BufferNode expected to include a name(..) method')
    assert_respond_to(node, :resolved_name, 'BufferNode expected to include a resolved_name(..) method to include result of interpolations')

    node = Sass::Tree::BufferNode.new('buffer')
    assert('buffer' == node.name, 'BufferNode expected to initialize @name from constructor')
    assert(node.resolved_name.nil?, 'BufferNode should not resolve interpolations on its own')

    assert_send([node, :bubbles?], 'BufferNode expected to bubble rules')
  end

  def test_flush_node
    node = Sass::Tree::FlushNode.new
    assert(node.is_a?(Sass::Tree::BufferNode), 'FlushNode expected to inherit from BufferNode')

    assert(node.bubbles? == false, 'FlushNode expected NOT to bubble rules (unlike BufferNode)')
  end
end
