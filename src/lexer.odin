
package main

import "core:strings"

Lexer :: struct {
	input:    string,
	pos:      int, // pos of current char
	read_pos: int, // pos after current char
	ch:       byte, // current char
}

lexer_init :: proc(input: string, allocator := context.allocator) -> ^Lexer {
	l := new(Lexer, allocator)
	l.input = input
	read_char(l)
	return l
}

next_token :: proc(l: ^Lexer) -> Token {
	tok: Token

	skip_whitespace(l)

	switch l.ch {
	case '=':
		if peek_char(l) == '=' {
			ch := l.ch
			read_char(l)
			tok = new_token(.EQ, ch, l.ch)
		} else {
			tok = new_token(.ASSIGN, l.ch)
		}
	case '!':
		if peek_char(l) == '=' {
			ch := l.ch
			read_char(l)
			tok = new_token(.NOT_EQ, ch, l.ch)
		} else {
			tok = new_token(.BANG, l.ch)
		}
	case ';':
		tok = new_token(.SEMICOLON, l.ch)
	case '(':
		tok = new_token(.LPAREN, l.ch)
	case ')':
		tok = new_token(.RPAREN, l.ch)
	case '{':
		tok = new_token(.LBRACE, l.ch)
	case '}':
		tok = new_token(.RBRACE, l.ch)
	case ',':
		tok = new_token(.COMMA, l.ch)
	case '+':
		tok = new_token(.PLUS, l.ch)
	case '-':
		tok = new_token(.MINUS, l.ch)
	case '/':
		tok = new_token(.SLASH, l.ch)
	case '*':
		tok = new_token(.ASTERISK, l.ch)
	case '<':
		tok = new_token(.LT, l.ch)
	case '>':
		tok = new_token(.GT, l.ch)
	case 0:
		tok.type = .EOF
		tok.literal = ""
	case:
		if is_letter(l.ch) {
			tok.literal = read_identifier(l)
			tok.type = lookup_ident(tok.literal)
			return tok
		} else if is_digit(l.ch) {
			tok.literal = read_integer(l)
			tok.type = .INT
			return tok
		} else {
			tok = new_token(.ILLEGAL, l.ch)
		}
	}

	read_char(l)
	return tok
}

skip_whitespace :: proc(l: ^Lexer) {
	for l.ch == ' ' || l.ch == '\t' || l.ch == '\n' || l.ch == '\r' {
		read_char(l)
	}
}

new_token :: proc(type: Token_Type, chars: ..byte) -> Token {
	literal := strings.clone_from_bytes(chars, context.temp_allocator)
	return Token{type, literal}
}

read_identifier :: proc(l: ^Lexer) -> string {
	start := l.pos
	for is_letter(l.ch) {
		read_char(l)
	}

	str := l.input[start:l.pos]
	return str
}

read_integer :: proc(l: ^Lexer) -> string {
	start := l.pos
	for is_digit(l.ch) {
		read_char(l)
	}

	s := l.input[start:l.pos]
	return s
}

read_char :: proc(l: ^Lexer) {
	if l.read_pos >= len(l.input) {
		l.ch = 0
	} else {
		l.ch = l.input[l.read_pos]
	}
	l.pos = l.read_pos
	l.read_pos += 1
}

peek_char :: proc(l: ^Lexer) -> byte {
	if l.read_pos >= len(l.input) {
		return 0
	} else {
		return l.input[l.read_pos]
	}
}

is_letter :: proc(ch: byte) -> bool {
	return 'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || '_' == ch
}

is_digit :: proc(ch: byte) -> bool {
	return '0' <= ch && ch <= '9'
}

