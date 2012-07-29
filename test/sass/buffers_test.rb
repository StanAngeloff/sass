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

  def test_sass_parser
    assert_has_node(:sass, :buffer, "html\nhello->\nbody")
    assert_has_node(:sass, :buffer, "html\nhello ->\nbody")
    assert_has_node(:sass, :buffer, "html\n@buffer hello\nbody")

    assert_has_node(:sass, :flush, "html\n<-flush\nbody")
    assert_has_node(:sass, :flush, "html\n<- flush\nbody")
    assert_has_node(:sass, :flush, "html\n@flush flush\nbody")

    assert_parser_fails(:sass, :buffer,
      [[MiniTest::Assertion, [
         "html\nhello >\nbody",
         "html\n@bufferhello\nbody",
         # NOTE: hello --> is OK and would be interpreted as buffer 'hello -'.

         "html\n< flush\nbody",
         "html\n@flushhello\nbody"]],
       [Sass::SyntaxError, [
         "html\n@buffer\nbody",
         "html\n@flush\nbody"]]
      ]
    )

    assert_interpolated_name(:sass, :buffer, "html\n\#{ $dynamic + '-value' }-name ->\nbody")
    assert_interpolated_name(:sass, :flush,  "html\n<- \#{ $dynamic + '-value' }-name\nbody")
  end

  def test_scss_parser
    [:buffer, :flush].each {|d| assert(Sass::SCSS::Parser::DIRECTIVES.include?(d), "expected SCSS parser directives to include @#{d.to_s}") }

    assert_has_node(:scss, :buffer, "html { }\n@buffer hello;\nbody { }")
    assert_has_node(:scss, :buffer, "html { }\n@buffer hello { };\nbody { }")

    assert_has_node(:scss, :flush,  "html { }\n@flush hello;\nbody { }")

    assert_parser_fails(:scss, :buffer,
      [[MiniTest::Assertion, [
         "html { }\n@bufferhello;\nbody { }",
         "html { }\n@flushhello;\nbody { }"]],
       [Sass::SyntaxError, [
         "html { }\n@buffer;\nbody { }",
         "html { }\n@flush;\nbody { }",
         "html { }\n@flush hello { };\nbody { }"]]
      ]
    )

    assert_interpolated_name(:scss, :buffer, "html { }\n@buffer \#{ $dynamic + '-value' }-name { }\nbody { }")
    assert_interpolated_name(:scss, :flush,  "html { }\n@flush \#{ $dynamic + '-value' }-name;\nbody { }")
  end

  private

  def assert_has_node(mode, type, code)
    case mode
    when :sass
      tree = Sass::Engine.new(code, :quiet => true).to_tree
    when :scss
      tree = Sass::SCSS::Parser.new(code, 'test.scss').parse
    else
      raise "Unsupported mode '#{mode.to_s}'"
    end
    assert(tree.is_a?(Sass::Tree::RootNode), "expected code '#{code}' to produce a 'RootNode' object after parsing, got '#{tree.inspect}'")
    assert(tree.children.length > 0, "expected code '#{code}' to produce children for 'RootNode' after parsing, got '#{tree.inspect}'")
    klass = Sass::Tree.const_get("#{type.to_s.capitalize}Node")
    node = tree.children.find {|c| c.is_a?(klass)}
    assert(!node.nil?, "expected code '#{code}' to produce child of type '#{klass.to_s},' got '#{tree.inspect}'")
    node
  end

  def assert_interpolated_name(*args)
    node = assert_has_node(*args)
    op = node.name.find {|n| !n.is_a?(String)}
    assert(!op.nil?, "expected name to accept interpolations")
  end

  def assert_parser_fails(mode, type, tests)
    tests.each do |klass, samples|
      samples.each do |code|
        assert_raise klass, "expected broken syntax '#{code}' NOT to parse" do
          assert_has_node(mode, type, code)
        end
      end
    end
  end
end
