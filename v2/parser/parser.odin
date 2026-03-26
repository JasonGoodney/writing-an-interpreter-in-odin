#+ feature dynamic-literals

package parser

import "../ast"
import "../lexer"
import "../token"
import "base:runtime"
import "core:fmt"
import "core:strconv"

prefix_parse_fn :: proc(p: ^Parser) -> ^ast.Expr
infix_parse_fn :: proc(p: ^Parser, left: ^ast.Expr) -> ^ast.Expr

Precedence :: enum {
	Lowest,
	Equals,
	Less_Greater,
	Sum,
	Product,
	Prefix,
	Call,
	Index,
}

precedence_table := map[token.Token_Type]Precedence {
	.Equal        = .Equals,
	.Not_Equal    = .Equals,
	.Less         = .Less_Greater,
	.Greater      = .Less_Greater,
	.Plus         = .Sum,
	.Minus        = .Sum,
	.Slash        = .Product,
	.Asterisk     = .Product,
	.Left_Paren   = .Call,
	.Left_Bracket = .Index,
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
	register_prefix(p, .Int, parse_integer_literal)
	register_prefix(p, .Bang, parse_prefix_expr)
	register_prefix(p, .Minus, parse_prefix_expr)
	register_prefix(p, .True, parse_boolean)
	register_prefix(p, .False, parse_boolean)
	register_prefix(p, .Left_Paren, parse_grouped_expr)
	register_prefix(p, .If, parse_if_expr)
	register_prefix(p, .Function, parse_function_literal)
	register_prefix(p, .String, parse_string_literal)
	register_prefix(p, .Left_Bracket, parse_array_literal)
	register_prefix(p, .Left_Brace, parse_hash_literal)

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
	register_infix(p, .Left_Bracket, parser_index_expr)

	next_token(p)
	next_token(p)

	return p
}

parse_program :: proc(p: ^Parser) -> ^ast.Program {
	program := ast.new(ast.Program, p.allocator)

	stmts := make([dynamic]^ast.Stmt, p.allocator)
	for p.curr_tok.type != .EOF {
		stmt := parse_stmt(p)
		#partial switch v in stmt.derived_stmt {
		case ^ast.Let_Stmt, ^ast.Return_Stmt, ^ast.Expr_Stmt, ^ast.Block_Stmt:
			append(&stmts, stmt)
		}
		next_token(p)
	}
	program.stmts = stmts[:]
	return program
}

next_token :: proc(p: ^Parser) {
	p.curr_tok = p.peek_tok
	p.peek_tok = lexer.next_token(p.lexer)
}

parse_stmt :: proc(p: ^Parser) -> ^ast.Stmt {
	#partial switch p.curr_tok.type {
	case .Let:
		return parse_let_stmt(p)
	case .Return:
		return parse_return_stmt(p)
	case:
		return parse_expr_stmt(p)
	}
}

parse_let_stmt :: proc(p: ^Parser) -> ^ast.Let_Stmt {
	ls := ast.new(ast.Let_Stmt, p.curr_tok, p.allocator)

	if !expect_peek(p, .Ident) {
		return {}
	}

	name := ast.new(ast.Ident, p.curr_tok, p.allocator)
	name.value = p.curr_tok.literal
	ls.name = name

	if !expect_peek(p, .Assign) {
		return {}
	}
	next_token(p)

	ls.value = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}

	return ls
}

parse_return_stmt :: proc(p: ^Parser) -> ^ast.Return_Stmt {
	rs := ast.new(ast.Return_Stmt, p.curr_tok, p.allocator)

	next_token(p)
	rs.return_value = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}
	return rs
}

parse_expr_stmt :: proc(p: ^Parser) -> ^ast.Expr_Stmt {
	es := ast.new(ast.Expr_Stmt, p.curr_tok, p.allocator)

	es.expr = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}
	return es
}

parse_block_stmt :: proc(p: ^Parser) -> ^ast.Block_Stmt {
	bs := ast.new(ast.Block_Stmt, p.curr_tok, p.allocator)

	next_token(p)

	stmts := make([dynamic]^ast.Stmt, p.allocator)
	for p.curr_tok.type != .Right_Brace && p.curr_tok.type != .EOF {
		stmt := parse_stmt(p)
		append(&stmts, stmt)
		next_token(p)
	}

	bs.stmts = stmts[:]
	return bs
}

// =========== Expressions ==============================

parser_error :: proc(p: ^Parser, format: string, args: ..any) {
	msg := fmt.tprintf(format, ..args)
	append(&p.errors, msg)
}

parse_expr :: proc(p: ^Parser, prec: Precedence) -> ^ast.Expr {
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
		left_expr = infix(p, left_expr)
	}

	return left_expr
}

parse_ident :: proc(p: ^Parser) -> ^ast.Expr {
	ident := ast.new(ast.Ident, p.curr_tok, p.allocator)
	ident.value = p.curr_tok.literal
	return ident
}

parse_integer_literal :: proc(p: ^Parser) -> ^ast.Expr {
	val, ok := strconv.parse_i64(p.curr_tok.literal)
	if !ok {
		parser_error(p, "could not parse %s as integer", p.curr_tok.literal)
		return {}
	}

	il := ast.new(ast.Integer_Literal, p.curr_tok, p.allocator)
	il.value = val
	return il
}

parse_string_literal :: proc(p: ^Parser) -> ^ast.Expr {
	sl := ast.new(ast.String_Literal, p.curr_tok, p.allocator)
	sl.value = p.curr_tok.literal
	return sl
}

parse_array_literal :: proc(p: ^Parser) -> ^ast.Expr {
	al := ast.new(ast.Array_Literal, p.curr_tok, p.allocator)
	elements := parse_expr_list(p, .Right_Bracket)
	al.elements = elements[:]
	return al
}

parse_hash_literal :: proc(p: ^Parser) -> ^ast.Expr {
	hl := ast.new(ast.Hash_Literal, p.curr_tok, p.allocator)

	hl.pairs = make(type_of(hl.pairs), p.allocator)

	for p.peek_tok.type != .Right_Brace {
		next_token(p)
		key := parse_expr(p, .Lowest)
		if !expect_peek(p, .Colon) {
			return {}
		}
		next_token(p)
		val := parse_expr(p, .Lowest)
		hl.pairs[key] = val

		if p.peek_tok.type != .Right_Brace && !expect_peek(p, .Comma) {
			return {}
		}
	}
	if !expect_peek(p, .Right_Brace) {
		return {}
	}

	return hl
}

parse_expr_list :: proc(p: ^Parser, end: token.Token_Type) -> []^ast.Expr {
	elems := make([dynamic]^ast.Expr, p.allocator)
	if p.peek_tok.type == end {
		next_token(p)
		return elems[:]
	}
	next_token(p)
	elem := parse_expr(p, .Lowest)
	append(&elems, elem)
	for p.peek_tok.type == .Comma {
		next_token(p)
		next_token(p)
		elem := parse_expr(p, .Lowest)
		append(&elems, elem)
	}
	if !expect_peek(p, end) {
		return {}
	}
	return elems[:]
}

parse_prefix_expr :: proc(p: ^Parser) -> ^ast.Expr {
	pe := ast.new(ast.Prefix_Expr, p.curr_tok, p.allocator)
	pe.op = p.curr_tok.literal

	next_token(p)
	pe.right = parse_expr(p, .Prefix)

	return pe
}

parse_infix_expr :: proc(p: ^Parser, left: ^ast.Expr) -> ^ast.Expr {
	ie := ast.new(ast.Infix_Expr, p.curr_tok, p.allocator)
	ie.op = p.curr_tok.literal
	ie.left = left

	precedence := curr_precedence(p)
	next_token(p)
	ie.right = parse_expr(p, precedence)

	return ie
}

parse_boolean :: proc(p: ^Parser) -> ^ast.Expr {
	val, ok := strconv.parse_bool(p.curr_tok.literal)
	if !ok {
		parser_error(p, "could not parse %s as boolean", p.curr_tok.literal)
		return {}
	}

	bl := ast.new(ast.Boolean, p.curr_tok, p.allocator)
	bl.value = val
	return bl
}

parse_grouped_expr :: proc(p: ^Parser) -> ^ast.Expr {
	next_token(p)
	inner := parse_expr(p, .Lowest)
	if !expect_peek(p, .Right_Paren) {
		parser_error(p, "missing closing parentheses", p.curr_tok.literal)
		return {}
	}
	return inner
}

parse_if_expr :: proc(p: ^Parser) -> ^ast.Expr {
	ie := ast.new(ast.If_Expr, p.curr_tok, p.allocator)

	if !expect_peek(p, .Left_Paren) {
		return {}
	}
	next_token(p)
	ie.condition = parse_expr(p, .Lowest)
	if !expect_peek(p, .Right_Paren) {
		return {}
	}
	if !expect_peek(p, .Left_Brace) {
		return {}
	}
	ie.consequence = parse_block_stmt(p)

	if p.peek_tok.type == .Else {
		next_token(p)
		if !expect_peek(p, .Left_Brace) {
			return {}
		}
		ie.alternative = parse_block_stmt(p)
	}

	return ie
}

parse_function_literal :: proc(p: ^Parser) -> ^ast.Expr {
	fl := ast.new(ast.Function_Literal, p.curr_tok, p.allocator)

	if !expect_peek(p, .Left_Paren) {
		return {}
	}
	fl.parameters = parse_function_parameters(p)
	if !expect_peek(p, .Left_Brace) {
		return {}
	}
	fl.body = parse_block_stmt(p)

	return fl
}

parse_function_parameters :: proc(p: ^Parser) -> []^ast.Ident {
	idents := make([dynamic]^ast.Ident, p.allocator)
	if p.peek_tok.type == .Right_Paren {
		next_token(p)
		return idents[:]
	}
	next_token(p)

	ident := ast.new(ast.Ident, p.curr_tok, p.allocator)
	ident.value = p.curr_tok.literal
	append(&idents, ident)

	for p.peek_tok.type == .Comma {
		next_token(p)
		next_token(p)
		ident := ast.new(ast.Ident, p.curr_tok, p.allocator)
		ident.value = p.curr_tok.literal
		append(&idents, ident)
	}
	if !expect_peek(p, .Right_Paren) {
		return {}
	}
	return idents[:]
}

parse_call_expr :: proc(p: ^Parser, function: ^ast.Expr) -> ^ast.Expr {
	ce := ast.new(ast.Call_Expr, p.curr_tok, p.allocator)
	ce.function = function
	ce.arguments = parse_expr_list(p, .Right_Paren)
	return ce
}

parser_index_expr :: proc(p: ^Parser, left: ^ast.Expr) -> ^ast.Expr {
	ie := ast.new(ast.Index_Expr, p.curr_tok)
	ie.left = left

	next_token(p)
	ie.index = parse_expr(p, .Lowest)
	if !expect_peek(p, .Right_Bracket) {
		return {}
	}

	return ie
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
