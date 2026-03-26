#+ feature dynamic-literals

package parser

import "../ast"
import "../lexer"
import "../token"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:strconv"

prefix_parse_fn :: proc(p: ^Parser) -> ^ast.Node
infix_parse_fn :: proc(p: ^Parser, left: ^ast.Node) -> ^ast.Node

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
	register_prefix(p, .Int, parse_int)
	register_prefix(p, .Bang, parse_prefix_expr)
	register_prefix(p, .Minus, parse_prefix_expr)
	register_prefix(p, .True, parse_boolean)
	register_prefix(p, .False, parse_boolean)
	register_prefix(p, .Left_Paren, parse_grouped_expr)
	register_prefix(p, .If, parse_if_expr)
	register_prefix(p, .Function, parse_function_literal)
	register_prefix(p, .String, parse_string_literal)
	register_prefix(p, .Left_Bracket, parse_array)
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

parse_program :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Program

	stmts := make([dynamic]ast.Node, p.allocator)
	for p.curr_tok.type != .EOF {
		stmt := parse_stmt(p)
		#partial switch stmt.kind {
		case .Let_Stmt, .Ret_Stmt, .Expr_Stmt, .Block_Stmt:
			append(&stmts, stmt^)
		}
		next_token(p)
	}
	node.program_stmts = stmts[:]
	return node
}

next_token :: proc(p: ^Parser) {
	p.curr_tok = p.peek_tok
	p.peek_tok = lexer.next_token(p.lexer)
}

parse_stmt :: proc(p: ^Parser) -> ^ast.Node {
	#partial switch p.curr_tok.type {
	case .Let:
		return parse_let_stmt(p)
	case .Return:
		return parse_return_stmt(p)
	case:
		return parse_expr_stmt(p)
	}
}

parse_let_stmt :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Let_Stmt
	node.token = p.curr_tok

	if !expect_peek(p, .Ident) {
		return {}
	}

	node.let_stmt_name = &ast.Node {
		kind = .Ident,
		token = p.curr_tok,
		ident_val = p.curr_tok.literal,
	}

	if !expect_peek(p, .Assign) {
		return {}
	}
	next_token(p)
	node.let_stmt_val = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}

	return node
}

parse_return_stmt :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Ret_Stmt
	node.token = p.curr_tok

	next_token(p)
	node.ret_stmt_val = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}
	return node
}

parse_expr_stmt :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Expr_Stmt
	node.token = p.curr_tok

	node.expr_stmt_expr = parse_expr(p, .Lowest)
	if p.peek_tok.type == .Semicolon {
		next_token(p)
	}
	return node
}

parse_block_stmt :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Block_Stmt
	node.token = p.curr_tok

	next_token(p)

	stmts := make([dynamic]ast.Node, p.allocator)
	for p.curr_tok.type != .Right_Brace && p.curr_tok.type != .EOF {
		stmt := parse_stmt(p)
		append(&stmts, stmt^)
		next_token(p)
	}
	return block
}

// =========== Expressions ==============================

parser_error :: proc(p: ^Parser, format: string, args: ..any) {
	msg := fmt.tprintf(format, ..args)
	append(&p.errors, msg)
}

parse_expr :: proc(p: ^Parser, prec: Precedence) -> ^ast.Node {
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

parse_ident :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Ident
	node.token = p.curr_tok
	node.ident_val = p.curr_tok.literal

	return node
}

parse_int :: proc(p: ^Parser) -> ^ast.Node {
	val, ok := strconv.parse_i64(p.curr_tok.literal)
	if !ok {
		parser_error(p, "could not parse %s as integer", p.curr_tok.literal)
		return {}
	}

	node := new(ast.Node, p.allocator)
	node.kind = .Int_Lit
	node.token = p.curr_tok
	node.int_lit_val = val

	return node
}

parse_string_literal :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .String_Lit
	node.token = p.curr_tok
	node.string_lit_val = p.curr_tok.literal

	return node
}

parse_array :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Array_Lit
	node.token = p.curr_tok

	elements := parse_expr_list(p, .Right_Bracket)
	node.array_lit_elems = elements[:]

	return node
}

parse_hash_literal :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Hash_Lit
	node.token = p.curr_tok

	pairs := make(map[^ast.Node]ast.Node, p.allocator)

	for p.peek_tok.type != .Right_Brace {
		next_token(p)
		key := new_clone(parse_expr(p, .Lowest), p.allocator)
		if !expect_peek(p, .Colon) {
			return {}
		}
		next_token(p)
		val := parse_expr(p, .Lowest)
		pairs[key] = val

		if p.peek_tok.type != .Right_Brace && !expect_peek(p, .Comma) {
			return {}
		}
	}
	if !expect_peek(p, .Right_Brace) {
		return {}
	}
	hash.pairs = pairs

	return node
}

parse_expr_list :: proc(p: ^Parser, end: token.Token_Type) -> []ast.Node {
	elems := make([dynamic]ast.Node, p.allocator)
	if p.peek_tok.type == end {
		next_token(p)
		return elems[:]
	}
	next_token(p)
	elem := parse_expr(p, .Lowest)
	append(&elems, elem^)
	for p.peek_tok.type == .Comma {
		next_token(p)
		next_token(p)
		elem := parse_expr(p, .Lowest)
		append(&elems, elem^)
	}
	if !expect_peek(p, end) {
		return {}
	}
	return elems[:]
}

parse_prefix_expr :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Prefix_Expr
	node.token = p.curr_tok
	node.prefix_expr_op = p.curr_tok.literal

	next_token(p)
	node.prefix_expr_right = parse_expr(p, .Prefix)

	return node
}

parse_infix_expr :: proc(p: ^Parser, left: ^ast.Node) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Infix_Expr
	node.token = p.curr_tok
	node.infix_expr_op = p.curr_tok.literal
	node.infix_expr_left = left

	precedence := curr_precedence(p)
	next_token(p)
	node.infix_expr_right = parse_expr(p, precedence)

	return node
}

parse_boolean :: proc(p: ^Parser) -> ^ast.Node {
	val, ok := strconv.parse_bool(p.curr_tok.literal)
	if !ok {
		parser_error(p, "could not parse %s as boolean", p.curr_tok.literal)
		return {}
	}

	node := new(ast.Node, p.allocator)
	node.kind = .Bool_Lit
	node.token = p.curr_tok
	node.bool_lit_val = val

	return node
}

parse_grouped_expr :: proc(p: ^Parser) -> ^ast.Node {
	next_token(p)
	inner := parse_expr(p, .Lowest)
	if !expect_peek(p, .Right_Paren) {
		parser_error(p, "missing closing parentheses", p.curr_tok.literal)
		return {}
	}
	return inner
}

parse_if_expr :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .If_Expr
	node.token = p.curr_tok

	if !expect_peek(p, .Left_Paren) {
		return {}
	}
	next_token(p)
	node.if_expr_cond = parse_expr(p, .Lowest)
	if !expect_peek(p, .Right_Paren) {
		return {}
	}
	if !expect_peek(p, .Left_Brace) {
		return {}
	}
	node.if_expr_then = parse_block_stmt(p)

	if p.peek_tok.type == .Else {
		next_token(p)
		if !expect_peek(p, .Left_Brace) {
			return {}
		}
		node.if_expr_else = parse_block_stmt(p)
	}

	return node
}

parse_function_literal :: proc(p: ^Parser) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Fn_Lit
	node.token = p.curr_tok

	if !expect_peek(p, .Left_Paren) {
		return {}
	}
	node.fn_lit_params = parse_function_parameters(p)
	if !expect_peek(p, .Left_Brace) {
		return {}
	}
	node.fn_lit_body = parse_block_stmt(p)

	return node
}

parse_function_parameters :: proc(p: ^Parser) -> []ast.Node {
	idents := make([dynamic]ast.Ident, p.allocator)
	if p.peek_tok.type == .Right_Paren {
		next_token(p)
		return idents
	}
	next_token(p)
	ident := ast.Node {
		kind      = .Ident,
		token     = p.curr_tok,
		ident_val = p.curr_tok.literal,
	}
	append(&idents, ident)
	for p.peek_tok.type == .Comma {
		next_token(p)
		next_token(p)
		ident := ast.Node {
			kind      = .Ident,
			token     = p.curr_tok,
			ident_val = p.curr_tok.literal,
		}
		append(&idents, ident)
	}
	if !expect_peek(p, .Right_Paren) {
		return {}
	}
	return idents[:]
}

parse_call_expr :: proc(p: ^Parser, function: ^ast.Node) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Call_Expr
	node.token = p.curr_tok
	node.call_expr_fn = function
	node.call_expr_fn = parse_expr_list(p, .Right_Paren)

	return node
}

parser_index_expr :: proc(p: ^Parser, left: ^ast.Node) -> ^ast.Node {
	node := new(ast.Node, p.allocator)
	node.kind = .Index_Expr
	node.token = p.curr_tok
	node.index_expr_left = left

	next_token(p)
	node.index_expr_index = parse_expr(p, .Lowest)
	if !expect_peek(p, .Right_Bracket) {
		return {}
	}

	return node
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
