class LoxArray
  def initialize(values)
    @values = values
  end

  def get(index)
    @values[index]
  end

  def set(index, value)
    @values[index] = value
  end

  # this to string is pretty naive because this implementation doesnt store
  # literals as internal object types to provide a good stringify but
  # could easily be expanded to be better TODO
  def to_s
    stringified_values = @values.map do |value|
      stringified = value.to_s
      stringified = stringified[...-2] if stringified.end_with?(".0")
      stringified = "\"#{stringified}\"" unless stringified.start_with?(/[0-9]/)
      stringified
    end

    "[#{stringified_values.join(", ")}]"
  end
end
