#!/usr/bin/env ruby
require 'test/unit'
require File.dirname(__FILE__) + '/../test_helper.rb'

require 'sass/engine'

class SassBufferTest < Test::Unit::TestCase
  def test_buffer_node
    node = Sass::Tree::BufferNode.new
    assert_kind_of(Sass::Tree::Node, node, 'BufferNode expected to inherit from Node')
    assert_respond_to(node, :name, 'BufferNode expected to include a name(..) method')
    assert_respond_to(node, :resolved_name, 'BufferNode expected to include a resolved_name(..) method to include result of interpolations')

    node = Sass::Tree::BufferNode.new('buffer')
    assert_equal('buffer', node.name, 'BufferNode expected to initialize @name from constructor')
    assert_nil(node.resolved_name, 'BufferNode should not resolve interpolations on its own')

    assert_send([node, :bubbles?], 'BufferNode expected to bubble rules')
  end

  def test_flush_node
    node = Sass::Tree::FlushNode.new
    assert_kind_of(Sass::Tree::BufferNode, node, 'FlushNode expected to inherit from BufferNode')

    assert_equal(false, node.bubbles?, 'FlushNode expected NOT to bubble rules (unlike BufferNode)')
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
    [:buffer, :flush].each {|d| assert_includes(Sass::SCSS::Parser::DIRECTIVES, d, "expected SCSS parser directives to include @#{d.to_s}") }

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

  def test_environment
    env = Sass::Environment.new

    assert_respond_to(env, :buffer, 'Environment expected to include a buffer(..) method')
    assert_respond_to(env, :append_buffer, 'Environment expected to include an append_buffer(..) method')

    buff = env.buffer('hello')
    assert_nil(buff, 'expected clean environment to have NO buffers')
    env.append_buffer('hello', 'World!')
    buff = env.buffer('hello')
    refute_nil(buff, 'expected environment to contain appended item')
    assert_instance_of(Array, buff, 'expected environment to put buffer items in an Array')
    assert_equal(1, buff.length, 'expected buffer length to be 1, i.e., the number of times append_buffer(..) was called')

    env.append_buffer('hello', 'We meet again!')
    buff = env.buffer('hello')
    assert_equal(2, buff.length, 'expected buffer length to be 2, i.e., the number of times append_buffer(..) was called')

    assert_equal(['World!', 'We meet again!'], buff, 'expected buffer contents to match appended items')

    child = Sass::Environment.new(env)
    buff2 = child.buffer('hello')
    assert_same(buff, buff2, 'expected child Environment to inherit buffers from parent')

    child.append_buffer('hello', 'final')
    buff = env.buffer('hello')
    assert_equal(3, buff.length, 'expected child append_buffer(..) call to delegate to parent')

    neighbor = Sass::Environment.new
    buff = neighbor.buffer('hello')
    assert_nil(buff, 'expected neighboring Environment to be separate')
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
    assert_instance_of(Sass::Tree::RootNode, tree, "expected code '#{code}' to produce a 'RootNode' object after parsing, got '#{tree.inspect}'")
    assert(tree.children.length > 0, "expected code '#{code}' to produce children for 'RootNode' after parsing, got '#{tree.inspect}'")
    klass = Sass::Tree.const_get("#{type.to_s.capitalize}Node")
    node = tree.children.find {|c| c.is_a?(klass)}
    refute_nil(node, "expected code '#{code}' to produce child of type '#{klass.to_s},' got '#{tree.inspect}'")
    node
  end

  def assert_interpolated_name(*args)
    node = assert_has_node(*args)
    op = node.name.find {|n| !n.is_a?(String)}
    refute_nil(op, "expected name to accept interpolations")
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
