package object

import "../ast"
import "core:fmt"
import "core:hash/xxhash"
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

Array :: struct {
	elements: []Object,
}

Hash_Key :: struct {
	type:  typeid,
	value: u64,
}
hash_key :: proc {
	hash_object,
	hash_boolean,
	hash_integer,
	hash_string,
}
hash_object :: proc(o: ^Object) -> Hash_Key {
	#partial switch &v in o {
	case Boolean:
		return hash_boolean(&v)
	case Integer:
		return hash_integer(&v)
	case String:
		return hash_string(&v)
	case:
		return {}
	}
}
hash_boolean :: proc(b: ^Boolean) -> Hash_Key {
	return Hash_Key{Boolean, b.value ? 1 : 0}
}
hash_integer :: proc(i: ^Integer) -> Hash_Key {
	return Hash_Key{Integer, u64(i.value)}
}
hash_string :: proc(s: ^String) -> Hash_Key {
	buf := transmute([]u8)s.value
	hash: u64 = xxhash.XXH3_64(buf)
	return Hash_Key{String, hash}
}
hashable :: proc(o: ^Object) -> bool {
	#partial switch v in o {
	case Boolean, Integer, String:
		return true
	case:
		return false
	}
}
Hash_Pair :: struct {
	key: Hash_Key,
	val: Object,
}
Hash :: struct {
	pairs: map[Hash_Key]Hash_Pair,
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
	Array,
	Hash,
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
	case Array:
		sb := strings.builder_make()
		defer strings.builder_destroy(&sb)
		strings.write_string(&sb, "[")
		if len(v.elements) > 0 {
			strings.write_string(&sb, inspect(&v.elements[0]))
			for i := 1; i < len(v.elements); i += 1 {
				strings.write_string(&sb, ", ")
				strings.write_string(&sb, inspect(&v.elements[i]))
			}
		}
		strings.write_string(&sb, "]")
		return strings.clone(strings.to_string(sb))
	case Hash:
		sb := strings.builder_make()
		defer strings.builder_destroy(&sb)
		strings.write_string(&sb, "{")
		delim := false
		for k, &v in v.pairs {
			if delim {
				strings.write_string(&sb, ", ")
			}
			strings.write_string(&sb, inspect(&v.val))
			delim = true
		}
		strings.write_string(&sb, "}")
		return strings.clone(strings.to_string(sb))

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
	case Array:
		return Array
	case Hash:
		return Hash
	}

	return {}
}

to_string :: proc(obj: ^Object) -> string {
	s := fmt.tprintf("%s", get_typeid(obj))
	return strings.to_upper(s)
}

