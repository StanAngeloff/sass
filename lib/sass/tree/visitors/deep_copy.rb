# A visitor for copying the full structure of a Sass tree.
class Sass::Tree::Visitors::DeepCopy < Sass::Tree::Visitors::Base
  protected

  def visit(node)
    super(node.dup)
  end

  def visit_children(parent)
    parent.children = parent.children.map {|c| visit(c)}
    parent
  end

  def visit_debug(node)
    node.expr = node.expr.deep_copy
    yield
  end

  def visit_each(node)
    node.list = node.list.deep_copy
    yield
  end

  def visit_extend(node)
    deep_copy_attrs(node, :selector)
    yield
  end

  def visit_for(node)
    node.from = node.from.deep_copy
    node.to = node.to.deep_copy
    yield
  end

  def visit_function(node)
    node.args = node.args.map {|k, v| [k.deep_copy, v && v.deep_copy]}
    yield
  end

  def visit_if(node)
    node.expr = node.expr.deep_copy if node.expr
    node.else = visit(node.else) if node.else
    yield
  end

  def visit_mixindef(node)
    node.args = node.args.map {|k, v| [k.deep_copy, v && v.deep_copy]}
    yield
  end

  def visit_mixin(node)
    node.args = node.args.map {|a| a.deep_copy}
    node.keywords = Hash[node.keywords.map {|k, v| [k, v.deep_copy]}]
    yield
  end

  def visit_prop(node)
    deep_copy_attrs(node, :name)
    node.value = node.value.deep_copy
    yield
  end

  def visit_return(node)
    node.expr = node.expr.deep_copy
    yield
  end

  def visit_rule(node)
    deep_copy_attrs(node, :rule)
    yield
  end

  def visit_variable(node)
    node.expr = node.expr.deep_copy
    yield
  end

  def visit_warn(node)
    node.expr = node.expr.deep_copy
    yield
  end

  def visit_while(node)
    node.expr = node.expr.deep_copy
    yield
  end

  def visit_directive(node)
    deep_copy_attrs(node, :value)
    yield
  end

  def visit_media(node)
    deep_copy_attrs(node, :query)
    yield
  end

  def visit_supports(node)
    node.condition = node.condition.deep_copy
    yield
  end

  private

  def deep_copy_attrs(node, *args)
    args.each do |name|
      node.send("#{name}=", node.send(name).map {|c| c.is_a?(Sass::Script::Node) ? c.deep_copy : c})
    end
  end
end
