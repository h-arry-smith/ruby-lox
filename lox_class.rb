require_relative "callable"
require_relative "instance"

class LoxClass < Callable
  attr_reader :name

  def initialize(name, superclass, methods)
    @name = name
    @superclass = superclass
    @methods = methods
  end

  def find_method(name)
    return method(name) if respond_to?(name)
    return @methods[name] if @methods.key?(name)
    return @superclass.find_method(name) unless @superclass.nil?
  end

  def to_s
    name
  end

  def call(interpreter, arguments)
    instance = Instance.new(self)
    initializer = find_method("init")
    unless initializer.nil?
      initializer.bind(instance).call(interpreter, arguments)
    end

    instance
  end

  def arity
    initializer = find_method("init")
    return 0 if initializer.nil?
    initializer.arity
  end
end
