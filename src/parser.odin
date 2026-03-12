#+feature dynamic-literals

package main

import "base:runtime"
import "core:fmt"
import "core:strconv"

Precedence :: enum {
	LOWEST = 0,
	EQUALS,
	LESS_GREATER,
	SUM,
	PRODUCT,
	PREFIX,
	CALL,
}

predecence_table := map[Token_Type]Precedence {
	.EQ       = .EQUALS,
	.NOT_EQ   = .EQUALS,
	.LT       = .LESS_GREATER,
	.GT       = .LESS_GREATER,
	.PLUS     = .SUM,
	.MINUS    = .SUM,
	.SLASH    = .PRODUCT,
	.ASTERISK = .PRODUCT,
}

peek_precedence :: proc(p: ^Parser) -> Precedence {
	if p, ok := predecence_table[p.peek_tok.type]; ok {
		return p
	}

	return .LOWEST
}

cur_precedence :: proc(p: ^Parser) -> Precedence {
	if p, ok := predecence_table[p.cur_tok.type]; ok {
		return p
	}

	return .LOWEST
}

prefix_parse_fn :: proc(p: ^Parser) -> Expression
infix_parse_fn :: proc(p: ^Parser, expr: ^Expression) -> Expression

register_prefix :: proc(p: ^Parser, type: Token_Type, fn: prefix_parse_fn) {
	p.prefix_parse_fns[type] = fn
}
register_infix :: proc(p: ^Parser, type: Token_Type, fn: infix_parse_fn) {
	p.infix_parse_fns[type] = fn
}

Parser :: struct {
	lexer:            ^Lexer,
	cur_tok:          Token,
	peek_tok:         Token,
	errors:           [dynamic]string,
	prefix_parse_fns: map[Token_Type]prefix_parse_fn,
	infix_parse_fns:  map[Token_Type]infix_parse_fn,
	allocator:        runtime.Allocator,
}

parser_init :: proc(l: ^Lexer, allocator := context.allocator) -> ^Parser {
	p := new(Parser, allocator)
	p.lexer = l
	p.errors = make([dynamic]string, allocator)
	p.allocator = allocator

	p.prefix_parse_fns = make(type_of(p.prefix_parse_fns), allocator)
	register_prefix(p, .IDENT, parse_identifier)
	register_prefix(p, .INT, parse_integer_literal)
	register_prefix(p, .BANG, parse_prefix_expression)
	register_prefix(p, .MINUS, parse_prefix_expression)
	register_prefix(p, .TRUE, parse_boolean)
	register_prefix(p, .FALSE, parse_boolean)

	p.infix_parse_fns = make(type_of(p.infix_parse_fns), allocator)
	register_infix(p, .PLUS, parse_infix_expression)
	register_infix(p, .MINUS, parse_infix_expression)
	register_infix(p, .ASTERISK, parse_infix_expression)
	register_infix(p, .SLASH, parse_infix_expression)
	register_infix(p, .LT, parse_infix_expression)
	register_infix(p, .GT, parse_infix_expression)
	register_infix(p, .EQ, parse_infix_expression)
	register_infix(p, .NOT_EQ, parse_infix_expression)

	parse_next_token(p)
	parse_next_token(p)

	return p
}

parse_program :: proc(p: ^Parser) -> ^Program {
	prog := new(Program, p.allocator)
	prog.statements = make([dynamic]Statement, p.allocator)

	for p.cur_tok.type != .EOF {
		stmt := parse_stmt(p)
		if stmt != {} {
			append(&prog.statements, stmt)
		}
		parse_next_token(p)
	}

	return prog
}

parse_next_token :: proc(p: ^Parser) {
	p.cur_tok = p.peek_tok
	p.peek_tok = lexer_next_token(p.lexer)
}

parse_stmt :: proc(p: ^Parser) -> Statement {
	#partial switch p.cur_tok.type {
	case .LET:
		return Statement{parse_let_stmt(p)}
	case .RETURN:
		return Statement{parse_return_stmt(p)}
	case:
		return Statement{parse_expression_stmt(p)}
	}
}

parse_let_stmt :: proc(p: ^Parser) -> Let_Statement {
	stmt := Let_Statement {
		token = p.cur_tok,
	}

	if !expect_peek(p, .IDENT) {
		return {}
	}

	stmt.name = Identifier {
		token = p.cur_tok,
		value = p.cur_tok.literal,
	}

	if !expect_peek(p, .ASSIGN) {
		return {}
	}

	parse_next_token(p)
	stmt.value = parse_expression(p, .LOWEST)

	for p.cur_tok.type != .SEMICOLON {
		parse_next_token(p)
	}

	return stmt
}

parse_return_stmt :: proc(p: ^Parser) -> Return_Statement {
	stmt := Return_Statement{}
	stmt.token = p.cur_tok
	parse_next_token(p)

	stmt.return_value = parse_expression(p, .LOWEST)

	for p.cur_tok.type != .SEMICOLON {
		parse_next_token(p)
	}

	return stmt
}

parse_expression_stmt :: proc(p: ^Parser) -> Expression_Statement {
	stmt := Expression_Statement{}
	stmt.token = p.cur_tok
	stmt.expr = parse_expression(p, .LOWEST)

	if p.peek_tok.type == .SEMICOLON {
		parse_next_token(p)
	}

	return stmt
}

// Expressions

no_prefix_parser_fn_error :: proc(p: ^Parser, type: Token_Type) {
	msg := fmt.tprintf("no prefix parse function for `%s` found", type)
	append(&p.errors, msg)
}

parse_expression :: proc(p: ^Parser, prec: Precedence) -> Expression {
	prefix, ok := p.prefix_parse_fns[p.cur_tok.type]
	if !ok {
		msg := fmt.tprintf("Unknown expression prefix: %s", p.cur_tok.type)
		append(&p.errors, msg)
		return {}
	}
	left_expr := prefix(p)

	for p.peek_tok.type != .SEMICOLON && prec < peek_precedence(p) {
		infix, ok := p.infix_parse_fns[p.peek_tok.type]
		if !ok {
			return left_expr
		}
		parse_next_token(p)
		left_expr = infix(p, &left_expr)
	}

	return left_expr
}

parse_identifier :: proc(p: ^Parser) -> Expression {
	expr := Identifier{p.cur_tok, p.cur_tok.literal}
	return Expression{expr}
}

parse_integer_literal :: proc(p: ^Parser) -> Expression {
	value, ok := strconv.parse_i64(p.cur_tok.literal)
	if !ok {
		msg := fmt.tprintf("Integer_Literal not i64: %s", p.cur_tok.literal)
		append(&p.errors, msg)
		return {}
	}
	expr := Integer_Literal{p.cur_tok, value}
	return Expression{expr}
}

parse_boolean :: proc(p: ^Parser) -> Expression {
	value, ok := strconv.parse_bool(p.cur_tok.literal)
	if !ok {
		msg := fmt.tprintf("Boolean not bool: %s", p.cur_tok.literal)
		append(&p.errors, msg)
		return {}
	}
	expr := Boolean{p.cur_tok, value}
	return Expression{expr}
}

parse_prefix_expression :: proc(p: ^Parser) -> Expression {
	expr := Prefix_Expression{}
	expr.token = p.cur_tok
	expr.op = p.cur_tok.literal
	parse_next_token(p)
	expr.right = new_clone(parse_expression(p, .PREFIX), p.allocator)
	return Expression{expr}
}

parse_infix_expression :: proc(p: ^Parser, left: ^Expression) -> Expression {
	expr := Infix_Expression{}
	expr.token = p.cur_tok
	expr.op = p.cur_tok.literal
	expr.left = new_clone(left^, p.allocator)
	prec := cur_precedence(p)
	parse_next_token(p)
	expr.right = new_clone(parse_expression(p, prec), p.allocator)

	return Expression{expr}
}

expect_peek :: proc(p: ^Parser, type: Token_Type) -> bool {
	if p.peek_tok.type == type {
		parse_next_token(p)
		return true
	}

	peek_error(p, type)
	return false
}

peek_error :: proc(p: ^Parser, type: Token_Type) {
	msg := fmt.tprintf("expected next to be `%s`, got `%s` instead", type, p.peek_tok.type)
	append(&p.errors, msg)
}

