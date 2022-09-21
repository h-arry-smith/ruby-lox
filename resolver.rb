require "ruby-enum"
require_relative "lox"

class Resolver
  class FunctionType
    include Ruby::Enum

    define :NONE, 'NONE'
    define :FUNCTION, 'FUNCTION'
    define :INITIALIZER, 'INITIALIZER'
    define :METHOD, 'METHOD'
  end

  class ClassType
    include Ruby::Enum

    define :NONE, 'NONE'
    define :CLASS, 'CLASS'
    define :SUBCLASS, 'SUBCLASS'
  end

  def initialize(interpreter)
    @interpreter = interpreter
    @scopes = []
    @current_function = FunctionType::NONE
    @current_class = ClassType::NONE
  end

  def visit_array(expr)
    expr.values.each { |value| resolve(value) }
  end

  def visit_block(stmt)
    begin_scope
    resolve_statements(stmt.statements)
    end_scope
  end

  def visit_class(stmt)
    enclosing_class = @current_class
    @current_class = ClassType::CLASS
    
    declare(stmt.name)
    define(stmt.name)

    if !stmt.superclass.nil? && stmt.name.lexeme == stmt.superclass.name.lexeme
      LOX.error(stmt.superclass.name, "A class can't inherit from itself.")
    end

    unless stmt.superclass.nil?
      @current_class = ClassType::SUBCLASS
      resolve(stmt.superclass)
    end

    unless stmt.superclass.nil?
      begin_scope
      @scopes.last["super"] = true
    end

    begin_scope
    @scopes.last["this"] = true

    stmt.methods.each do |method|
      declaration = FunctionType::METHOD
      declaration = FunctionType::INITIALIZER if method.name.lexeme == "init"

      resolve_function(method, declaration)
    end

    end_scope

    end_scope unless stmt.superclass.nil?
    
    @current_class = enclosing_class
  end

  def visit_expression(stmt)
    resolve(stmt.expression)
  end

  def visit_var(stmt)
    declare(stmt.name)

    resolve(stmt.initializer) unless stmt.initializer.nil?

    define(stmt.name)
  end

  def visit_while(stmt)
    resolve(stmt.condition)
    resolve(stmt.body)
  end

  def visit_return(stmt)
    if @current_function == FunctionType::NONE
      LOX.error(stmt.keyword, "Can't return from top-level code'")
    end

    unless stmt.value.nil?
      if @current_function == FunctionType::INITIALIZER
        LOX.error(stmt.keyword, "Can't return a value from an initializer.")
      end

      resolve(stmt.value)
    end
  end

  def visit_variable(expr)
    if !@scopes.empty? && @scopes.last[expr.name.lexeme] == false
      LOX.error(expr.name, "Can't read local variable in its own initializer.")
    end

    resolve_local(expr, expr.name)
  end

  def visit_assign(expr)
    resolve(expr.value)
    resolve_local(expr, expr.name)
  end

  def visit_binary(expr)
    resolve(expr.left)
    resolve(expr.right)
  end

  def visit_call(expr)
    resolve(expr.callee)
    expr.arguments.each { |arg| resolve(arg) }
  end

  def visit_arrayget(expr)
    resolve(expr.array)
    expr.arguments.each { |arg| resolve(arg) }
  end

  def visit_get(expr)
    resolve(expr.object)
  end

  def visit_grouping(expr)
    resolve(expr.expression)
  end

  def visit_literal(expr)
  end

  def visit_logical(expr)
    resolve(expr.left)
    resolve(expr.right)
  end

  def visit_arrayset(expr)
    resolve(expr.array)
    expr.arguments.each { |arg| resolve(arg) }
    resolve(expr.value)
  end

  def visit_set(expr)
    resolve(expr.value)
    resolve(expr.object)
  end

  def visit_super(expr)
    raise LOX.error(expr.keyword, "Can't use 'super' outside of a class.") if @current_class == ClassType::NONE
    raise LOX.error(expr.keyword, "Can't use 'super' in a class with no superclass.") unless @current_class == ClassType::SUBCLASS

    resolve_local(expr, expr.keyword)
  end

  def visit_this(expr)
    if @current_class == ClassType::NONE
      LOX.error(expr.keyword, "Can't use 'this' outside of a class.")
    end

    resolve_local(expr, expr.keyword)
  end

  def visit_unary(expr)
    resolve(expr.right)
  end

  def visit_function(stmt)
    declare(stmt.name)
    define(stmt.name)

    resolve_function(stmt, FunctionType::FUNCTION)
  end

  def visit_if(stmt)
    resolve(stmt.condition)
    resolve(stmt.then_branch)
    resolve(stmt.else_branch) unless stmt.else_branch.nil?
  end
    
  def visit_print(stmt)
    resolve(stmt.expression)
  end

  def resolve(stmt)
    stmt.accept(self)
  end

  def resolve_statements(statements)
    statements.each { |statement| resolve(statement) }
  end

  private

  def resolve_function(function, type)
    enclosing_function = @current_function
    @current_function = type

    begin_scope
    function.params.each do |param|
      declare(param)
      define(param)
    end

    resolve_statements(function.body)
    end_scope
    @current_function = enclosing_function
  end

  def begin_scope
    @scopes.push({})
  end

  def end_scope
    @scopes.pop
  end

  def declare(name)
    return if @scopes.empty?
    scope = @scopes.last

    if scope.key?(name.lexeme)
      LOX.error(name, "Already a variable with this name in this scope.")
    end

    scope[name.lexeme] = false
  end

  def define(name)
    return if @scopes.empty?
    @scopes.last[name.lexeme] = true
  end

  def resolve_local(expr, name)
    @scopes.each_with_index do |scope, index|
      if scope.key?(name.lexeme)
        @interpreter.resolve(expr, @scopes.length - 1 - index)
        return
      end
    end
  end
end
