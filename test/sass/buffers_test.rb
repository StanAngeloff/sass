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

  def test_nesting
    klass = Sass::Tree::BufferNode
    [[:VALID_PROP_PARENTS, "expected properties to be allowed in #{klass.to_s}"],
     [:VALID_EXTEND_PARENTS, "expected @extend directives to be allowed in #{klass.to_s}"],
     [:INVALID_IMPORT_PARENTS, "expected @import directives to be disallowed in #{klass.to_s}."]
    ].each do |test|
      const, message = test
      assert_includes(Sass::Tree::Visitors::CheckNesting.const_get(const), klass, message)
    end

    [["@buffer hello { property: { key: value; } }", nil],
     ["@buffer hello { @extend .class; }", nil],
     ["@buffer hello { @import 'file'; }", Sass::SyntaxError, 'expected @import directive to fail in a @buffer']
    ].each do |test|
      code, klass, message = test
      node = assert_has_node(:scss, :buffer, code)
      exec = lambda { Sass::Tree::Visitors::CheckNesting.visit(node) }
      if klass.nil?
        assert_nothing_raised { exec.call }
      else
        assert_raise *[klass, message] { exec.call }
      end
    end
  end

  def test_deep_copy
    node = assert_has_node(:scss, :buffer, "@buffer \#{ $dynamic + '-operation' }-name\#{ '-followed' + '-by'}-more { }")
    op1 = node.name.select {|n| !n.is_a?(String)}
    clone = node.deep_copy
    op2 = clone.name.select {|n| !n.is_a?(String)}
    assert_equal(op1.length, op2.length, 'expected clone to have the same number of items in its name')
    op1.each_with_index do |value, index|
      assert_not_same(op1[index], op2[index], 'expected clone item to be de-referenced, i.e., a copy')
    end
  end

  def test_basic_buffer_and_flush
    assert_equal <<CSS, render(<<SCSS)
html {
  property: value; }
CSS
@buffer #{__method__} {
  html { property: value; }
}
@flush #{__method__};
SCSS
  end

  def test_append_to_buffer_and_flush
    assert_equal <<CSS, render(<<SCSS)
html {
  property: value; }

body {
  property-2: value; }
CSS
@buffer #{__method__} {
  html { property: value; }
}
@buffer #{__method__} {
  body { property-2: value; }
}
@flush #{__method__};
SCSS
  end

  def test_interpolated_buffer_and_flush
    assert_equal <<CSS, render(<<SCSS)
html {
  property: value; }
CSS
$name: '#{__method__}';

@buffer append-#{$name}-prepend {
  html { property: value; }
}
@flush append-#{$name}-prepend;
SCSS
  end

  def test_bubbling_buffer_and_blush
    assert_equal <<CSS, render(<<SCSS)
html {
  property: value; }

html {
  property-2: value; }
CSS
html {
  property: value;

  @buffer #{__method__} { property-2: value; }
}

@flush #{__method__};
SCSS
  end

  def test_append_to_bubbling_buffer_and_flush
    assert_equal <<CSS, render(<<SCSS)
html {
  property: value; }

body {
  property-2: value; }
CSS
html {
  @buffer #{__method__} { property: value; }
}

body {
  @buffer #{__method__} { property-2: value; }
}

@flush #{__method__};
SCSS
  end

  def test_empty_childred_do_not_create_buffer
    assert_raise Sass::SyntaxError do
      render(<<SCSS)
html {
  @buffer #{__method__};
}

@flush #{__method__};
SCSS
    end
    assert_equal '', render(<<SCSS)
html {
  @buffer #{__method__} {
    // force
  }
}

@flush #{__method__};
SCSS
  end

  def test_buffer_and_media_queries
    assert_equal <<CSS, render(<<SCSS)
#page {
  min-width: 960px; }

#nav {
  max-width: 400px; }

@media only screen and (max-width: 320px) {
  #page {
    min-width: 0; }

  #nav {
    max-width: 100%; } }
CSS
#page {
  min-width: 960px;
  @buffer #{__method__}-small-screen {
    min-width: 0;
  }
}

#nav {
  max-width: 400px;
  @buffer #{__method__}-small-screen {
    max-width: 100%;
  }
}

@media only screen and (max-width: 320px) {
  @flush #{__method__}-small-screen;
}
SCSS

    assert_equal <<CSS, render(<<SCSS)
#page {
  color: #666; }

#nav {
  color: #333; }

@media print {
  #page {
    color: black; } }

@media print {
  #nav {
    color: black; } }
CSS
#page {
  color: #666;

  @buffer #{__method__}-print {
    @media print { color: black; }
  }
}

#nav {
  color: #333;

  @buffer #{__method__}-print {
    @media print { color: black; }
  }
}

@flush #{__method__}-print;
SCSS
  end

  def test_nested_buffers
    assert_equal <<CSS, render(<<SCSS)
html {
  property: value; }
CSS
html {
  @buffer #{__method__} {
    @buffer #{__method__}-level-1 {
      @buffer #{__method__}-level-2 { property: value; }
    }
  }
}

@flush #{__method__};
@flush #{__method__}-level-1;
@flush #{__method__}-level-2;
SCSS
  end

  def test_parent_selected_in_buffer
    assert_equal <<CSS, render(<<SCSS)
html {
  text-align: left; }

.no-js html {
  text-align: right; }

.no-cssgradients body #page {
  background: white; }
CSS
html {
  text-align: left;

  @buffer #{__method__} {
    .no-js & { text-align: right; }
  }
}

body {
  @buffer #{__method__} {
    .no-cssgradients & {
      & #page { background: white; }
    }
  }
}

@flush #{__method__};
SCSS
  end

  def test_mixin_and_content_in_buffer
    assert_equal <<CSS, render(<<SCSS)
html {
  text-align: left; }

.no-js html {
  text-align: right; }
CSS
@mixin if-no-js {
  .no-js & { @content; }
}

html {
  text-align: left;

  @buffer #{__method__} {
    @include if-no-js { text-align: right; }
  }
}

@flush #{__method__};
SCSS
  end

  def test_mixin_in_buffer_and_flush_in_rule
    assert_equal <<CSS, render(<<SCSS)
html {
  text-align: left; }

body {
  text-align: right; }

.no-js html {
  text-align: right; }
.no-js body {
  text-align: left; }
CSS
@mixin if-no-js {
  @buffer #{__method__} { @content; }
}

@mixin flush-no-js {
  .no-js { @flush #{__method__}; }
}

html {
  text-align: left;

  @include if-no-js { text-align: right; }
}

body {
  text-align: right;

  @include if-no-js { text-align: left; }
}

@include flush-no-js;
SCSS
  end

  def test_buffer_and_extend
    assert_equal <<CSS, render(<<SCSS)
.align-left, html {
  text-align: left; }

body {
  text-align: right; }
CSS
.align-left {
  text-align: left;
}

html {
  @buffer #{__method__} {
    @extend .align-left;
  }
}

@buffer #{__method__} {
  body { text-align: right; }
}

@flush #{__method__};
SCSS
  end

  def test_buffer_and_silent_class_extend
    assert_equal <<CSS, render(<<SCSS)
html {
  text-align: left; }

body {
  text-align: right; }
CSS
%align-left {
  text-align: left;
}

html {
  @buffer #{__method__} {
    @extend %align-left;
  }
}

@buffer #{__method__} {
  body { text-align: right; }
}

@flush #{__method__};
SCSS

    assert_equal <<CSS, render(<<SCSS)
body {
  text-align: right; }
CSS
%align-left {
  text-align: left;
}

html {
  @buffer #{__method__} {
    @extend %align-left;
  }
}

@buffer #{__method__}-different {
  body { text-align: right; }
}

@flush #{__method__}-different;
SCSS
  end

  def test_buffer_name_is_normalized
    assert_equal <<CSS, render(<<SCSS)
html {
  property: value; }
CSS
@buffer #{__method__}-mix-dashes_with_underscores {
  html { property: value; }
}

@flush #{__method__}-mix-dashes-with-underscores;
SCSS
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

  def render(scss, options = {})
    options[:syntax] ||= :scss
    munge_filename options
    Sass::Engine.new(scss, options).render
  end
end
