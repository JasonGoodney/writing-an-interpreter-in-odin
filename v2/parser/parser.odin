package parser

import "../ast"
import "../lexer"
import "../token"
import "base:runtime"
import "core:fmt"
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

	next_token(p)
	next_token(p)

	return p
}

parse_program :: proc(p: ^Parser) -> ast.Program {
	program: ast.Program
	program.stmts = make(type_of(program.stmts), p.allocator)

	for p.curr_tok.type != .EOF {
		stmt := parse_stmt(p)
		if stmt != {} {
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

	for p.curr_tok.type != .Semicolon {
		next_token(p)
	}

	return ast.Stmt{letstmt}
}

parse_return_stmt :: proc(p: ^Parser) -> ast.Stmt {
	retstmt := ast.Return_Stmt {
		token = p.curr_tok,
	}
	next_token(p)
	for p.curr_tok.type != .Semicolon {
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

// =========== Expressions ==============================

parse_expr :: proc(p: ^Parser, prec: Precedence) -> ast.Expr {
	prefix := p.prefix_parse_fns[p.curr_tok.type]
	if prefix == nil {
		return {}
	}
	left_expr := prefix(p)
	return left_expr
}

parse_ident :: proc(p: ^Parser) -> ast.Expr {
	ident := ast.Ident{p.curr_tok, p.curr_tok.literal}
	return ast.Expr{ident}
}

parse_int :: proc(p: ^Parser) -> ast.Expr {
	val, ok := strconv.parse_i64(p.curr_tok.literal)
	if !ok {
		return {}
	}
	integer := ast.Integer_Literal{p.curr_tok, val}
	return ast.Expr{integer}
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
