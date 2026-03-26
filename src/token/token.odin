#+ feature dynamic-literals
package token

Token_Type :: enum {
	Illegal,
	EOF,
	Ident,
	Int,
	String,
	Assign,
	Bang,
	Slash,
	Asterisk,
	Minus,
	Plus,
	Comma,
	Semicolon,
	Colon,
	Left_Paren,
	Right_Paren,
	Left_Brace,
	Right_Brace,
	Left_Bracket,
	Right_Bracket,
	Less,
	Greater,
	Equal,
	Not_Equal,
	Function,
	Let,
	If,
	Else,
	True,
	False,
	Return,
}

token_string_table := map[Token_Type]string {
	.Illegal       = "ILLEGAL",
	.EOF           = "EOF",
	.Ident         = "IDENT",
	.Int           = "INT",
	.String        = "STRING",
	.Assign        = "=",
	.Plus          = "+",
	.Comma         = ",",
	.Semicolon     = ";",
	.Colon         = ":",
	.Left_Paren    = "(",
	.Right_Paren   = ")",
	.Left_Brace    = "{",
	.Right_Brace   = "}",
	.Left_Bracket  = "[",
	.Right_Bracket = "]",
	.Bang          = "!",
	.Slash         = "/",
	.Asterisk      = "*",
	.Minus         = "-",
	.Less          = "<",
	.Greater       = ">",
	.Equal         = "==",
	.Not_Equal     = "!=",
	.If            = "IF",
	.Else          = "ELSE",
	.True          = "TRUE",
	.False         = "FALSE",
	.Function      = "FUNCTION",
	.Let           = "LET",
	.Return        = "RETURN",
}

Token :: struct {
	type:    Token_Type,
	literal: string,
}

keywords := map[string]Token_Type {
	"fn"     = .Function,
	"let"    = .Let,
	"if"     = .If,
	"else"   = .Else,
	"true"   = .True,
	"false"  = .False,
	"return" = .Return,
}

lookup_ident :: proc(ident: string) -> Token_Type {
	if tok, ok := keywords[ident]; ok {
		return tok
	}
	return .Ident
}

