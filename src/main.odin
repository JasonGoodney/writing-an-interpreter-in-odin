package main

import "ast"
import "core:fmt"
import "core:os"
import "eval"
import "lexer"
import "object"
import "parser"
import "repl"

exec :: proc(input: string) {
	env := object.env_init()
	lexer := lexer.init(input)
	p := parser.init(lexer)
	program := parser.parse_program(p)
	if len(p.errors) > 0 {
		fmt.println(p.errors)
	}
	// Evaluate the input
	obj := eval.eval(program, &env)
	fmt.printfln("{}", object.inspect(&obj))
}

main :: proc() {
	// # REPL
	if len(os.args) == 1 {
		repl.start(os.stdin, os.stdout)

	} else {
		input, err := os.read_entire_file(os.args[1], context.allocator)
		if err != nil {
			fmt.eprintf("Failed to read file: %v", err)
		}
		exec(string(input))
	}
}
