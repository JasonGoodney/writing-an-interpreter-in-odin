#+ feature dynamic-literals

package parser

import "../ast"
import "../lexer"
import "../token"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:strconv"

prefix_parse_fn :: proc(p: ^Parser) -> ast.Expr
infix_parse_fn :: proc(p: ^Parser, left: ^ast.Expr) -> ast.Expr

Precedence :: enum {
	Lowest,
	Equals,
	Less_Greater,
	Sum,
	Product,
	Prefix,
	Call,
}

precedence_table := map[token.Token_Type]Precedence {
	.Equal      = .Equals,
	.Not_Equal  = .Equals,
	.Less       = .Less_Greater,
	.Greater    = .Less_Greater,
	.Plus       = .Sum,
	.Minus      = .Sum,
	.Slash      = .Product,
	.Asterisk   = .Product,
	.Left_Paren = .Call,
}

peek_precedence :: proc(p: ^Parser) -> Precedence {
	if p, ok := precedence_table[p.peek_tok.type]; ok {
		return p
	}
	return .Lowest
}

curr_precedence :: proc(p: ^Parser) -> Precedence {
	if p, ok := precedence_table[p.curr_tok.type]; ok {
		return p
	}
	return .Lowest
}

Parser :: struct {
	lexer:            ^lexer.Lexer,
	curr_tok:         token.Token,
	peek_tok:         token.Token,
	allocator:        runtime.Allocator,
	errors:           [dynamic]string,
	prefix_parse_fns: map[token.Token_Type]prefix_parse_fn,
	infix_parse_fns:  map[token.Token_Type]infix_parse_fn,
}

register_prefix :: proc(p: ^Parser, type: token.Token_Type, fn: prefix_parse_fn) {
	p.prefix_parse_fns[type] = fn
}

register_infix :: proc(p: ^Parser, type: token.Token_Type, fn: infix_parse_fn) {
	p.infix_parse_fns[type] = fn
}

init :: proc(l: ^lexer.Lexer, allocator := context.allocator) -> ^Parser {
	p := new(Parser, allocator)
	p.allocator = allocator
	p.lexer = l
	p.errors = make(type_of(p.errors), p.allocator)

	p.prefix_parse_fns = make(type_of(p.prefix_parse_fns), p.allocator)
	register_prefix(p, .Ident, parse_ident)
	register_prefix(p, .Int, parse_int)
	register_prefix(p, .Bang, parse_prefix_expr)
	register_prefix(p, .Minus, parse_prefix_expr)
	register_prefix(p, .True, parse_boolean)
	register_prefix(p, .False, parse_boolean)
	register_prefix(p, .Left_Paren, parse_grouped_expr)
	register_prefix(p, .If, parse_if_expr)
	register_prefix(p, .Function, parse_function_literal)

	p.infix_parse_fns = make(type_of(p.infix_parse_fns), p.allocator)
	register_infix(p, .Plus, parse_infix_expr)
	register_infix(p, .Minus, parse_infix_expr)
	register_infix(p, .Asterisk, parse_infix_expr)
	register_infix(p, .Slash, parse_infix_expr)
	register_infix(p, .Greater, parse_infix_expr)
	register_infix(p, .Less, parse_infix_expr)
	register_infix(p, .Equal, parse_infix_expr)
	register_infix(p, .Not_Equal, parse_infix_expr)
	register_infix(p, .Left_Paren, parse_call_expr)

	next_token(p)
	next_token(p)

	return p
}

parse_program :: proc(p: ^Parser) -> ast.Program {
	program: ast.Program
	program.stmts = make(type_of(program.stmts), p.allocator)

	for p.curr_tok.type != .EOF {
		stmt := parse_stmt(p)
		switch &v in stmt.variant {
		case ast.Let_Stmt:
			append(&program.stmts, stmt)
		case ast.Return_Stmt:
			append(&program.stmts, stmt)
		case ast.Expr_Stmt:
			append(&program.stmts, stmt)
		case ast.Block_Stmt:
			append(&program.stmts, stmt)
		}
		next_token(p)
	}
	return program
}

next_token :: proc(p: ^Parser) {
	p.curr_tok = p.peek_tok
	p.peek_tok = lexer.next_token(p.lexer)
}

parse_stmt :: proc(p: ^Parser) -> ast.Stmt {
	#partial switch p.curr_tok.type {
	case .Let:
		return parse_let_stmt(p)
	case .Return:
		return parse_return_stmt(p)
	case:
		return parse_expr_stmt(p)
	}
}

parse_let_stmt :: proc(p: ^Parser) -> ast.Stmt {
	letstmt := ast.Let_Stmt {
		token = p.curr_tok,
	}

	if !expect_peek(p, .Ident) {
		return {}
	}

	letstmt.name = ast.Ident{p.curr_tok, p.curr_tok.literal}


	if !expect_peek(p, .Assign) {
		return {}
	}
	next_token(p)
	letstmt.value = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}

	return ast.Stmt{letstmt}
}

parse_return_stmt :: proc(p: ^Parser) -> ast.Stmt {
	retstmt := ast.Return_Stmt {
		token = p.curr_tok,
	}
	next_token(p)
	retstmt.return_value = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}
	return ast.Stmt{retstmt}
}

parse_expr_stmt :: proc(p: ^Parser) -> ast.Stmt {
	stmt := ast.Expr_Stmt {
		token = p.curr_tok,
	}
	stmt.expr = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}
	return ast.Stmt{stmt}
}

parse_block_stmt :: proc(p: ^Parser) -> ast.Block_Stmt {
	block := ast.Block_Stmt {
		token = p.curr_tok,
	}
	next_token(p)
	for p.curr_tok.type != .Right_Brace && p.curr_tok.type != .EOF {
		stmt := new_clone(parse_stmt(p), p.allocator)
		switch &v in stmt.variant {
		case ast.Let_Stmt:
			append(&block.stmts, stmt)
		case ast.Return_Stmt:
			append(&block.stmts, stmt)
		case ast.Expr_Stmt:
			append(&block.stmts, stmt)
		case ast.Block_Stmt:
			append(&block.stmts, stmt)
		}
		next_token(p)
	}
	return block
}

// =========== Expressions ==============================

parser_error :: proc(p: ^Parser, format: string, args: ..any) {
	msg := fmt.tprintf(format, ..args)
	append(&p.errors, msg)
}

parse_expr :: proc(p: ^Parser, prec: Precedence) -> ast.Expr {
	prefix := p.prefix_parse_fns[p.curr_tok.type]
	if prefix == nil {
		parser_error(p, "no prefix parse fn for %s found", p.curr_tok.literal)
		return {}
	}
	left_expr := prefix(p)

	for p.peek_tok.type != .Semicolon && prec < peek_precedence(p) {
		infix := p.infix_parse_fns[p.peek_tok.type]
		if infix == nil {
			return left_expr
		}
		next_token(p)
		left_expr = infix(p, &left_expr)
	}

	return left_expr
}

parse_ident :: proc(p: ^Parser) -> ast.Expr {
	ident := ast.Ident{p.curr_tok, p.curr_tok.literal}
	return ast.Expr{ident}
}

parse_int :: proc(p: ^Parser) -> ast.Expr {
	val, ok := strconv.parse_i64(p.curr_tok.literal)
	if !ok {
		parser_error(p, "could not parse %s as integer", p.curr_tok.literal)
		return {}
	}
	integer := ast.Integer_Literal{p.curr_tok, val}
	return ast.Expr{integer}
}

parse_prefix_expr :: proc(p: ^Parser) -> ast.Expr {
	prefix_expr := ast.Prefix_Expr {
		token = p.curr_tok,
		op    = p.curr_tok.literal,
	}
	next_token(p)
	prefix_expr.right = new_clone(parse_expr(p, .Prefix), p.allocator)
	return ast.Expr{prefix_expr}
}

parse_infix_expr :: proc(p: ^Parser, left: ^ast.Expr) -> ast.Expr {
	infix_expr := ast.Infix_Expr {
		token = p.curr_tok,
		op    = p.curr_tok.literal,
	}
	infix_expr.left = new_clone(left^, p.allocator)
	precedence := curr_precedence(p)
	next_token(p)
	infix_expr.right = new_clone(parse_expr(p, precedence), p.allocator)
	return ast.Expr{infix_expr}

}

parse_boolean :: proc(p: ^Parser) -> ast.Expr {
	val, ok := strconv.parse_bool(p.curr_tok.literal)
	if !ok {
		parser_error(p, "could not parse %s as boolean", p.curr_tok.literal)
		return {}
	}
	b := ast.Boolean{p.curr_tok, val}
	return ast.Expr{b}
}

parse_grouped_expr :: proc(p: ^Parser) -> ast.Expr {
	next_token(p)
	inner := new_clone(parse_expr(p, .Lowest), p.allocator)
	if !expect_peek(p, .Right_Paren) {
		parser_error(p, "missing closing parentheses", p.curr_tok.literal)
		return {}
	}
	return inner^
}

parse_if_expr :: proc(p: ^Parser) -> ast.Expr {
	ifexpr := ast.If_Expr {
		token = p.curr_tok,
	}
	if !expect_peek(p, .Left_Paren) {
		return {}
	}
	next_token(p)
	ifexpr.condition = new_clone(parse_expr(p, .Lowest), p.allocator)
	if !expect_peek(p, .Right_Paren) {
		return {}
	}
	if !expect_peek(p, .Left_Brace) {
		return {}
	}
	ifexpr.consequence = new_clone(parse_block_stmt(p), p.allocator)

	if p.peek_tok.type == .Else {
		next_token(p)
		if !expect_peek(p, .Left_Brace) {
			return {}
		}
		ifexpr.alternative = new_clone(parse_block_stmt(p), p.allocator)
	}

	return ast.Expr{ifexpr}
}

parse_function_literal :: proc(p: ^Parser) -> ast.Expr {
	fnexpr := ast.Function_Literal {
		token = p.curr_tok,
	}
	if !expect_peek(p, .Left_Paren) {
		return {}
	}
	fnexpr.parameters = parse_function_parameters(p)
	if !expect_peek(p, .Left_Brace) {
		return {}
	}
	fnexpr.body = new_clone(parse_block_stmt(p), p.allocator)
	return ast.Expr{fnexpr}
}

parse_function_parameters :: proc(p: ^Parser) -> ^[dynamic]ast.Ident {
	idents := new([dynamic]ast.Ident, p.allocator)
	if p.peek_tok.type == .Right_Paren {
		next_token(p)
		return idents
	}
	next_token(p)
	ident := ast.Ident {
		token = p.curr_tok,
		value = p.curr_tok.literal,
	}
	append(idents, ident)
	for p.peek_tok.type == .Comma {
		next_token(p)
		next_token(p)
		ident := ast.Ident {
			token = p.curr_tok,
			value = p.curr_tok.literal,
		}
		append(idents, ident)
	}
	if !expect_peek(p, .Right_Paren) {
		return {}
	}
	return idents
}

parse_call_expr :: proc(p: ^Parser, function: ^ast.Expr) -> ast.Expr {
	callexpr := ast.Call_Expr {
		token    = p.curr_tok,
		function = new_clone(function^, p.allocator),
	}
	callexpr.arguments = parse_call_arguments(p)
	return ast.Expr{callexpr}
}

parse_call_arguments :: proc(p: ^Parser) -> ^[dynamic]ast.Expr {
	args := new([dynamic]ast.Expr, p.allocator)
	if p.peek_tok.type == .Right_Paren {
		next_token(p)
		return args
	}
	next_token(p)
	append(args, parse_expr(p, .Lowest))
	for p.peek_tok.type == .Comma {
		next_token(p)
		next_token(p)
		append(args, parse_expr(p, .Lowest))
	}

	if !expect_peek(p, .Right_Paren) {
		return {}
	}
	return args
}

expect_peek :: proc(p: ^Parser, type: token.Token_Type) -> bool {
	if p.peek_tok.type == type {
		next_token(p)
		return true
	} else {
		peek_error(p, type)
		return false
	}
}

peek_error :: proc(p: ^Parser, type: token.Token_Type) {
	msg := fmt.aprintf(
		"expected next token to be '%s', got '%s' instead",
		type,
		p.peek_tok.type,
		allocator = p.allocator,
	)
	append(&p.errors, msg)
}
