class Return < StandardError
  attr_reader :value

  def initialize(value)
    super
    @value = value
  end
end
