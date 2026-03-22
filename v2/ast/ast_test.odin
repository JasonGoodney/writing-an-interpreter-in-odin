package ast

import "../token"
import "core:testing"

@(test)
test_to_string :: proc(t: ^testing.T) {
	program := Program{}
	program.stmts = make(type_of(program.stmts))

	let := Let_Stmt {
		token = token.Token{.Let, "let"},
		name = Ident{token = token.Token{.Ident, "myVar"}, value = "myVar"},
		value = Expr{Ident{token = token.Token{.Ident, "anotherVar"}, value = "anotherVar"}},
	}
	append(&program.stmts, Stmt{let})

	testing.expectf(
		t,
		to_string(&program) == "let myVar = anotherVar;",
		"program wrong, got=`%s`",
		to_string(&program),
	)
}
