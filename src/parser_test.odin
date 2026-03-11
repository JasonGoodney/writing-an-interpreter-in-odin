package main

import "core:fmt"
import "core:testing"

check_parse_errors :: proc(t: ^testing.T, p: ^Parser) {
	errors := p.errors

	if len(errors) == 0 {
		return
	}

	fmt.printfln("parser has %d errors", len(errors))
	for msg in errors {
		fmt.printfln("parse error: %s", msg)
	}

	testing.fail_now(t)
}

setup_and_parse_program :: proc(t: ^testing.T, input: string) -> ^Program {
	alloc := context.temp_allocator
	defer free_all(alloc)
	l := lexer_init(input, alloc)
	p := parser_init(l, alloc)
	prog := parse_program(p)
	check_parse_errors(t, p)
	return prog
}

@(test)
test_let_statements :: proc(t: ^testing.T) {
	input := `
		let x = 5;
		let y = 10;
		let foobar = 838383;
	`
	alloc := context.temp_allocator

	l := lexer_init(input, alloc)
	p := parser_init(l, alloc)

	program := parse_program(p)
	check_parse_errors(t, p)

	testing.expectf(t, program != nil, "parse_program() return nil")
	testing.expectf(
		t,
		len(program.statements) == 3,
		"program.statements does not contain 3 statements. got=`%d`",
		len(program.statements),
	)

	tests := []struct {
		expected_ident: string,
	}{{"x"}, {"y"}, {"foobar"}}

	for tt, i in tests {
		stmt := program.statements[i]
		#partial switch s in stmt.variant {
		case Let_Statement:
			testing.expectf(
				t,
				s.name.value == tt.expected_ident,
				"s.name.value not `%s`, got=`%s`",
				tt.expected_ident,
				s.name.value,
			)
		case Expression_Statement:
			#partial switch &e in s.expr.variant {
			case Identifier:
				testing.expectf(
					t,
					e.value == tt.expected_ident,
					"s.value not `%s`, got=`%s`",
					tt.expected_ident,
					e.value,
				)
			}
		}
	}
}

@(test)
test_return_statements :: proc(t: ^testing.T) {
	input := `
		return 5;
		return 10;
		return 993322;
	`
	alloc := context.allocator
	defer free_all(alloc)

	l := lexer_init(input, alloc)
	p := parser_init(l, alloc)

	program := parse_program(p)
	check_parse_errors(t, p)

	testing.expectf(t, program != nil, "parse_program() return nil")
	testing.expectf(
		t,
		len(program.statements) == 3,
		"program.statements does not contain 3 statements. got=`%d`",
		len(program.statements),
	)

	for stmt in program.statements {
		#partial switch s in stmt.variant {
		case Return_Statement:
			testing.expectf(
				t,
				s.token.literal == "return",
				"s.token.literal not `return`, got=`%s`",
				s.token.literal,
			)
		case:
			fmt.printfln("stmt not Return_Statement, got=`%v`", s)
		}
	}
}


@(test)
test_identifier :: proc(t: ^testing.T) {
	input := "foobar;"
	alloc := context.temp_allocator
	l := lexer_init(input, alloc)
	p := parser_init(l, alloc)
	prog := parse_program(p)
	check_parse_errors(t, p)

	testing.expectf(
		t,
		len(prog.statements) == 1,
		"program has not enough statements, got=`%d`",
		len(prog.statements),
	)
	stmt, ok := prog.statements[0].variant.(Expression_Statement)
	testing.expectf(
		t,
		ok,
		"prog.statements[0] is not Expression_Statement. got=`%T`",
		prog.statements[0].variant,
	)
	ident, ident_ok := stmt.expr.variant.(Identifier)
	testing.expectf(t, ident_ok, "expr not Identifier. got=`%T`", stmt.expr.variant)
	testing.expectf(
		t,
		ident.value == "foobar",
		"ident.value not %s. got=`%s`",
		"foobar",
		ident.value,
	)
	testing.expectf(
		t,
		ident.token.literal == "foobar",
		"ident.token.literal not %s. got=`%s`",
		"foobar",
		ident.token.literal,
	)
}

@(test)
test_integer_literal :: proc(t: ^testing.T) {
	alloc := context.temp_allocator

	input := "5;"
	l := lexer_init(input, alloc)
	p := parser_init(l, alloc)
	prog := parse_program(p)
	check_parse_errors(t, p)

	testing.expectf(
		t,
		len(prog.statements) == 1,
		"program has not enough statements, got=`%d`",
		len(prog.statements),
	)
	stmt, ok := prog.statements[0].variant.(Expression_Statement)
	testing.expectf(
		t,
		ok,
		"prog.statements[0] is not Expression_Statement. got=`%T`",
		prog.statements[0].variant,
	)
	expr, expr_ok := stmt.expr.variant.(Integer_Literal)
	testing.expectf(t, expr_ok, "expr not Integer_Literal. got=`%T`", stmt.expr.variant)
	testing.expectf(t, expr.value == 5, "expr.value expected=`%d`. got=`%d`", 5, expr.value)
	testing.expectf(
		t,
		expr.token.literal == "5",
		"expr.token.literal not %s. got=`%s`",
		"5",
		expr.token.literal,
	)
}

@(test)
test_prefix_expressions :: proc(t: ^testing.T) {
	tests := []struct {
		input:   string,
		op:      string,
		int_val: i64,
	}{{"!5;", "!", 5}, {"-15;", "-", 15}}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		check_parse_errors(t, p)

		testing.expectf(
			t,
			len(prog.statements) == 1,
			"program has not enough statements, got=`%d`",
			len(prog.statements),
		)
		stmt, ok := prog.statements[0].variant.(Expression_Statement)
		testing.expectf(
			t,
			ok,
			"prog.statements[0] is not Expression_Statement. got=`%T`",
			prog.statements[0].variant,
		)
		expr, expr_ok := stmt.expr.variant.(Prefix_Expression)
		testing.expectf(t, expr_ok, "expr not Prefix_Expression. got=`%T`", stmt.expr.variant)
		testing.expectf(t, expr.op == tt.op, "expr.op expected=`%s`. got=`%s`", tt.op, expr.op)

		if !_test_integer_literal(t, expr.right, tt.int_val) {
			testing.fail_now(t)
		}
	}
}

@(test)
test_infix_expressions :: proc(t: ^testing.T) {
	tests := []struct {
		input:     string,
		left_val:  i64,
		op:        string,
		right_val: i64,
	} {
		{"5 + 5;", 5, "+", 5},
		{"5 - 5;", 5, "-", 5},
		{"5 * 5;", 5, "*", 5},
		{"5 / 5;", 5, "/", 5},
		{"5 > 5;", 5, ">", 5},
		{"5 < 5;", 5, "<", 5},
		{"5 == 5;", 5, "==", 5},
		{"5 != 5;", 5, "!=", 5},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		check_parse_errors(t, p)

		testing.expectf(
			t,
			len(prog.statements) == 1,
			"program has not enough statements, got=`%d`",
			len(prog.statements),
		)
		stmt, ok := prog.statements[0].variant.(Expression_Statement)
		testing.expectf(
			t,
			ok,
			"prog.statements[0] is not Expression_Statement. got=`%T`",
			prog.statements[0].variant,
		)

		expr, expr_ok := stmt.expr.variant.(Infix_Expression)
		testing.expectf(t, expr_ok, "expr not Infix_Expression. got=`%T`", stmt.expr.variant)

		if !_test_integer_literal(t, expr.left, tt.left_val) {
			testing.fail_now(t)
		}

		testing.expectf(t, expr.op == tt.op, "expr.op expected=`%s`. got=`%s`", tt.op, expr.op)

		if !_test_integer_literal(t, expr.right, tt.right_val) {
			testing.fail_now(t)
		}
	}
}

@(test)
test_operator_precedence_parsing :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: string,
	} {
		{"-a * b", "((-a) * b)"},
		{"!-a", "(!(-a))"},
		{"a + b + c", "((a + b) + c)"},
		{"a + b - c", "((a + b) - c)"},
		{"a * b * c", "((a * b) * c)"},
		{"a * b / c", "((a * b) / c)"},
		{"a + b / c", "(a + (b / c))"},
		{"a + b * c + d / e - f", "(((a + (b * c)) + (d / e)) - f)"},
		{"3 + 4; -5 * 5", "(3 + 4)((-5) * 5)"},
		{"5 > 4 == 3 < 4", "((5 > 4) == (3 < 4))"},
		{"5 < 4 != 3 > 4", "((5 < 4) != (3 > 4))"},
		{"3 + 4 * 5 == 3 * 1 + 4 * 5", "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))"},
		{"3 + 4 * 5 == 3 * 1 + 4 * 5", "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))"},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		check_parse_errors(t, p)

		actual := to_string(prog, alloc)
		testing.expectf(t, actual == tt.expected, "expected=`%s`, got=`%s`", tt.expected, actual)
	}
}

_test_integer_literal :: proc(
	t: ^testing.T,
	expr: ^Expression,
	val: i64,
	alloc := context.allocator,
) -> bool {

	il, il_ok := expr.variant.(Integer_Literal)
	testing.expectf(t, il_ok, "expr not Integer_Literal. got=`%T`", expr.variant)
	if !il_ok {
		return false
	}

	testing.expectf(t, il.value == val, "il.value expected=`%d`. got=`%d`", val, il.value)
	if il.value != val {
		return false
	}
	testing.expectf(
		t,
		il.token.literal == fmt.tprintf("%d", val),
		"il.token.literal not %d. got=`%s`",
		val,
		il.token.literal,
	)
	if il.token.literal != fmt.tprintf("%d", val) {
		return false
	}

	return true
}

