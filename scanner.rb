require_relative "lox"
require_relative "token"
require_relative "token_type"

class Scanner
  def initialize(source)
    @source = source
    @tokens = []
    @start = 0
    @current = 0
    @line = 1
  end

  def scan_tokens
    while !is_at_end
      @start = @current
      scan_token
    end

    @tokens << Token.new(TokenType::EOF, "", nil, @line)
  end

  private

  def is_at_end
    @current >= @source.length
  end

  def scan_token
    c = advance
    case c
    when '('
      add_token(TokenType::LEFT_PAREN)
    when ')'
      add_token(TokenType::RIGHT_PAREN)
    when '{'
      add_token(TokenType::LEFT_BRACE)
    when '}'
      add_token(TokenType::RIGHT_BRACE)
    when '['
      add_token(TokenType::LEFT_BRACKET)
    when ']'
      add_token(TokenType::RIGHT_BRACKET)
    when ','
      add_token(TokenType::COMMA)
    when '.'
      add_token(TokenType::DOT)
    when '-'
      add_token(TokenType::MINUS)
    when '+'
      add_token(TokenType::PLUS)
    when ';'
      add_token(TokenType::SEMICOLON)
    when '*'
      add_token(TokenType::STAR)
    when '!'
      add_token(match('=') ? TokenType::BANG_EQUAL : TokenType::BANG)
    when '='
      add_token(match('=') ? TokenType::EQUAL_EQUAL : TokenType::EQUAL)
    when '<'
      add_token(match('=') ? TokenType::LESS_EQUAL : TokenType::LESS)
    when '>'
      add_token(match('=') ? TokenType::GREATER_EQUAL : TokenType::GREATER)
    when '/'
      if match('/')
        advance while peek != "\n" && !is_at_end
      else
        add_token TokenType::SLASH
      end
    when " " then return
    when "\r" then return
    when "\t" then return
    when "\n"
      @line += 1
    when '"'
      string
    else
      if digit?(c)
        number
      elsif alpha?(c)
        identifier
      else
        LOX.error(@line, "Unexpected character.")
      end
    end
  end

  def string
    while peek != '"' && !is_at_end
      @line += 1 if peek == "\n"
      advance
    end

    if is_at_end
      LOX.error(@line, "Unterminated string.")
      return
    end

    # closing "
    advance

    # trim surrounding quotes
    value = @source[(@start + 1)...(@current - 1)]
    add_token(TokenType::STRING, value)
  end

  def number
    advance while digit?(peek)

    if peek == '.' && digit?(peek_next)
      advance
      advance while digit?(peek)
    end

    value = @source[@start...@current].to_f
    add_token(TokenType::NUMBER, value)
  end

  def identifier
    advance while alphanumeric?(peek)

    text = @source[@start...@current]
    type = TokenType.key(text)
    type = :IDENTIFIER if type.nil?

    add_token(TokenType.value(type))
  end

  def match(expected)
    return false if is_at_end
    return false if @source[@current] != expected

    @current += 1
    true
  end

  def peek
    "\0" if is_at_end
    @source[@current]
  end

  def peek_next
    "\0" if @current + 1 >= @source.length
    @source[@current + 1]
  end

  def digit?(c)
    c in '0'..'9'
  end

  def alpha?(c)
    ('a'..'z').include?(c) || ('A'..'Z').include?(c) || c == '_'
  end

  def alphanumeric?(c)
    alpha?(c) || digit?(c)
  end

  def advance
    c = @source[@current]
    @current += 1
    c
  end

  def add_token(type, literal = nil)
    text = @source[@start...@current]
    @tokens << Token.new(type, text, literal, @line)
  end
end
