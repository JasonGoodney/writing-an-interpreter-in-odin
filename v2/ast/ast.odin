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
	block_stmt_to_string,
	ident_to_string,
	integer_literal_to_string,
	boolean_to_string,
	prefix_expr_to_string,
	infix_expr_to_string,
	if_expr_to_string,
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
		Block_Stmt,
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
	case Block_Stmt:
		return to_string(&v)
	case:
		return fmt.tprintf("Unknown statement: %v", stmt)
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

Block_Stmt :: struct {
	token: token.Token,
	stmts: [dynamic]^Stmt,
}
block_stmt_to_string :: proc(stmt: ^Block_Stmt) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for s in stmt.stmts {
		strings.write_string(&sb, stmt_to_string(s))
	}
	return strings.clone(strings.to_string(sb), context.temp_allocator)
}

// ======= Expression =============================
Expr :: struct {
	variant: union {
		Ident,
		Integer_Literal,
		Boolean,
		Prefix_Expr,
		Infix_Expr,
		If_Expr,
	},
}
expr_to_string :: proc(expr: ^Expr) -> string {
	switch &v in expr.variant {
	case Ident:
		return to_string(&v)
	case Integer_Literal:
		return to_string(&v)
	case Boolean:
		return to_string(&v)
	case Prefix_Expr:
		return to_string(&v)
	case Infix_Expr:
		return to_string(&v)
	case If_Expr:
		return to_string(&v)
	case:
		return fmt.tprintf("Unknown expression: %v", expr)
	}
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
integer_literal_to_string :: proc(expr: ^Integer_Literal) -> string {
	return expr.token.literal
}
Boolean :: struct {
	token: token.Token,
	value: bool,
}
boolean_to_string :: proc(expr: ^Boolean) -> string {
	return expr.token.literal
}

Prefix_Expr :: struct {
	token: token.Token,
	op:    string,
	right: ^Expr,
}
prefix_expr_to_string :: proc(expr: ^Prefix_Expr) -> string {
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, "(")
	strings.write_string(&sb, expr.op)
	strings.write_string(&sb, to_string(expr.right))
	strings.write_string(&sb, ")")
	return strings.clone(strings.to_string(sb), context.temp_allocator)
}

Infix_Expr :: struct {
	token: token.Token,
	op:    string,
	left:  ^Expr,
	right: ^Expr,
}
infix_expr_to_string :: proc(expr: ^Infix_Expr) -> string {
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, "(")
	strings.write_string(&sb, to_string(expr.left))
	strings.write_string(&sb, " ")
	strings.write_string(&sb, expr.op)
	strings.write_string(&sb, " ")
	strings.write_string(&sb, to_string(expr.right))
	strings.write_string(&sb, ")")
	return strings.clone(strings.to_string(sb), context.temp_allocator)
}

If_Expr :: struct {
	token:       token.Token,
	condition:   ^Expr,
	consequence: ^Block_Stmt,
	alternative: ^Block_Stmt,
}

if_expr_to_string :: proc(expr: ^If_Expr) -> string {
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, "if")
	strings.write_string(&sb, to_string(expr.condition))
	strings.write_string(&sb, " ")
	strings.write_string(&sb, to_string(expr.consequence))
	if expr.alternative != nil {
		strings.write_string(&sb, "else ")
		strings.write_string(&sb, to_string(expr.alternative))
	}

	return strings.clone(strings.to_string(sb), context.temp_allocator)
}
