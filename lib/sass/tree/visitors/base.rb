# Visitors are used to traverse the Sass parse tree.
# Visitors should extend {Visitors::Base},
# which provides a small amount of scaffolding for traversal.
module Sass::Tree::Visitors
  # The abstract base class for Sass visitors.
  # Visitors should extend this class,
  # then implement `visit_*` methods for each node they care about
  # (e.g. `visit_rule` for {RuleNode} or `visit_for` for {ForNode}).
  # These methods take the node in question as argument.
  # They may `yield` to visit the child nodes of the current node.
  #
  # *Note*: due to the unusual nature of {Sass::Tree::IfNode},
  # special care must be taken to ensure that it is properly handled.
  # In particular, there is no built-in scaffolding
  # for dealing with the return value of `@else` nodes.
  #
  # @abstract
  class Base
    # Runs the visitor on a tree.
    #
    # @param root [Tree::Node] The root node of the Sass tree.
    # @return [Object] The return value of \{#visit} for the root node.
    def self.visit(root)
      new.send(:visit, root)
    end

    protected

    # Returns the immediate parent of the current node.
    # @return [Tree::Node]
    attr_reader :parent

    def initialize
      @parent_directives = []
    end

    # Runs the visitor on the given node.
    # This can be overridden by subclasses that need to do something for each node.
    #
    # @param node [Tree::Node] The node to visit.
    # @return [Object] The return value of the `visit_*` method for this node.
    def visit(node)
      method = "visit_#{node_name node}"
      if self.respond_to?(method, true)
        self.send(method, node) {visit_children(node)}
      else
        visit_children(node)
      end
    end

    # Visit the child nodes for a given node.
    # This can be overridden by subclasses that need to do something
    # with the child nodes' return values.
    #
    # This method is run when `visit_*` methods `yield`,
    # and its return value is returned from the `yield`.
    #
    # @param parent [Tree::Node] The parent node of the children to visit.
    # @return [Array<Object>] The return values of the `visit_*` methods for the children.
    def visit_children(parent)
      parent.children.map {|c| visit(c)}
    end

    # Runs a block of code with the current parent node
    # replaced with the given node.
    #
    # @param parent [Tree::Node] The new parent for the duration of the block.
    # @yield A block in which the parent is set to `parent`.
    # @return [Object] The return value of the block.
    def with_parent(parent)
      @parent_directives.push parent if parent.is_a?(Sass::Tree::DirectiveNode)
      old_parent, @parent = @parent, parent
      yield
    ensure
      @parent_directives.pop if parent.is_a?(Sass::Tree::DirectiveNode)
      @parent = old_parent
    end

    NODE_NAME_RE = /.*::(.*?)Node$/

    # Returns the name of a node as used in the `visit_*` method.
    #
    # @param [Tree::Node] node The node.
    # @return [String] The name.
    def node_name(node)
      @@node_names ||= {}
      @@node_names[node.class.name] ||= node.class.name.gsub(NODE_NAME_RE, '\\1').downcase
    end

    # `yield`s, then runs the visitor on the `@else` clause if the node has one.
    # This exists to ensure that the contents of the `@else` clause get visited.
    def visit_if(node)
      yield
      visit(node.else) if node.else
      node
    end

    def bubble(node, options = {})
      return unless parent.is_a?(Sass::Tree::RuleNode)
      new_rule = parent.dup
      new_rule.children = node.children
      node.children = with_parent(node) do
        children = visit(new_rule)
        # Cast children to Array unless explicityly turned off.
        # This is useful when we want to avoid flattening the list.
        if options[:to_array].nil? || options[:to_array]
          Array(children)
        else
          [children]
        end
      end
      # If the last child is actually the end of the group,
      # the parent's cssize will set it properly
      unless node.children.empty?
        last = node.children.last
        last.group_end = false if last.respond_to?(:group_end)
      end
      true
    end
  end
end
