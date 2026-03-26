package ast

import "../token"
import "core:testing"

@(test)
test_to_string :: proc(t: ^testing.T) {
	program := Node {
		kind = .Program,
	}
	stmts := make([dynamic]Node)

	let := Node {
		kind          = .Let_Stmt,
		token         = token.Token{.Let, "let"},
		let_stmt_name = &Node {
			kind = .Ident,
			token = token.Token{.Ident, "myVar"},
			ident_val = "myVar",
		},
		let_stmt_val  = &Node {
			kind = .Ident,
			token = token.Token{.Ident, "anotherVar"},
			ident_val = "anotherVar",
		},
	}
	append(&stmts, let)
	program.program_stmts = stmts[:]

	testing.expectf(
		t,
		to_string(&program) == "let myVar = anotherVar;",
		"program wrong, got=`%s`",
		to_string(&program),
	)
}
