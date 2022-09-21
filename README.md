# rLox
Ruby implementation of tree walking intepreter from part one of Crafting Interpreters.

`ruby main.rb` for the REPL like interpreter.  
`ruby main.rb <filename>` to run a file.  

This implementation is more of a direct translation of the code in the book into ruby, but uses a spattering of ruby metaprogramming to make it nicer - mainly for generating the AST nodes. It is probably not the best implementation in ruby possible, but may serve as a starting point for someone else wanting to follow this book in Ruby :)

The only dependency is ruby-enum which I used for the TokenType class.

For fun, I also implemented in this version simple support for arrays, and your typical access syntax for them, but it is far from perfect.
