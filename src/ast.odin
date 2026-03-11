package main

import "core:fmt"
import "core:strings"

Node :: union {
	Program,
	Statement,
	Expression,
}


to_string :: proc {
	program_to_string,
	// statements
	statement_to_string,
	let_statement_to_string,
	return_statement_to_string,
	expression_statement_to_string,
	// expressions
	expression_to_string,
	identifier_to_string,
	integer_literal_to_string,
	prefix_expression_to_string,
	infix_expression_to_string,
}

Program :: struct {
	statements: [dynamic]Statement,
}
program_to_string :: proc(prog: ^Program, allocator := context.allocator) -> string {
	buf: [dynamic]byte
	sb := strings.builder_make(allocator)
	defer strings.builder_destroy(&sb)
	for &s in prog.statements {
		str := to_string(&s)
		// append_elem_string(&buf, str)
		strings.write_string(&sb, str)
	}

	// str := string(buf[:])
	str := strings.clone(strings.to_string(sb), allocator)
	return str
}

// Statement
Statement :: struct {
	variant: union {
		Let_Statement,
		Return_Statement,
		Expression_Statement,
	},
}
statement_to_string :: proc(stmt: ^Statement) -> string {
	switch &v in stmt.variant {
	case Let_Statement:
		return to_string(&v)
	case Return_Statement:
		return to_string(&v)
	case Expression_Statement:
		return to_string(&v)
	case:
		return "Unknown Statement"
	}
}

Let_Statement :: struct {
	token: Token,
	name:  Identifier,
	value: Expression,
}
let_statement_to_string :: proc(stmt: ^Let_Statement) -> string {
	return fmt.tprintf(
		"{} {} = {};",
		stmt.token.literal,
		to_string(&stmt.name),
		to_string(&stmt.value),
	)
}

Return_Statement :: struct {
	token:        Token,
	return_value: Expression,
}
return_statement_to_string :: proc(stmt: ^Return_Statement) -> string {
	if stmt.return_value == {} {return ""}
	return fmt.tprintf("{} {};", stmt.token.literal, to_string(&stmt.return_value))
}

Expression_Statement :: struct {
	token: Token,
	expr:  Expression,
}
expression_statement_to_string :: proc(stmt: ^Expression_Statement) -> string {
	if stmt.expr == {} {return ""}
	return to_string(&stmt.expr)
}

// Expression
Expression :: struct {
	variant: union {
		Identifier,
		Integer_Literal,
		Prefix_Expression,
		Infix_Expression,
	},
}
expression_to_string :: proc(expr: ^Expression) -> string {
	switch &v in expr.variant {
	case Identifier:
		return to_string(&v)
	case Integer_Literal:
		return to_string(&v)
	case Prefix_Expression:
		return to_string(&v)
	case Infix_Expression:
		return to_string(&v)
	case:
		return "Unknown Expression"
	}
}

Identifier :: struct {
	token: Token,
	value: string,
}
identifier_to_string :: proc(expr: ^Identifier) -> string {
	return expr.value
}

Integer_Literal :: struct {
	token: Token,
	value: i64,
}
integer_literal_to_string :: proc(expr: ^Integer_Literal) -> string {
	return expr.token.literal
}

Prefix_Expression :: struct {
	token: Token,
	op:    string,
	right: ^Expression,
}
prefix_expression_to_string :: proc(expr: ^Prefix_Expression) -> string {
	return fmt.tprintf("(%s%s)", expr.op, to_string(expr.right))
}

Infix_Expression :: struct {
	token: Token,
	left:  ^Expression,
	op:    string,
	right: ^Expression,
}
infix_expression_to_string :: proc(expr: ^Infix_Expression) -> string {
	return fmt.tprintf("(%s %s %s)", to_string(expr.left), expr.op, to_string(expr.right))
}

