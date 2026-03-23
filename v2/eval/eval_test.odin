package eval

import "../ast"
import "../lexer"
import "../object"
import "../parser"
import "core:testing"

expect :: proc(t: ^testing.T, ok: bool, format: string, args: ..any) -> bool {
	result := testing.expectf(t, ok, format, ..args)
	assert(result)
	return result
}

@(test)
test_eval_integer_expr :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: i64,
	} {
		{"5", 5},
		{"10", 10},
		{"-5", -5},
		{"-10", -10},
		{"5 + 5 + 5 + 5 - 10", 10},
		{"2 * 2 * 2 * 2 * 2", 32},
		{"-50 + 100 + -50", 0},
		{"5 * 2 + 10", 20},
		{"5 + 2 * 10", 25},
		{"20 + 2 * -10", 0},
		{"50 / 2 * 2 + 10", 60},
		{"2 * (5 + 10)", 30},
		{"3 * 3 * 3 + 10", 37},
		{"3 * (3 * 3) + 10", 37},
		{"(5 + 10 * 2 + 15 / 3) * 2 + -10", 50},
	}

	for tt in tests {
		evaluated := _test_eval(tt.input)
		_test_integer_object(t, evaluated, tt.expected)
	}
}

@(test)
test_eval_boolean_expression :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: bool,
	} {
		{"true", true},
		{"false", false},
		{"1 < 2", true},
		{"1 > 2", false},
		{"1 < 1", false},
		{"1 > 1", false},
		{"1 == 1", true},
		{"1 != 1", false},
		{"1 == 2", false},
		{"1 != 2", true},
		{"true == true", true},
		{"false == false", true},
		{"true == false", false},
		{"true != false", true},
		{"false != true", true},
		{"(1 < 2) == true", true},
		{"(1 < 2) == false", false},
		{"(1 > 2) == true", false},
		{"(1 > 2) == false", true},
	}

	for tt in tests {
		evaluated := _test_eval(tt.input)
		_test_boolean_object(t, evaluated, tt.expected)
	}
}

@(test)
test_bang_operator :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: bool,
	} {
		{"!true", false},
		{"!false", true},
		{"!5", false},
		{"!!true", true},
		{"!!false", false},
		{"!!5", true},
	}

	for tt in tests {
		evaluated := _test_eval(tt.input)
		_test_boolean_object(t, evaluated, tt.expected)
	}
}

Expected_Value :: union {
	i64,
	bool,
	string,
}

@(test)
test_if_else_expressions :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: Expected_Value,
	} {
		{"if (true) { 10 }", 10},
		{"if (false) { 10 }", nil},
		{"if (1) { 10 }", 10},
		{"if (1 < 2) { 10 }", 10},
		{"if (1 > 2) { 10 }", nil},
		{"if (1 > 2) { 10 } else { 20 }", 20},
		{"if (1 < 2) { 10 } else { 20 }", 10},
	}

	for tt in tests {
		evaluated := _test_eval(tt.input)
		#partial switch v in tt.expected {
		case i64:
			_test_integer_object(t, evaluated, v)
		case:
			_test_null_object(t, evaluated)
		}
	}
}

@(test)
test_return_statements :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: Expected_Value,
	} {
		{"return 10;", 10},
		{"return 10; 9;", 10},
		{"return 2 * 5; 9;", 10},
		{"9; return 2 * 5; 9;", 10},
		{`if (10 > 1) {
			if (10 > 1) {
				return 10;
			}
			return 1;
		 }`, 10},
	}

	for tt in tests {
		evaluated := _test_eval(tt.input)
		#partial switch v in tt.expected {
		case i64:
			_test_integer_object(t, evaluated, v)
		case:
			_test_null_object(t, evaluated)
		}
	}
}

@(test)
test_let_statements :: proc(t: ^testing.T) {
	tests := []struct {
		input:    string,
		expected: Expected_Value,
	} {
		{"let a = 5; a;", 5},
		{"let a = 5 * 5; a;", 25},
		{"let a = 5; let b = a; b;", 5},
		{"let a = 5; let b = a; let c = a + b + 5; c;", 15},
	}

	for tt in tests {
		evaluated := _test_eval(tt.input)
		#partial switch v in tt.expected {
		case i64:
			_test_integer_object(t, evaluated, v)
		}
	}
}

@(test)
test_error_handling :: proc(t: ^testing.T) {
	tests := []struct {
		input:            string,
		expected_message: Expected_Value,
	} {
		{"5 + true;", "type mismatch: INTEGER + BOOLEAN"},
		{"5 + true; 5;", "type mismatch: INTEGER + BOOLEAN"},
		{"-true", "unknown operator: -BOOLEAN"},
		{"true + false;", "unknown operator: BOOLEAN + BOOLEAN"},
		{"5; true + false; 5", "unknown operator: BOOLEAN + BOOLEAN"},
		{"if (10 > 1) { true + false; }", "unknown operator: BOOLEAN + BOOLEAN"},
		{
			`if (10 > 1) {
			if (10 > 1) {
			  return true + false;
			}
			return 1;
		  }`,
			"unknown operator: BOOLEAN + BOOLEAN",
		},
		{"foobar", "identifier not found: foobar"},
	}

	for tt in tests {
		evaluated := _test_eval(tt.input)
		errobj, ok := evaluated.(object.Error)
		expect(t, ok, "no error object returned. got=%T (%v)", evaluated, evaluated)
		expect(
			t,
			errobj.message == tt.expected_message,
			"wrong error message. expected=%s, got=%s",
			tt.expected_message,
			errobj.message,
		)
	}
}

// ============== Helpers ===============================

_test_eval :: proc(input: string) -> object.Object {
	l := lexer.init(input, context.temp_allocator)
	p := parser.init(l, context.temp_allocator)
	program := parser.parse_program(p)
	env := object.env_init()
	obj := eval(ast.Node{program}, &env)
	return obj
}

_test_integer_object :: proc(t: ^testing.T, obj: object.Object, expected: i64) -> bool {
	result, ok := obj.(object.Integer)
	expect(t, ok, "object is not Integer. got=%T (%v)", obj, obj) or_return
	expect(
		t,
		result.value == expected,
		"object has wrong value, got=%d, expected=%d",
		result.value,
		expected,
	) or_return

	return true
}

_test_boolean_object :: proc(t: ^testing.T, obj: object.Object, expected: bool) -> bool {
	result, ok := obj.(object.Boolean)
	expect(t, ok, "object is not Boolean. got=%T (%v)", obj, obj) or_return
	expect(
		t,
		result.value == expected,
		"object has wrong value, got=%d, expected=%d",
		result.value,
		expected,
	) or_return

	return true
}

_test_null_object :: proc(t: ^testing.T, obj: object.Object) -> bool {
	#partial switch v in obj {
	case object.Null:
		return true
	case:
		return expect(t, obj != object.NULL, "object is not NULL. got=%T (%v)", obj, obj)
	}
}
