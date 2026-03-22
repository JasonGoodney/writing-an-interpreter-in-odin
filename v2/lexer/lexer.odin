package lexer

import "../token"
import "base:runtime"
import "core:fmt"
import "core:strings"

Lexer :: struct {
	input:    string,
	pos:      int,
	read_pos: int,
	ch:       byte,
}

init :: proc(input: string, allocator := context.allocator) -> ^Lexer {
	l := new(Lexer, allocator)
	l.input = input
	read_char(l)
	return l
}

next_token :: proc(l: ^Lexer) -> token.Token {
	tok: token.Token

	skip_whitespace(l)
	switch l.ch {
	case '=':
		if peek_token(l) == '=' {
			ch := l.ch
			read_char(l)
			tok = new_token(.Equal, ch, l.ch)
		} else {
			tok = new_token(.Assign, l.ch)
		}
	case '!':
		if peek_token(l) == '=' {
			ch := l.ch
			read_char(l)
			tok = new_token(.Not_Equal, ch, l.ch)
		} else {
			tok = new_token(.Bang, l.ch)
		}
	case ';':
		tok = new_token(.Semicolon, l.ch)
	case '(':
		tok = new_token(.Left_Paren, l.ch)
	case ')':
		tok = new_token(.Right_Paren, l.ch)
	case '{':
		tok = new_token(.Left_Brace, l.ch)
	case '}':
		tok = new_token(.Right_Brace, l.ch)
	case ',':
		tok = new_token(.Comma, l.ch)
	case '+':
		tok = new_token(.Plus, l.ch)
	case '-':
		tok = new_token(.Minus, l.ch)
	case '/':
		tok = new_token(.Slash, l.ch)
	case '*':
		tok = new_token(.Asterisk, l.ch)
	case '<':
		tok = new_token(.Less, l.ch)
	case '>':
		tok = new_token(.Greater, l.ch)
	case 0:
		tok.literal = ""
		tok.type = .EOF
	case:
		if is_letter(l.ch) {
			tok.literal = read_identifier(l)
			tok.type = token.lookup_ident(tok.literal)
			return tok
		} else if is_digit(l.ch) {
			tok.literal = read_number(l)
			tok.type = .Int
			return tok
		} else {
			tok = new_token(.Illegal, l.ch)
		}
	}

	read_char(l)
	return tok
}

new_token :: proc(type: token.Token_Type, chars: ..byte) -> token.Token {
	literal := strings.clone_from_bytes(chars, context.temp_allocator)
	return token.Token{type, literal}
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

read_identifier :: proc(l: ^Lexer) -> string {
	start := l.pos
	for is_letter(l.ch) {
		read_char(l)
	}
	ident := l.input[start:l.pos]
	return ident
}

read_number :: proc(l: ^Lexer) -> string {
	start := l.pos
	for is_digit(l.ch) {
		read_char(l)
	}
	ident := l.input[start:l.pos]
	return ident
}

is_letter :: proc(ch: byte) -> bool {
	return 'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || ch == '_'
}

is_digit :: proc(ch: byte) -> bool {
	return '0' <= ch && ch <= '9'
}

skip_whitespace :: proc(l: ^Lexer) {
	for l.ch == ' ' || l.ch == '\t' || l.ch == '\r' || l.ch == '\n' {
		read_char(l)
	}
}

peek_token :: proc(l: ^Lexer) -> byte {
	if l.read_pos >= len(l.input) {
		return 0
	}
	return l.input[l.read_pos]
}
