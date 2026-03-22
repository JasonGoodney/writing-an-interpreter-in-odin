package ast

import "../token"
import "core:fmt"
import "core:strings"

Node :: struct {
	variant: union {
		Program,
		Stmt,
		Expr,
	},
}
to_string :: proc {
	program_to_string,
	stmt_to_string,
	expr_to_string,
	let_stmt_to_string,
	return_stmt_to_string,
	expr_stmt_to_string,
	ident_to_string,
	integer_literal_to_sstring,
}

// ======= Program =============================
Program :: struct {
	stmts: [dynamic]Stmt,
}
program_to_string :: proc(program: ^Program) -> string {
	sb := strings.builder_make(context.temp_allocator)
	defer strings.builder_destroy(&sb)
	for &s in program.stmts {
		str := to_string(&s)
		strings.write_string(&sb, str)
	}

	str := strings.clone(strings.to_string(sb), context.temp_allocator)
	return str
}

// ======= Statements =============================
Stmt :: struct {
	variant: union {
		Let_Stmt,
		Return_Stmt,
		Expr_Stmt,
	},
}
stmt_to_string :: proc(stmt: ^Stmt) -> string {
	switch &v in stmt.variant {
	case Let_Stmt:
		return to_string(&v)
	case Return_Stmt:
		return to_string(&v)
	case Expr_Stmt:
		return to_string(&v)
	case:
		return fmt.tprintf("Unknown statement: %v", stmt)
	}
}

// ======= Expression =============================
Expr :: struct {
	variant: union {
		Ident,
		Integer_Literal,
	},
}
expr_to_string :: proc(expr: ^Expr) -> string {
	switch &v in expr.variant {
	case Ident:
		return to_string(&v)
	case Integer_Literal:
		return to_string(&v)
	case:
		return fmt.tprintf("Unknown expression: %v", expr)
	}
}

Let_Stmt :: struct {
	token: token.Token,
	name:  Ident,
	value: Expr,
}
let_stmt_to_string :: proc(stmt: ^Let_Stmt) -> string {
	return fmt.tprintf(
		"%s %s = %s;",
		stmt.token.literal,
		to_string(&stmt.name),
		to_string(&stmt.value),
	)
}

Return_Stmt :: struct {
	token:        token.Token,
	return_value: Expr,
}
return_stmt_to_string :: proc(stmt: ^Return_Stmt) -> string {
	if stmt.return_value == {} {return ""}
	return fmt.tprintf("{} {};", stmt.token.literal, to_string(&stmt.return_value))
}

Expr_Stmt :: struct {
	token: token.Token,
	expr:  Expr,
}
expr_stmt_to_string :: proc(stmt: ^Expr_Stmt) -> string {
	if stmt.expr == {} {return ""}
	return to_string(&stmt.expr)
}

Ident :: struct {
	token: token.Token,
	value: string,
}
ident_to_string :: proc(expr: ^Ident) -> string {
	return expr.value
}

Integer_Literal :: struct {
	token: token.Token,
	value: i64,
}
integer_literal_to_sstring :: proc(expr: ^Integer_Literal) -> string {
	return fmt.tprintf("%s", expr.value)
}
