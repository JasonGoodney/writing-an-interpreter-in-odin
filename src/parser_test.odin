package main

import "core:fmt"
import "core:testing"

Expected_Value :: union {
	i64,
	string,
	bool,
}

@(test)
test_let_statements :: proc(t: ^testing.T) {
	tests := []struct {
		input:          string,
		expected_ident: string,
		expected_value: Expected_Value,
	}{{"let x = 5;", "x", 5}, {"let foobar = y;", "foobar", "y"}}

	for tt, i in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		program := parse_program(p)
		_check_parse_errors(t, p)

		if len(program.statements) != 1 {
			fmt.panicf(
				"program.statements does not contain 1 statements. got=%s",
				len(program.statements),
			)
		}
		stmt := program.statements[0]
		if !_test_let_statement(t, stmt, tt.expected_ident) {
			testing.fail_now(t)
		}

		value := stmt.variant.(Let_Statement).value
		if !_test_literal_expression(t, value, tt.expected_value) {
			return
		}
	}
}

@(test)
test_return_statements :: proc(t: ^testing.T) {
	tests := []struct {
		input:         string,
		expectedValue: Expected_Value,
	} {
		{"return 5;", 5},
		// {"return true;", true},
		{"return foobar;", "foobar"},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		program := parse_program(p)
		_check_parse_errors(t, p)

		if len(program.statements) != 1 {
			fmt.panicf(
				"program.statements does not contain 1 statements. got=%s",
				len(program.statements),
			)
		}

		stmt := program.statements[0]
		returnStmt, ok := stmt.variant.(Return_Statement)
		if !ok {
			fmt.panicf("stmt not *ast.returnStatement. got=%T", stmt)
		}
		if returnStmt.token.literal != "return" {
			fmt.panicf("returnStmt.TokenLiteral not 'return', got %q", returnStmt.token.literal)
		}
		if _test_literal_expression(t, returnStmt.return_value, tt.expectedValue) {
			return
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
	_check_parse_errors(t, p)

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
	_check_parse_errors(t, p)

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
test_boolean :: proc(t: ^testing.T) {
	alloc := context.temp_allocator

	input := "true;"
	l := lexer_init(input, alloc)
	p := parser_init(l, alloc)
	prog := parse_program(p)
	_check_parse_errors(t, p)

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
	expr, expr_ok := stmt.expr.variant.(Boolean)
	testing.expectf(t, expr_ok, "expr not Boolean. got=`%T`", stmt.expr.variant)
	testing.expectf(t, expr.value == true, "expr.value expected=`%d`. got=`%d`", true, expr.value)
	testing.expectf(
		t,
		expr.token.literal == "true",
		"expr.token.literal not %s. got=`%s`",
		"true",
		expr.token.literal,
	)
}

@(test)
test_prefix_expressions :: proc(t: ^testing.T) {
	tests := []struct {
		input: string,
		op:    string,
		value: Expected_Value,
	} {
		{"!5;", "!", 5},
		{"-15;", "-", 15},
		{"!foobar;", "!", "foobar"},
		{"-foobar;", "-", "foobar"},
		{"!true;", "!", true},
		{"!false;", "!", false},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		_check_parse_errors(t, p)

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

		if !_test_literal_expression(t, expr.right^, tt.value) {
			testing.fail_now(t)
		}
	}
}

@(test)
test_infix_expressions :: proc(t: ^testing.T) {
	tests := []struct {
		input:     string,
		left_val:  Expected_Value,
		op:        string,
		right_val: Expected_Value,
	} {
		{"5 + 5;", 5, "+", 5},
		{"5 - 5;", 5, "-", 5},
		{"5 * 5;", 5, "*", 5},
		{"5 / 5;", 5, "/", 5},
		{"5 > 5;", 5, ">", 5},
		{"5 < 5;", 5, "<", 5},
		{"5 == 5;", 5, "==", 5},
		{"5 != 5;", 5, "!=", 5},
		{"foobar + barfoo;", "foobar", "+", "barfoo"},
		{"foobar - barfoo;", "foobar", "-", "barfoo"},
		{"foobar * barfoo;", "foobar", "*", "barfoo"},
		{"foobar / barfoo;", "foobar", "/", "barfoo"},
		{"foobar > barfoo;", "foobar", ">", "barfoo"},
		{"foobar < barfoo;", "foobar", "<", "barfoo"},
		{"foobar == barfoo;", "foobar", "==", "barfoo"},
		{"foobar != barfoo;", "foobar", "!=", "barfoo"},
		{"true == true", true, "==", true},
		{"true != false", true, "!=", false},
		{"false == false", false, "==", false},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		_check_parse_errors(t, p)

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

		if !_test_infix_expression(t, stmt.expr, tt.left_val, tt.op, tt.right_val) {
			return
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
		{"true", "true"},
		{"false", "false"},
		{"3 > 5 == false", "((3 > 5) == false)"},
		{"3 < 5 == true", "((3 < 5) == true)"},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		_check_parse_errors(t, p)

		actual := to_string(prog, alloc)
		testing.expectf(t, actual == tt.expected, "expected=`%s`, got=`%s`", tt.expected, actual)
	}
}

//
// ========= Helpers ==========================
//

_test_let_statement :: proc(t: ^testing.T, s: Statement, name: string) -> bool {
	letstmt, ok := s.variant.(Let_Statement)
	testing.expectf(t, ok, "s not Let_Statement. got=%T", s.variant)
	if !ok {return false}

	testing.expectf(
		t,
		letstmt.name.value == name,
		"letstmt.name.value expected=%s, got=%s",
		name,
		letstmt.name.value,
	)
	if letstmt.name.value != name {return false}


	testing.expectf(
		t,
		letstmt.name.token.literal == name,
		"letstmt.name.token.literal expected=%s, got=%s",
		name,
		letstmt.name.token.literal,
	)
	if letstmt.name.token.literal != name {return false}

	return true
}

_test_literal_expression :: proc(t: ^testing.T, expr: Expression, expected: $T) -> bool {
	switch ev in expected {
	case i64:
		return _test_integer_literal(t, expr, ev)
	case string:
		return _test_identifier(t, expr, ev)
	case bool:
		return _test_boolean(t, expr, ev)
	}

	fmt.printfln("type of expr not handled. got=`%T`", expected)
	return false
}

_test_boolean :: proc(t: ^testing.T, expr: Expression, value: bool) -> bool {
	b, ok := expr.variant.(Boolean)
	testing.expectf(t, ok, "expr not Boolean. got=%T", expr.variant)
	if !ok {return false}

	testing.expectf(t, b.value == value, "b.value not %t. got=%t", value, b.value)
	if b.value != value {return false}

	testing.expectf(
		t,
		b.token.literal == fmt.tprintf("%t", value),
		"b.token.literal not %t. got=%s",
		value,
		b.token.literal,
	)
	if b.token.literal != fmt.tprintf("%t", value) {return false}

	return true
}

_test_integer_literal :: proc(
	t: ^testing.T,
	expr: Expression,
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

_test_identifier :: proc(t: ^testing.T, expr: Expression, value: string) -> bool {
	ident, ok := expr.variant.(Identifier)
	testing.expectf(t, ok, "expr not Identifier, got=`%T`", expr)
	if !ok {return false}

	testing.expectf(t, ident.value == value, "ident.value not %s. got=`%s`", value, ident.value)
	if ident.value != value {return false}

	testing.expectf(
		t,
		ident.token.literal == value,
		"ident.token.literal not %s. got=`%s`",
		value,
		ident.token.literal,
	)
	if ident.token.literal != value {return false}

	return true
}

_test_infix_expression :: proc(
	t: ^testing.T,
	expr: Expression,
	left: $T,
	op: string,
	right: $U,
) -> bool {
	opexpr, ok := expr.variant.(Infix_Expression)
	testing.expectf(t, ok, "expr is not Infix_Expression. got=`%T`", expr)
	if !ok {return false}

	if !_test_literal_expression(t, opexpr.left^, left) {
		return false
	}

	testing.expectf(t, opexpr.op == op, "expr operator is not `%s`. got=`%s`", op, opexpr.op)
	if opexpr.op != op {return false}

	if !_test_literal_expression(t, opexpr.right^, right) {
		return false
	}

	return true
}

_check_parse_errors :: proc(t: ^testing.T, p: ^Parser) {
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

