class Callable
  def arity
    raise NotImplementedError
  end

  def call(interpreter, arguments)
    raise NotImplementedError
  end
end
