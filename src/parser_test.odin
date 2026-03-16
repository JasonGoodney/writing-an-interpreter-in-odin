package main

import "core:fmt"
import "core:log"
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
		{"1 + (2 + 3) + 4", "((1 + (2 + 3)) + 4)"},
		{"(5 + 5) * 2", "((5 + 5) * 2)"},
		{"2 / (5 + 5)", "(2 / (5 + 5))"},
		{"(5 + 5) * 2 * (5 + 5)", "(((5 + 5) * 2) * (5 + 5))"},
		{"-(5 + 5)", "(-(5 + 5))"},
		{"!(true == true)", "(!(true == true))"},
		{"a + add(b * c) + d", "((a + add((b * c))) + d)"},
		{
			"add(a, b, 1, 2 * 3, 4 + 5, add(6, 7 * 8))",
			"add(a, b, 1, (2 * 3), (4 + 5), add(6, (7 * 8)))",
		},
		{"add(a + b + c * d / f + g)", "add((((a + b) + ((c * d) / f)) + g))"},
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

@(test)
test_if_expression :: proc(t: ^testing.T) {
	input := `if (x < y) { x }`

	alloc := context.temp_allocator
	free_all(alloc)
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

	ifexpr, if_ok := stmt.expr.variant.(If_Expression)
	testing.expectf(t, ok, "stmt.expr is not If_Expression. got=%T", stmt.expr.variant)

	if !_test_infix_expression(t, ifexpr.condition^, "x", "<", "y") {
		return
	}

	testing.expectf(
		t,
		len(ifexpr.consequence.statements) == 1,
		"consequence is not 1 statements. got=%d",
		len(ifexpr.consequence.statements),
	)

	conseq, conseq_ok := ifexpr.consequence.statements[0].variant.(Expression_Statement)
	testing.expectf(
		t,
		ok,
		"statements[0] not Expression_Statement. got=%T",
		ifexpr.consequence.statements[0].variant,
	)

	if !_test_identifier(t, conseq.expr, "x") {
		return
	}

	testing.expectf(
		t,
		ifexpr.alternative == nil,
		"alternative not nil. got=%v",
		ifexpr.alternative,
	)
}

@(test)
test_if_else_expression :: proc(t: ^testing.T) {
	input := `if (x < y) { x } else { y }`

	alloc := context.temp_allocator
	free_all(alloc)
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

	ifexpr, if_ok := stmt.expr.variant.(If_Expression)
	testing.expectf(t, ok, "stmt.expr is not If_Expression. got=%T", stmt.expr.variant)

	if !_test_infix_expression(t, ifexpr.condition^, "x", "<", "y") {
		return
	}

	testing.expectf(
		t,
		len(ifexpr.consequence.statements) == 1,
		"consequence is not 1 statements. got=%d",
		len(ifexpr.consequence.statements),
	)

	conseq, conseq_ok := ifexpr.consequence.statements[0].variant.(Expression_Statement)
	testing.expectf(
		t,
		ok,
		"consequence.statements[0] not Expression_Statement. got=%T",
		ifexpr.consequence.statements[0].variant,
	)

	if !_test_identifier(t, conseq.expr, "x") {
		return
	}

	alt, alt_ok := ifexpr.alternative.statements[0].variant.(Expression_Statement)
	testing.expectf(
		t,
		ok,
		"alt.statements[0] not Expression_Statement. got=%T",
		ifexpr.alternative.statements[0].variant,
	)

	if !_test_identifier(t, alt.expr, "y") {
		return
	}
}

@(test)
test_function_literal :: proc(t: ^testing.T) {
	input := `fn(x, y) { x + y; }`

	alloc := context.temp_allocator
	free_all(alloc)
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

	fnexpr, if_ok := stmt.expr.variant.(Function_Literal)
	testing.expectf(t, ok, "stmt.expr is not Function_Literal. got=%T", stmt.expr.variant)

	testing.expectf(
		t,
		len(fnexpr.parameters) == 2,
		"fn literal len parameters. expected=2, got=%d",
		len(fnexpr.parameters),
	)

	_test_literal_expression(t, Expression{fnexpr.parameters[0]}, "x")
	_test_literal_expression(t, Expression{fnexpr.parameters[1]}, "y")

	testing.expectf(
		t,
		len(fnexpr.body.statements) == 1,
		"fn.body.statements expected=1, got=%d",
		len(fnexpr.body.statements),
	)

	bodystmt, body_ok := fnexpr.body.statements[0].variant.(Expression_Statement)
	testing.expectf(
		t,
		body_ok,
		"fn body stmt is not Expression_Satement. got=%T",
		fnexpr.body.statements[0].variant.(Expression_Statement),
	)

	_test_infix_expression(t, bodystmt.expr, "x", "+", "y")
}

@(test)
test_function_parameter_parsing :: proc(t: ^testing.T) {
	tests := []struct {
		input:           string,
		expected_params: []string,
	} {
		{"fn() {};", []string{}},
		{"fn(x) {};", []string{"x"}},
		{"fn(x,y,z) {};", []string{"x", "y", "z"}},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		_check_parse_errors(t, p)

		stmt := prog.statements[0].variant.(Expression_Statement)
		fn := stmt.expr.variant.(Function_Literal)

		testing.expectf(
			t,
			len(fn.parameters) == len(tt.expected_params),
			"param count wrong. expected=%d, got=%d",
			len(tt.expected_params),
			len(fn.parameters),
		)

		for ident, i in tt.expected_params {
			_test_literal_expression(t, Expression{fn.parameters[i]}, ident)
		}
	}

}

@(test)
test_call_expression_parsing :: proc(t: ^testing.T) {
	input := `add(1, 2 * 3, 4 + 5);`

	alloc := context.temp_allocator
	defer free_all(alloc)
	l := lexer_init(input, alloc)
	p := parser_init(l, alloc)
	prog := parse_program(p)
	_check_parse_errors(t, p)

	testing.expectf(
		t,
		len(prog.statements) == 1,
		"prog.statements does not contain %s statements. got=%d",
		1,
		len(prog.statements),
	)

	stmt, stmt_ok := prog.statements[0].variant.(Expression_Statement)
	testing.expectf(t, stmt_ok, "stmt is not Expression_Statement. got=%T", prog.statements[0])

	expr, expr_ok := stmt.expr.variant.(Call_Expression)
	testing.expectf(t, expr_ok, "stmt.expr not Call_Expression. got=%T", stmt.expr)


	if !_test_identifier(t, expr.function^, "add") {
		return
	}

	testing.expectf(
		t,
		len(expr.arguments) == 3,
		"wrong argument count. got=%d",
		len(expr.arguments),
	)

	_test_literal_expression(t, expr.arguments[0]^, i64(1))
	_test_infix_expression(t, expr.arguments[1]^, i64(2), "*", i64(3))
	_test_infix_expression(t, expr.arguments[2]^, i64(4), "+", i64(5))
}

@(test)
test_call_expression_parameter_parsing :: proc(t: ^testing.T) {
	tests := []struct {
		input:         string,
		expectedIdent: string,
		expectedArgs:  []string,
	} {
		{"add();", "add", []string{}},
		{"add(1);", "add", []string{"1"}},
		{"add(1, 2 * 3, 4 + 5);", "add", []string{"1", "(2 * 3)", "(4 + 5)"}},
	}

	for tt in tests {
		alloc := context.temp_allocator
		defer free_all(alloc)
		l := lexer_init(tt.input, alloc)
		p := parser_init(l, alloc)
		prog := parse_program(p)
		_check_parse_errors(t, p)


		stmt, stmt_ok := prog.statements[0].variant.(Expression_Statement)
		testing.expectf(t, stmt_ok, "stmt is not Expression_Statement. got=%T", prog.statements[0])

		expr, expr_ok := stmt.expr.variant.(Call_Expression)
		testing.expectf(t, expr_ok, "stmt.expr not Call_Expression. got=%T", stmt.expr)

		if !_test_identifier(t, expr.function^, "add") {
			return
		}

		testing.expectf(
			t,
			len(expr.arguments) == 3,
			"wrong argument count. got=%d",
			len(expr.arguments),
		)


		for arg, i in tt.expectedArgs {
			s := to_string(expr.arguments[i])
			testing.expectf(t, s == arg, "argument %d wrong. expected=%s, got=%s", arg, s)
		}
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

_test_literal_expression :: proc(
	t: ^testing.T,
	expr: Expression,
	expected: Expected_Value,
) -> bool {
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

	log.infof("parser has %d errors", len(errors))
	for msg in errors {
		log.infof("parse error: %s", msg)
	}

	testing.fail_now(t)
}
