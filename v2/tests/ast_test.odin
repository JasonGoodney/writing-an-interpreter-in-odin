package main

import "core:testing"

@(test)
test_to_string :: proc(t: ^testing.T) {
	program := Program{}
	program.statements = make(type_of(program.statements))
	let := Let_Statement {
		token = Token{.LET, "let"},
		name = Identifier{token = Token{.IDENT, "myVar"}, value = "myVar"},
		value = Expression{Identifier{token = Token{.IDENT, "anotherVar"}, value = "anotherVar"}},
	}
	append(&program.statements, Statement{let})

	testing.expectf(
		t,
		to_string(&program) == "let myVar = anotherVar;",
		"program wrong, got=`%s`",
		to_string(&program),
	)
}

