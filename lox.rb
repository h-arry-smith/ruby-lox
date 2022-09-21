require_relative "scanner"
require_relative "token_type"
require_relative "parser"
require_relative "ast_printer"
require_relative "interpreter"
require_relative "resolver"

class Lox
  def initialize
    @interpreter = Interpreter.new

    @had_error = false
    @had_runtime_error = false
  end

  def main(args)
    if args.length > 1
      puts "Usage: rlox [script]"
      exit 64
    elsif args.length == 1
      run_file(args[0])
    else
      run_prompt
    end
  end

  def error(line, message)
    report(line, "", message)
  end

  def token_error(token, message)
    if token.type == TokenType::EOF
      report(token.line, " at end", message)
    else
      report(token.line, " at '#{token.lexeme}'", message)
    end
  end

  def runtime_error(error)
    puts "#{error.message}\n[line #{error.token.line}]"
    @had_runtime_error = true
  end


  private

  def run_file(path)
    file = File.read(path)
    run(file)

    exit(65) if @had_error
    exit(70) if @had_runtime_error
  end

  def run_prompt
    loop do
      print "> "
      line = gets

      break if line.nil?

      run(line.chomp.strip)
      @had_error = false
    end
  end

  def run(source)
    scanner = Scanner.new(source)
    tokens = scanner.scan_tokens

    parser = Parser.new(tokens)
    statements = parser.parse

    return if @had_error

    resolver = Resolver.new(@interpreter)
    resolver.resolve_statements(statements)

    return if @had_error

    @interpreter.interpret(statements)
  end

  def report(line, where, message)
    puts "[line #{line}] Error#{where}: #{message}"
    @had_error = true
  end
end

LOX = Lox.new
