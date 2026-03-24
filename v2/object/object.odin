package object

import "../ast"
import "core:fmt"
import "core:strings"

TRUE :: Boolean{true}
FALSE :: Boolean{false}
NULL :: Null{}

Integer :: struct {
	value: i64,
}

Boolean :: struct {
	value: bool,
}

Null :: struct {}

Return_Value :: struct {
	value: ^Object,
}

Error :: struct {
	message: string,
}

Function :: struct {
	parameters: []ast.Ident,
	body:       ^ast.Block_Stmt,
	env:        ^Env,
}

String :: struct {
	value: string,
}

Builtin_Function :: proc(args: ..Object) -> Object
Builtin :: struct {
	fn: Builtin_Function,
}

Object :: union {
	Integer,
	Boolean,
	Null,
	Return_Value,
	Error,
	Function,
	String,
	Builtin,
}

inspect :: proc(object: ^Object) -> string {
	switch v in object {
	case Integer:
		return fmt.tprintf("%d", v.value)
	case Boolean:
		return fmt.tprintf("%t", v.value)
	case Null:
		return "null"
	case Return_Value:
		return inspect(v.value)
	case Error:
		return fmt.tprintf("ERROR: %s", v.message)
	case Function:
		sb := strings.builder_make()
		defer strings.builder_destroy(&sb)
		strings.write_string(&sb, "fn(")
		if len(v.parameters) > 0 {
			strings.write_string(&sb, ast.to_string(&v.parameters[0]))
			for i := 1; i < len(v.parameters); i += 1 {
				strings.write_string(&sb, ", ")
				strings.write_string(&sb, ast.to_string(&v.parameters[i]))
			}
		}
		strings.write_string(&sb, ast.to_string(v.body))
		strings.write_string(&sb, "\n")
		return strings.clone(strings.to_string(sb))
	case String:
		return v.value
	case Builtin:
		return "builtin function"
	case:
		return fmt.tprintf("Unknown object: %T", object^)
	}
}

get_typeid :: proc(obj: ^Object) -> typeid {
	switch v in obj {
	case Integer:
		return Integer
	case Boolean:
		return Boolean
	case Null:
		return Null
	case Return_Value:
		return Return_Value
	case Error:
		return Error
	case Function:
		return Function
	case String:
		return String
	case Builtin:
		return Builtin
	}

	return {}
}

to_string :: proc(obj: ^Object) -> string {
	s := fmt.tprintf("%s", get_typeid(obj))
	return strings.to_upper(s)
}

