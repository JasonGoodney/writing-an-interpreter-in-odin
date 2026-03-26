package lexer

import "../token"

import "core:testing"

expect :: proc(t: ^testing.T, ok: bool, format: string, args: ..any) -> bool {
	result := testing.expectf(t, ok, format, ..args)
	assert(result)
	return result
}

@(test)
test_next_token_1 :: proc(t: ^testing.T) {
	input := `=+(){},;`
	tests := []struct {
		expected_type:    token.Token_Type,
		expected_literal: string,
	} {
		{.Assign, "="},
		{.Plus, "+"},
		{.Left_Paren, "("},
		{.Right_Paren, ")"},
		{.Left_Brace, "{"},
		{.Right_Brace, "}"},
		{.Comma, ","},
		{.Semicolon, ";"},
	}

	l := init(input, context.temp_allocator)
	for tt, i in tests {
		tok := next_token(l)

		expect(
			t,
			tok.type == tt.expected_type,
			"test[%d] - tokentype wrong. expected=`%s`, got=`%s`",
			i,
			token.token_string_table[tt.expected_type],
			token.token_string_table[tok.type],
		)
		expect(
			t,
			tok.literal == tt.expected_literal,
			"test[%d] - literal wrong. expected=`%s`, got=`%s`",
			i,
			tt.expected_literal,
			tok.literal,
		)
	}
}

@(test)
test_next_token_2 :: proc(t: ^testing.T) {
	input := `let five = 5;
		let ten = 10;
		let add = fn(x, y) {
		x + y;
		};
		let result = add(five, ten);
`
	tests := []struct {
		expected_type:    token.Token_Type,
		expected_literal: string,
	} {
		{.Let, "let"},
		{.Ident, "five"},
		{.Assign, "="},
		{.Int, "5"},
		{.Semicolon, ";"},
		{.Let, "let"},
		{.Ident, "ten"},
		{.Assign, "="},
		{.Int, "10"},
		{.Semicolon, ";"},
		{.Let, "let"},
		{.Ident, "add"},
		{.Assign, "="},
		{.Function, "fn"},
		{.Left_Paren, "("},
		{.Ident, "x"},
		{.Comma, ","},
		{.Ident, "y"},
		{.Right_Paren, ")"},
		{.Left_Brace, "{"},
		{.Ident, "x"},
		{.Plus, "+"},
		{.Ident, "y"},
		{.Semicolon, ";"},
		{.Right_Brace, "}"},
		{.Semicolon, ";"},
		{.Let, "let"},
		{.Ident, "result"},
		{.Assign, "="},
		{.Ident, "add"},
		{.Left_Paren, "("},
		{.Ident, "five"},
		{.Comma, ","},
		{.Ident, "ten"},
		{.Right_Paren, ")"},
		{.Semicolon, ";"},
		{.EOF, ""},
	}

	l := init(input, context.temp_allocator)
	for tt, i in tests {
		tok := next_token(l)

		expect(
			t,
			tok.type == tt.expected_type,
			"test[%d] - tokentype wrong. expected=`%s`, got=`%s`",
			i,
			token.token_string_table[tt.expected_type],
			token.token_string_table[tok.type],
		)
		expect(
			t,
			tok.literal == tt.expected_literal,
			"test[%d] - literal wrong. expected=`%s`, got=`%s`",
			i,
			tt.expected_literal,
			tok.literal,
		)
	}
}

@(test)
test_next_token_3 :: proc(t: ^testing.T) {
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
	"foobar";
	"foo bar";
	"Hello, World";
	[1, 2];
	{"foo": "bar"}
`

	tests := []struct {
		expected_type:    token.Token_Type,
		expected_literal: string,
	} {
		{.Let, "let"},
		{.Ident, "five"},
		{.Assign, "="},
		{.Int, "5"},
		{.Semicolon, ";"},
		{.Let, "let"},
		{.Ident, "ten"},
		{.Assign, "="},
		{.Int, "10"},
		{.Semicolon, ";"},
		{.Let, "let"},
		{.Ident, "add"},
		{.Assign, "="},
		{.Function, "fn"},
		{.Left_Paren, "("},
		{.Ident, "x"},
		{.Comma, ","},
		{.Ident, "y"},
		{.Right_Paren, ")"},
		{.Left_Brace, "{"},
		{.Ident, "x"},
		{.Plus, "+"},
		{.Ident, "y"},
		{.Semicolon, ";"},
		{.Right_Brace, "}"},
		{.Semicolon, ";"},
		{.Let, "let"},
		{.Ident, "result"},
		{.Assign, "="},
		{.Ident, "add"},
		{.Left_Paren, "("},
		{.Ident, "five"},
		{.Comma, ","},
		{.Ident, "ten"},
		{.Right_Paren, ")"},
		{.Semicolon, ";"},
		{.Bang, "!"},
		{.Minus, "-"},
		{.Slash, "/"},
		{.Asterisk, "*"},
		{.Int, "5"},
		{.Semicolon, ";"},
		{.Int, "5"},
		{.Less, "<"},
		{.Int, "10"},
		{.Greater, ">"},
		{.Int, "5"},
		{.Semicolon, ";"},
		{.If, "if"},
		{.Left_Paren, "("},
		{.Int, "5"},
		{.Less, "<"},
		{.Int, "10"},
		{.Right_Paren, ")"},
		{.Left_Brace, "{"},
		{.Return, "return"},
		{.True, "true"},
		{.Semicolon, ";"},
		{.Right_Brace, "}"},
		{.Else, "else"},
		{.Left_Brace, "{"},
		{.Return, "return"},
		{.False, "false"},
		{.Semicolon, ";"},
		{.Right_Brace, "}"},
		{.Int, "10"},
		{.Equal, "=="},
		{.Int, "10"},
		{.Semicolon, ";"},
		{.Int, "10"},
		{.Not_Equal, "!="},
		{.Int, "9"},
		{.Semicolon, ";"},
		{.String, "foobar"},
		{.Semicolon, ";"},
		{.String, "foo bar"},
		{.Semicolon, ";"},
		{.String, "Hello, World"},
		{.Semicolon, ";"},
		{.Left_Bracket, "["},
		{.Int, "1"},
		{.Comma, ","},
		{.Int, "2"},
		{.Right_Bracket, "]"},
		{.Semicolon, ";"},
		{.Left_Brace, "{"},
		{.String, "foo"},
		{.Colon, ":"},
		{.String, "bar"},
		{.Right_Brace, "}"},
		{.EOF, ""},
	}

	lex := init(input, context.allocator)

	for test, i in tests {
		tok := next_token(lex)
		expect(
			t,
			tok.type == test.expected_type,
			"test[%d] - tokentype wrong. expected=`%s`, got=`%s`",
			i,
			token.token_string_table[test.expected_type],
			token.token_string_table[tok.type],
		)
		expect(
			t,
			tok.literal == test.expected_literal,
			"test[%d] - literal wrong. expected=`%s`, got=`%s`",
			i,
			test.expected_literal,
			tok.literal,
		)

	}
}
