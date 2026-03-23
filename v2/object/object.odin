package object

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

Object :: union {
	Integer,
	Boolean,
	Null,
	Return_Value,
	Error,
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
	case:
		return fmt.tprintf("Unknown object: %T", object)
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
	}

	return {}
}

type_to_string :: proc(obj: ^Object) -> string {
	s := fmt.tprintf("%s", get_typeid(obj))
	return strings.to_upper(s)
}
