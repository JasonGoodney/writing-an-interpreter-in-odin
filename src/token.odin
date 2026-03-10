#+feature dynamic-literals

package main


Token :: struct {
	type:    Token_Type,
	literal: string,
}

Token_Type :: enum {
	ILLEGAL,
	EOF,
	IDENT,
	INT,

	// Operators
	ASSIGN,
	PLUS,
	MINUS,
	BANG,
	ASTERISK,
	SLASH,

	// Comparison
	LT,
	GT,
	EQ,
	NOT_EQ,
	COMMA,
	SEMICOLON,
	LPAREN,
	RPAREN,
	LBRACE,
	RBRACE,

	// Keywords
	FUNCTION,
	LET,
	TRUE,
	FALSE,
	IF,
	ELSE,
	RETURN,
}

token_string_table := [Token_Type]string {
	.ILLEGAL   = "ILLEGAL",
	.EOF       = "EOF",
	.IDENT     = "IDENT",
	.INT       = "INT",
	.COMMA     = "COMMA",
	.SEMICOLON = "SEMICOLON",
	.LBRACE    = "{",
	.RBRACE    = "}",
	.LPAREN    = "(",
	.RPAREN    = ")",
	.LET       = "LET",
	.FUNCTION  = "FUNCTION",
	.ASSIGN    = "=",
	.PLUS      = "+",
	.MINUS     = "-",
	.BANG      = "!",
	.ASTERISK  = "*",
	.SLASH     = "/",
	.LT        = "<",
	.GT        = ">",
	.EQ        = "==",
	.NOT_EQ    = "!=",
	.TRUE      = "TRUE",
	.FALSE     = "FALSE",
	.IF        = "IF",
	.ELSE      = "ELSE",
	.RETURN    = "RETURN",
}


token_string :: proc(tok: Token) -> string {
	if tok.type == .SEMICOLON && tok.literal == "\n" {
		return "newline"
	}
	return token_string_table[tok.type]
}

keywords := map[string]Token_Type {
	"fn"     = .FUNCTION,
	"let"    = .LET,
	"true"   = .TRUE,
	"false"  = .FALSE,
	"if"     = .IF,
	"else"   = .ELSE,
	"return" = .RETURN,
}

lookup_ident :: proc(ident: string) -> Token_Type {
	if tok, ok := keywords[ident]; ok {
		return tok
	}
	return .IDENT
}

