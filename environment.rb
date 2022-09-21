require_relative "interpreter"

class Environment
  attr_reader :enclosing, :values

  def initialize(enclosing = nil)
    @enclosing = enclosing
    @values = {}
  end

  def define(name, value)
    @values[name] = value
  end

  def get_at(distance, name)
    ancestor(distance).values[name]
  end

  def get(name)
    return @values[name.lexeme] if @values.key?(name.lexeme)

    return enclosing.get(name) unless @enclosing.nil?

    raise LoxRuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
  end

  def assign(name, value)
    if @values.key?(name.lexeme)
      @values[name.lexeme] = value
      return
    end

    unless @enclosing.nil?
      @enclosing.assign(name, value)
      return
    end

    raise LoxRuntimeError.new(name, "Undefined variable '#{name.lexeme}'")
  end

  def assign_at(distance, name, value)
    ancestor(distance).values[name.lexeme] = value
  end

  private

  def ancestor(distance)
    environment = self

    distance.times { environment = environment.enclosing }

    environment
  end
end
