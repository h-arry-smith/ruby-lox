require_relative "lox"
require_relative "lox_class"
require_relative "expr"
require_relative "stmt"
require_relative "token_type"

class Parser
  def initialize(tokens)
    @tokens = tokens
    @current = 0
  end

  def parse
    statements = []

    statements.append(declaration) while !is_at_end

    statements
  end

  private

  def expression
    assignment
  end

  def declaration
    begin
      return class_declaration if match(TokenType::CLASS)
      return function("function") if match(TokenType::FUN)
      return var_declaration if match(TokenType::VAR)
      statement
    rescue ParserError
      synchronize
    end
  end

  def class_declaration
    name = consume(TokenType::IDENTIFIER, "Expect class name.")

    superclass = nil
    if match(TokenType::LESS)
      consume(TokenType::IDENTIFIER, "Expect superclass name.")
      superclass = Expr::Variable.new(previous)
    end

    consume(TokenType::LEFT_BRACE, "Expect '{' before class body.")

    methods = []
    methods << function("method") while !check(TokenType::RIGHT_BRACE) && !is_at_end

    consume(TokenType::RIGHT_BRACE, "Expect '}' after class body.")

    Stmt::Class.new(name, superclass, methods)
  end

  def statement
    return for_statement if match(TokenType::FOR)
    return if_statement if match(TokenType::IF)
    return print_statement if match(TokenType::PRINT)
    return return_statement if match(TokenType::RETURN)
    return while_statement if match(TokenType::WHILE)
    return Stmt::Block.new(block) if match(TokenType::LEFT_BRACE)

    expression_statement
  end

  def for_statement
    consume(TokenType::LEFT_PAREN, "Expect '(' after 'for'.")

    initializer = nil
    if match(TokenType::SEMICOLON)
      initializer = nil
    elsif match(TokenType::VAR)
      initializer = var_declaration
    else
      initializer expression_statement
    end

    condition = nil
    if !check(TokenType::SEMICOLON)
      condition = expression
    end
    consume(TokenType::SEMICOLON, "Expect ';' after loop condiiton.")

    increment = nil
    if !check(TokenType::SEMICOLON)
      increment = expression
    end
    consume(TokenType::RIGHT_PAREN, "Expect ')' after for clauses.")

    body = statement

    unless increment.nil?
      body = Stmt::Block.new([
        body,
        Stmt::Expression.new(increment)
      ])

      condition = Expr::Literal(true) if condition.nil?
      body = Stmt::While.new(condition, body)

      unless initializer.nil?
        body = Stmt::Block.new([
          initializer,
          body
        ])
      end
    end

    body
  end

  def if_statement
    consume(TokenType::LEFT_PAREN, "Expect '(' after 'if'.")
    condition = expression
    consume(TokenType::RIGHT_PAREN, "Expect ')' after if condition.")

    then_branch = statement
    else_branch = nil
    else_branch = statement if match(TokenType::ELSE)

    Stmt::If.new(condition, then_branch, else_branch)
  end

  def print_statement
    value = expression
    consume(TokenType::SEMICOLON, "Expect ';' after value.")

    Stmt::Print.new(value)
  end

  def return_statement
    keyword = previous
    value = nil

    unless check(TokenType::SEMICOLON)
      value = expression
    end

    consume(TokenType::SEMICOLON, "Expect ';' after return value.")
    Stmt::Return.new(keyword, value)
  end

  def var_declaration
    name = consume(TokenType::IDENTIFIER, "Expect variable name.")
    initializer = expression if match(TokenType::EQUAL)

    consume(TokenType::SEMICOLON, "Expect ';' after variable declaration.")

    Stmt::Var.new(name, initializer)
  end

  def while_statement
    consume(TokenType::LEFT_PAREN, "Expect '(' after 'while'.")
    condition = expression
    consume(TokenType::RIGHT_PAREN, "Expect ')' after condition.")
    body = statement

    Stmt::While.new(condition, body)
  end

  def expression_statement
    expr = expression
    consume(TokenType::SEMICOLON, "Expect ';' after expression.")

    Stmt::Expression.new(expr)
  end

  def function(kind)
    name = consume(TokenType::IDENTIFIER, "Expect #{kind} name.")
    consume(TokenType::LEFT_PAREN, "Expect '(' after #{kind} name.")

    parameters = []

    unless check(TokenType::RIGHT_PAREN)
      loop do
        if parameters.length >= 255
          error(peek, "Can't have more than 255 parameters.")
        end

        parameters << consume(TokenType::IDENTIFIER, "Expect paramater name.")

        break unless match(TokenType::COMMA)
      end
    end

    consume(TokenType::RIGHT_PAREN, "Expect ')' after parameters.")

    consume(TokenType::LEFT_BRACE, "Expect '{' before #{kind} body.")
    body = block

    Stmt::Function.new(name, parameters, body)
  end

  def block
    statements = []

    while !check(TokenType::RIGHT_BRACE) && !is_at_end
      statements << declaration
    end

    consume(TokenType::RIGHT_BRACE, "Expect '}' after block.")
    return statements
  end

  def assignment
    expr = logical_or

    if match(TokenType::EQUAL)
      equals = previous
      value = assignment

      if expr.is_a?(Expr::Variable)
        name = expr.name
        return Expr::Assign.new(name, value)
      elsif expr.is_a?(Expr::Get)
        get = expr
        return Expr::Set.new(get.object, get.name, value)
      elsif expr.is_a?(Expr::ArrayGet)
        array_get = expr
        return Expr::ArraySet.new(array_get.array, array_get.arguments, value)
      end

      error(equals, "Invalid assignment target.")
    end

    expr
  end

  def logical_or
    expr = logical_and

    while match(TokenType::OR)
      operator = previous
      right = logical_and
      expr = Expr::Logical.new(expr, operator, right)
    end

    expr
  end

  def logical_and
    expr = equality

    while match(TokenType::AND)
      operator = previous
      right = equality
      expr = Expr::Logical.new(expr, operator, right)
    end

    expr
  end

  def equality
    expr = comparison

    while match(TokenType::BANG_EQUAL, TokenType::EQUAL_EQUAL) do
      operator = previous
      right = comparison
      expr = Expr::Binary.new(expr, operator, right)
    end

    expr
  end

  def comparison
    expr = term

    while match(TokenType::GREATER, TokenType::GREATER_EQUAL, TokenType::LESS, TokenType::LESS_EQUAL) do
      operator = previous
      right = term
      expr = Expr::Binary.new(expr, operator, right)
    end

    expr
  end

  def term
    expr = factor

    while match(TokenType::MINUS, TokenType::PLUS) do
      operator = previous
      right = factor
      expr = Expr::Binary.new(expr, operator, right)
    end

    expr
  end

  def factor
    expr = unary

    while match(TokenType::SLASH, TokenType::STAR) do
      operator = previous
      right = unary
      expr = Expr::Binary.new(expr, operator, right)
    end

    expr
  end

  def unary
    if match(TokenType::BANG, TokenType::MINUS)
      operator = previous
      right = unary
      return Expr::Unary.new(operator, right)
    end

    call
  end

  def expression_list(ending)
    args = []

    unless check(ending)
      loop do
        if args.length > 255
          error(peek, "Can't have more than 255 arguments.")
        end

        args << expression

        break unless match(TokenType::COMMA)
      end
    end

    args
  end

  def finish_call(callee)
    args = expression_list(TokenType::RIGHT_PAREN)

    paren = consume(TokenType::RIGHT_PAREN,
                   "Expect ')' after arguments.")

    Expr::Call.new(callee, paren, args)
  end

  def finish_array_get(array)
    args = expression_list(TokenType::RIGHT_BRACKET)
    bracket = consume(TokenType::RIGHT_BRACKET,
                      "Expect ']' after arguments.")

    Expr::ArrayGet.new(array, args, bracket)
  end

  def call
    expr = primary

    while
      if match(TokenType::LEFT_PAREN)
        expr = finish_call(expr)
      elsif match(TokenType::LEFT_BRACKET)
        expr = finish_array_get(expr)
      elsif match(TokenType::DOT)
        name = consume(TokenType::IDENTIFIER, "Expect property name after '.'.")
        expr = Expr::Get.new(expr, name)
      else
        break
      end
    end

    expr
  end

  def primary
    return Expr::Literal.new(false) if match(TokenType::FALSE)
    return Expr::Literal.new(true) if match(TokenType::TRUE)
    return Expr::Literal.new(nil) if match(TokenType::NIL)
    return Expr::This.new(previous) if match(TokenType::THIS)

    if match(TokenType::SUPER)
      keyword = previous
      consume(TokenType::DOT, "Expect '.' after 'super'.")
      method = consume(TokenType::IDENTIFIER, "Expect superclass method name.")

      return Expr::Super.new(keyword, method)
    end

    if match(TokenType::LEFT_BRACKET)
      values = expression_list(TokenType::RIGHT_BRACKET)
      consume(TokenType::RIGHT_BRACKET, "Expect ']' after array.")
      return Expr::Array.new(values)
    end

    if match(TokenType::NUMBER, TokenType::STRING)
      return Expr::Literal.new(previous.literal)
    end

    if match(TokenType::IDENTIFIER)
      return Expr::Variable.new(previous)
    end

    if match(TokenType::LEFT_PAREN)
      expr = expression
      consume(TokenType::RIGHT_PAREN, "Expect ')' after expression.")
      return Expr::Grouping.new(expr)
    end

    raise error(peek, "Expect expression.")
  end

  def match(*types)
    types.each do |type|
      if check(type)
        advance
        return true
      end
    end

    false
  end

  def consume(type, message)
    return advance if check(type)

    raise error(peek, message)
  end

  def check(type)
    return false if is_at_end
    peek.type == type
  end

  def advance
    @current += 1 unless is_at_end
    previous
  end

  def is_at_end
    peek.type == TokenType::EOF
  end

  def peek
    @tokens[@current]
  end

  def previous
    @tokens[@current - 1]
  end

  def error(token, message)
    LOX.token_error(token, message)
    return ParserError.new
  end

  def synchronize
    advance

    while !is_at_end
      return if previous.type == TokenType::SEMICOLON

      case peek.type
      when TokenType::CLASS,
          TokenType::FUN,
          TokenType::VAR,
          TokenType::FOR,
          TokenType::IF,
          TokenType::WHILE,
          TokenType::PRINT,
          TokenType::RETURN
        return
      end

      advance
    end
  end
end

class ParserError < StandardError
end
