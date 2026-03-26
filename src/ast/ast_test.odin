package ast

import "../token"
import "core:testing"

@(test)
test_to_string :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator
	program := new(Program)
	stmts := make([dynamic]^Stmt)

	let := new(Let_Stmt, token.Token{.Let, "let"})
	let.name = new(Ident, token.Token{.Ident, "myVar"})
	let.name.value = "myVar"
	let_value := new(Ident, token.Token{.Ident, "anotherVar"})
	let_value.value = "anotherVar"
	let.value = let_value

	append(&stmts, let)
	program.stmts = stmts[:]

	actual := to_string(program, context.temp_allocator)
	testing.expectf(t, actual == "let myVar = anotherVar;", "program wrong, got=`%s`", actual)
}
