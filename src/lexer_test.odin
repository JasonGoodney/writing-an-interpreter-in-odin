package main

import "core:testing"

@(test)
test_next_token :: proc(t: ^testing.T) {
	input := `let five = 5;
	let ten = 10;

	let add = fn(x,y) {
		x + y;
	};

	let result = add(five, ten);
	!-/*5;
	5 < 10 > 5;

	if (5 < 10) {
		return true;
	} else {
		return false;
	}

	10 == 10;
	10 != 9;
	`

	tests := []struct {
		expected_type:    Token_Type,
		expected_literal: string,
	} {
		{.LET, "let"},
		{.IDENT, "five"},
		{.ASSIGN, "="},
		{.INT, "5"},
		{.SEMICOLON, ";"},
		{.LET, "let"},
		{.IDENT, "ten"},
		{.ASSIGN, "="},
		{.INT, "10"},
		{.SEMICOLON, ";"},
		{.LET, "let"},
		{.IDENT, "add"},
		{.ASSIGN, "="},
		{.FUNCTION, "fn"},
		{.LPAREN, "("},
		{.IDENT, "x"},
		{.COMMA, ","},
		{.IDENT, "y"},
		{.RPAREN, ")"},
		{.LBRACE, "{"},
		{.IDENT, "x"},
		{.PLUS, "+"},
		{.IDENT, "y"},
		{.SEMICOLON, ";"},
		{.RBRACE, "}"},
		{.SEMICOLON, ";"},
		{.LET, "let"},
		{.IDENT, "result"},
		{.ASSIGN, "="},
		{.IDENT, "add"},
		{.LPAREN, "("},
		{.IDENT, "five"},
		{.COMMA, ","},
		{.IDENT, "ten"},
		{.RPAREN, ")"},
		{.SEMICOLON, ";"},
		{.BANG, "!"},
		{.MINUS, "-"},
		{.SLASH, "/"},
		{.ASTERISK, "*"},
		{.INT, "5"},
		{.SEMICOLON, ";"},
		{.INT, "5"},
		{.LT, "<"},
		{.INT, "10"},
		{.GT, ">"},
		{.INT, "5"},
		{.SEMICOLON, ";"},
		{.IF, "if"},
		{.LPAREN, "("},
		{.INT, "5"},
		{.LT, "<"},
		{.INT, "10"},
		{.RPAREN, ")"},
		{.LBRACE, "{"},
		{.RETURN, "return"},
		{.TRUE, "true"},
		{.SEMICOLON, ";"},
		{.RBRACE, "}"},
		{.ELSE, "else"},
		{.LBRACE, "{"},
		{.RETURN, "return"},
		{.FALSE, "false"},
		{.SEMICOLON, ";"},
		{.RBRACE, "}"},
		{.INT, "10"},
		{.EQ, "=="},
		{.INT, "10"},
		{.SEMICOLON, ";"},
		{.INT, "10"},
		{.NOT_EQ, "!="},
		{.INT, "9"},
		{.SEMICOLON, ";"},
		{.EOF, ""},
	}

	lex := lexer_init(input, context.allocator)

	for test, i in tests {
		tok := lexer_next_token(lex)
		testing.expectf(
			t,
			tok.type == test.expected_type,
			"test[%d] - tokentype wrong. expected=`%s`, got=`%s`",
			i,
			token_string_table[test.expected_type],
			token_string_table[tok.type],
		)
		testing.expectf(
			t,
			tok.literal == test.expected_literal,
			"test[%d] - literal wrong. expected=`%s`, got=`%s`",
			i,
			test.expected_literal,
			tok.literal,
		)

	}
}

