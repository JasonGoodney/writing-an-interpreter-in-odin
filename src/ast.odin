package main

import "core:fmt"
import "core:slice"
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
	block_statement_to_string,
	// expressions
	expression_to_string,
	identifier_to_string,
	integer_literal_to_string,
	prefix_expression_to_string,
	infix_expression_to_string,
	boolean_to_string,
	if_expression_to_string,
	function_literal_to_string,
	call_expression_to_string,
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
		strings.write_string(&sb, str)
	}

	str := strings.clone(strings.to_string(sb), allocator)
	return str
}

// Statement
Statement :: struct {
	variant: union {
		Let_Statement,
		Return_Statement,
		Expression_Statement,
		Block_Statement,
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
	case Block_Statement:
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

Block_Statement :: struct {
	token:      Token,
	statements: [dynamic]Statement,
}
block_statement_to_string :: proc(stmt: ^Block_Statement) -> string {
	buf: [dynamic]byte
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)
	for &s in stmt.statements {
		str := to_string(&s)
		strings.write_string(&sb, str)
	}

	str := strings.clone(strings.to_string(sb))
	return str
}

// Expression
Expression :: struct {
	variant: union {
		Identifier,
		Integer_Literal,
		Prefix_Expression,
		Infix_Expression,
		Boolean,
		If_Expression,
		Function_Literal,
		Call_Expression,
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
	case Boolean:
		return to_string(&v)
	case If_Expression:
		return to_string(&v)
	case Function_Literal:
		return to_string(&v)
	case Call_Expression:
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

Boolean :: struct {
	token: Token,
	value: bool,
}
boolean_to_string :: proc(expr: ^Boolean) -> string {
	return expr.token.literal
}

If_Expression :: struct {
	token:       Token,
	condition:   ^Expression,
	consequence: ^Block_Statement,
	alternative: ^Block_Statement,
}
if_expression_to_string :: proc(expr: ^If_Expression) -> string {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "if")
	strings.write_string(&sb, to_string(expr.condition))
	strings.write_string(&sb, " ")
	strings.write_string(&sb, to_string(expr.consequence))

	if expr.alternative != nil {
		strings.write_string(&sb, "else ")
		strings.write_string(&sb, to_string(expr.alternative))
	}

	return strings.clone(strings.to_string(sb))
}

Function_Parameters :: [dynamic]Identifier
Function_Literal :: struct {
	token:      Token,
	parameters: ^Function_Parameters,
	body:       ^Block_Statement,
}
function_literal_to_string :: proc(expr: ^Function_Literal) -> string {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, expr.token.literal)
	strings.write_string(&sb, "(")
	params := slice.mapper(expr.parameters[:], proc(id: Identifier) -> string {
		return id.value
	})
	paramlist := strings.join(params, ", ")
	strings.write_string(&sb, ") ")

	strings.write_string(&sb, to_string(expr.body))

	return strings.clone(strings.to_string(sb))
}

Call_Arguments :: [dynamic]^Expression
Call_Expression :: struct {
	token:     Token, // The '(' token
	function:  ^Expression, // Identifier or Function_Literal
	arguments: ^Call_Arguments,
}
call_expression_to_string :: proc(expr: ^Call_Expression) -> string {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	args := make([dynamic]string, 0, len(expr.arguments))
	defer delete(args)
	for a in expr.arguments {
		append(&args, to_string(a))
	}

	strings.write_string(&sb, to_string(expr.function))
	strings.write_rune(&sb, '(')
	strings.write_string(&sb, strings.join(args[:], ", "))
	strings.write_rune(&sb, ')')

	return strings.clone(strings.to_string(sb))
}

