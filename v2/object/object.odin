package object

import "core:fmt"

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

Object :: union {
	Integer,
	Boolean,
	Null,
}

inspect :: proc(object: ^Object) -> string {
	switch v in object {
	case Integer:
		return fmt.tprintf("%d", v.value)
	case Boolean:
		return fmt.tprintf("%t", v.value)
	case Null:
		return "null"
	case:
		return fmt.tprintf("Unknown object: %T", object)
	}
}
