require_relative "callable"
require_relative "return"
require_relative "environment"

class Function < Callable
  def initialize(declaration, closure, is_initializer)
    @declaration = declaration
    @closure = closure
    @is_initializer = is_initializer
  end

  def call(interpreter, arguments)
    environment = Environment.new(@closure)

    @declaration.params.each_with_index do |param, index|
      environment.define(
        param.lexeme,
        arguments[index]
      )
    end

    begin
      interpreter.evaluate_block(@declaration.body, environment)
    rescue Return => return_value
      return @closure.get_at(0, "this") if @is_initializer
      return return_value.value
    end

    return @closure.get_at(0, "this") if @is_initializer
  end

  def bind(instance)
    environment = Environment.new(@closure)
    environment.define("this", instance)
    Function.new(@declaration, environment, @is_initializer)
  end

  def arity
    @declaration.params.length
  end

  def to_s
    "<fn #{@declaration.name.lexeme}>"
  end
end
