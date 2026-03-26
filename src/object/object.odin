package object

import "../ast"
import "core:fmt"
import "core:hash/xxhash"
import "core:strconv"
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
	parameters: []^ast.Ident,
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
inspect :: proc(object: ^Object, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	defer strings.builder_destroy(&sb)
	write_object(&sb, object)
	s := strings.to_string(sb)
	return strings.clone(s, allocator)
}

write_string :: strings.write_string
write_object :: proc(sb: ^strings.Builder, object: ^Object) {
	switch v in object {
	case Integer:
		strings.write_i64(sb, v.value)
	case Boolean:
		write_string(sb, v.value ? "true" : "false")
	case Null:
		write_string(sb, "null")
	case Return_Value:
		write_object(sb, v.value)
	case Error:
		write_string(sb, "ERROR: ")
		write_string(sb, v.message)
	case Function:
		write_string(sb, "fn(")
		delim := false
		for param in v.parameters {
			if delim {write_string(sb, ",")}
			delim = true
			write_string(sb, ast.to_string(param))
		}
		write_string(sb, ast.to_string(v.body))
		write_string(sb, "\n")
	case String:
		write_string(sb, v.value)
	case Builtin:
		write_string(sb, "builtin function")
	case Array:
		write_string(sb, "[")
		delim := false
		for &elem in v.elements {
			if delim {write_string(sb, ", ")}
			delim = true
			write_string(sb, inspect(&elem))
		}
		write_string(sb, "]")

	case Hash:
		write_string(sb, "{")
		delim := false
		for k, &v in v.pairs {
			if delim {
				write_string(sb, ", ")
			}
			write_string(sb, inspect(&v.val))
			delim = true
		}
		write_string(sb, "}")

	case:
		write_string(sb, "Unknown object: ")
		write_string(sb, to_string(object))
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
