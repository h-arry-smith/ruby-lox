STMT_AST = {
  Block: [:statements],
  Class: [:name, :superclass, :methods],
  Expression: [:expression],
  Function: [:name, :params, :body],
  If: [:condition, :then_branch, :else_branch],
  Print: [:expression],
  Return: [:keyword, :value],
  Var: [:name, :initializer],
  While: [:condition, :body]
}

module Stmt
end

STMT_AST.each_pair do |name, params|
  Stmt.const_set(
    name,
    Struct.new(*params) do
      define_method(:accept) do |visitor|
        visitor.public_send("visit_#{name.downcase}", self)
      end
    end)
end
