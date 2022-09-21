EXPR_AST = {
  Array: [:values],
  ArrayGet: [:array, :arguments, :bracket],
  ArraySet: [:array, :arguments, :value],
  Assign: [:name, :value],
  Binary: [:left, :operator, :right],
  Call: [:callee, :paren, :arguments],
  Get: [:object, :name],
  Grouping: [:expression],
  Literal: [:value],
  Logical: [:left, :operator, :right],
  Set: [:object, :name, :value],
  Super: [:keyword, :method],
  This: [:keyword],
  Unary: [:operator, :right],
  Variable: [:name]
}

module Expr
end

EXPR_AST.each_pair do |name, params|
  Expr.const_set(
    name,
    Struct.new(*params) do
      define_method(:accept) do |visitor|
        visitor.public_send("visit_#{name.downcase}", self)
      end
    end)
end
