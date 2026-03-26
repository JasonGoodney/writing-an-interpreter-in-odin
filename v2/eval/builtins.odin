#+ feature dynamic-literals

package eval

import "../object"
import "core:fmt"

builtins := map[string]object.Builtin {
	"len" = object.Builtin{fn = proc(args: ..object.Object) -> object.Object {
			if len(args) != 1 {
				return new_error("wrong number of arguments. got=%d, want=1")
			}
			n := 0
			#partial switch &v in args[0] {
			case object.String:
				n = len(v.value)
			case object.Array:
				n = len(v.elements)
			case:
				return new_error("arugment to `len` not supported, got %s", object.to_string(&v))
			}
			return object.Integer{i64(n)}
		}},
	"first" = object.Builtin{fn = proc(args: ..object.Object) -> object.Object {
			if len(args) != 1 {
				return new_error("wrong number of arguments. got=%d, want=1")
			}
			#partial switch &v in args[0] {
			case object.Array:
				if len(v.elements) == 0 {return object.NULL}
				return v.elements[0]
			case:
				return new_error("arugment to `first` not supported, got %s", object.to_string(&v))
			}
		}},
	"last" = object.Builtin{fn = proc(args: ..object.Object) -> object.Object {
			if len(args) != 1 {
				return new_error("wrong number of arguments. got=%d, want=1")
			}
			#partial switch &v in args[0] {
			case object.Array:
				if len(v.elements) == 0 {return object.NULL}
				return v.elements[len(v.elements) - 1]
			case:
				return new_error("arugment to `last` not supported, got %s", object.to_string(&v))
			}
		}},
	"rest" = object.Builtin{fn = proc(args: ..object.Object) -> object.Object {
			if len(args) != 1 {
				return new_error("wrong number of arguments. got=%d, want=1")
			}
			#partial switch &v in args[0] {
			case object.Array:
				length := len(v.elements)
				if length == 0 {return object.NULL}
				rest := make([dynamic]object.Object, length - 1, length - 1)
				copy(rest[:], v.elements[1:])
				return object.Array{rest[:]}
			case:
				return new_error("arugment to `rest` not supported, got %s", object.to_string(&v))
			}
		}},
	"push" = object.Builtin{fn = proc(args: ..object.Object) -> object.Object {
			if len(args) != 2 {
				return new_error("wrong number of arguments. got=%d, want=2")
			}
			#partial switch &v in args[0] {
			case object.Array:
				length := len(v.elements)
				rest := make([dynamic]object.Object, length + 1, length + 1)
				copy(rest[:], v.elements[:])
				rest[length] = args[1]
				return object.Array{rest[:]}
			case:
				return new_error("arugment to `push` not supported, got %s", object.to_string(&v))
			}
		}},
	"puts" = object.Builtin{fn = proc(args: ..object.Object) -> object.Object {
			for &arg in args {
				str := object.inspect(&arg)
				fmt.println(str)
			}
			return object.NULL
		}},
}
