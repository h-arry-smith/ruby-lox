require_relative "callable"
require_relative "instance"
require_relative "function"
require_relative "environment"
require_relative "lox"
require_relative "token_type"
require_relative "return"
require_relative "lox_class"
require_relative "lox_array"

class Interpreter
  attr_reader :globals
  
  def initialize
    @globals = Environment.new
    @environment = @globals
    @locals = {}

    @globals.define(
      "clock",
      Class.new(Callable) do
        def arity
          0
        end

        def call(interpreter, arguments)
          (Time.now.to_f * 1000).to_i
        end

        def to_s
         "<native fn>"
        end
      end.new)
  end

  def interpret(statements)
    begin
      statements.each { |statement| evaluate(statement) }
    rescue LoxRuntimeError => error
      LOX.runtime_error(error)
    end
  end

  def visit_array(expr)
    values = expr.values.map { |value| evaluate(value) }
    return LoxArray.new(values)
  end

  def visit_block(stmt)
    evaluate_block(stmt.statements, Environment.new(@environment))
  end

  def visit_class(stmt)
    superclass = nil

    unless stmt.superclass.nil?
      superclass = evaluate(stmt.superclass)
      raise LoxRuntimeError.new(stmt.superclass.name, "Superclass must be a class.") unless superclass.is_a?(LoxClass)
    end
    
    @environment.define(stmt.name.lexeme, nil)

    unless stmt.superclass.nil?
      @environment = Environment.new(@environment)
      @environment.define("super", superclass)
    end

    methods = {}
    stmt.methods.each do |method|
      function = Function.new(method, @environment, method.name.lexeme == "init")
      methods[method.name.lexeme] = function
    end

    klass = LoxClass.new(stmt.name.lexeme, superclass, methods)

    @environment = @environment.enclosing unless superclass.nil?

    @environment.assign(stmt.name, klass)
  end

  def visit_expression(stmt)
    evaluate(stmt.expression)
  end

  def visit_function(stmt)
    function = Function.new(stmt, @environment, false)
    @environment.define(stmt.name.lexeme, function)
  end

  def visit_if(stmt)
    if truthy?(evaluate(stmt.condition))
      evaluate(stmt.then_branch)
    elsif !stmt.else_branch.nil?
      evaluate(stmt.else_branch)
    end
  end

  def visit_print(stmt)
    value = evaluate(stmt.expression)
    puts stringify(value)
  end

  def visit_return(stmt)
    value = nil
    value = evaluate(stmt.value) unless stmt.value.nil?

    raise Return.new(value)
  end

  def visit_var(stmt)
    value = nil

    value = evaluate(stmt.initializer) unless stmt.initializer.nil?

    @environment.define(stmt.name.lexeme, value)
  end

  def visit_while(stmt)
    while truthy?(evaluate(stmt.condition))
      evaluate(stmt.body)
    end
  end

  def visit_assign(expr)
    value = evaluate(expr.value)

    distance = @locals[expr]
    unless distance.nil?
      @environment.assign_at(distance, expr.name, value)
    else
      @globals.assign(expr.name, value)
    end

    value
  end

  def visit_literal(expr)
    expr.value
  end

  def visit_logical(expr)
    left = evaluate(expr.left)

    if expr.operator.type == TokenType::OR
      return left if truthy?(left)
    else
      return left unless truthy?(left)
    end

    evaluate(expr.right)
  end

  def visit_set(expr)
    object = evaluate(expr.object)

    raise LoxRuntimeError.new(expr.name, "Only instances have fields.") unless object.is_a?(Instance)

    value = evaluate(expr.value)
    object.set(expr.name, value)
    value
  end

  def visit_super(expr)
    distance = @locals[expr]
    superclass = @environment.get_at(distance, "super")
    # 'this' is always one environment to the right of the super resolution
    object = @environment.get_at(distance - 1, "this")

    method = superclass.find_method(expr.method.lexeme)

    raise LoxRuntimeError.new(expr.method, "Undefined property '#{expr.method.lexeme}'.") if method.nil?

    method.bind(object)
  end

  def visit_this(expr)
    lookup_variable(expr.keyword, expr)
  end

  def visit_grouping(expr)
    evaluate(expr.expression)
  end

  def visit_unary(expr)
    right = evaluate(expr.right)

    case expr.operator.type
    when TokenType::MINUS
      check_number_operand(expr.operator, right)
      -right
    when TokenType::BANG
      !truthy?(right)
    end
  end

  def visit_variable(expr)
    lookup_variable(expr.name, expr)
  end

  def visit_binary(expr)
    left = evaluate(expr.left)
    right = evaluate(expr.right)

    case expr.operator.type
    when TokenType::BANG_EQUAL
      !equal?(left, right)
    when TokenType::EQUAL_EQUAL
      equal?(left, right)
    when TokenType::GREATER
      check_number_operands(expr.operator, left, right)
      left > right
    when TokenType::GREATER_EQUAL
      check_number_operands(expr.operator, left, right)
      left >= right
    when TokenType::LESS
      check_number_operands(expr.operator, left, right)
      left < right
    when TokenType::LESS_EQUAL
      check_number_operands(expr.operator, left, right)
      left <= right
    when TokenType::MINUS
      check_number_operands(expr.operator, left, right)
      left - right
    when TokenType::PLUS
      if left.is_a?(String) && right.is_a?(String)
        left + right
      elsif left.is_a?(Numeric) && right.is_a?(Numeric)
        left + right
      else
        raise LoxRuntimeError.new(expr.operator, "Operands must be two numbers or two strings.")
      end
    when TokenType::SLASH
      check_number_operands(expr.operator, left, right)
      left / right
    when TokenType::STAR
      check_number_operands(expr.operator, left, right)
      left * right
    end
  end

  def visit_call(expr)
    callee = evaluate(expr.callee)

    raise LoxRuntimeError.new(expr.paren, "Can only call functions and classes.") unless callee.is_a?(Callable) || callee.is_a?(Method)

    arguments = expr.arguments.map { |argument| evaluate(argument) }

    if callee.is_a?(Callable)
      lox_call(expr, callee, arguments)
    elsif callee.is_a?(Method)
      native_call(expr, callee, arguments)
    end
  end

  def native_call(expr, callee, arguments)
    if callee.arity == -1 && !arguments.empty?
      raise LoxRuntimeError.new(expr.paren, "Expected 0 arguments but got #{arguments.length}.") 
    end

    if arguments.length != callee.arity
      raise LoxRuntimeError.new(expr.paren, "Expected #{callee.arity} arguments but got #{arguments.length}.") 
    end

    if callee.arity == -1
      callee.call()
    else
      callee.call(*arguments)
    end
  end

  def lox_call(expr, callee, arguments)
    if arguments.length != callee.arity && callee.arity != -1
      raise LoxRuntimeError.new(expr.paren, "Expected #{callee.arity} arguments but got #{arguments.length}.") 
    end

    callee.call(self, arguments)
  end

  def visit_arrayget(expr)
    array = evaluate(expr.array)
    raise LoxRuntimeError.new(expr.bracket, "Expected an array.") unless array.is_a?(LoxArray)

    arguments = expr.arguments.map { |arg| evaluate(arg) }

    return array.get(*arguments)
  end

  def visit_arrayset(expr)
    array = evaluate(expr.array)
    arguments = expr.arguments.map { |arg| evaluate(arg) }
    value = evaluate(expr.value)

    array.set(arguments[0], value)
  end

  def visit_get(expr)
    object = evaluate(expr.object)
    if object.is_a?(Instance)
      return object.get(expr.name)
    end

    raise LoxRuntimeError.new(expr.name, "Only instances have properties.")
  end

  def evaluate_block(statements, environment)
    previous = @environment

    begin
      @environment = environment
      statements.each { |statement| evaluate(statement) }
    ensure
      @environment = previous
    end
  end

  def resolve(expr, depth)
    @locals[expr] = depth
  end

  private

  def evaluate(expr)
    expr.accept(self)
  end

  def truthy?(object)
    return false if object.nil?
    return false if object == false 
    true
  end

  def equal?(a, b)
    return true if a.nil? && b.nil?
    return false if a.nil?

    a == b
  end

  def stringify(object)
    return "nil" if object.nil?

    if object.is_a?(Numeric)
      text = object.to_s
      return text[...-2] if text.end_with?(".0")
      return text
    end

    object.to_s
  end

  def lookup_variable(name, expr)
    distance = @locals[expr]
    unless distance.nil?
      @environment.get_at(distance, name.lexeme)
    else
      @globals.get(name)
    end
  end

  def check_number_operand(operator, operand)
    raise LoxRuntimeError.new(operator, "Operand must be a number.") unless operand.is_a?(Numeric)
  end

  def check_number_operands(operator, left, right)
    raise LoxRuntimeError.new(operator, "Operands must be a number.") unless left.is_a?(Numeric) && right.is_a?(Numeric)
  end
end

class LoxRuntimeError < StandardError
  attr_reader :token

  def initialize(token, message)
    super(message)
    @token = token
  end
end
