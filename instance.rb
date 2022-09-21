require_relative 'interpreter'

class Instance
  def initialize(klass)
    @klass = klass
    @fields = {}
  end

  def get(name)
    return @fields[name.lexeme] if @fields.key?(name.lexeme)

    method = @klass.find_method(name.lexeme)

    return method if method.is_a?(Method)
    return method.bind(self) unless method.nil?

    raise LoxRuntimeError.new(name, "Undefined property '#{name.lexeme}'.")
  end

  def set(name, value)
    @fields[name.lexeme] = value
  end

  def to_s
    "#{@klass.name} instance"
  end
end
