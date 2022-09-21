class AstPrinter
  def print(expr)
    expr.accept(self)
  end

  def visit_binary(expr)
    parenthesize(expr.operator.lexeme, expr.left, expr.right)
  end

  def visit_grouping(expr)
    parenthesize("group", expr.expression)
  end

  def visit_literal(expr)
    "nil" if expr.nil?
    expr.value.to_s
  end

  def visit_unary(expr)
    parenthesize(expr.operator.lexeme, expr.right)
  end

  private

  def parenthesize(name, *exprs)
    string = ""

    string << "(" << name
    exprs.each { |expr| string << " " << expr.accept(self) }
    string << ")"
  end
end
