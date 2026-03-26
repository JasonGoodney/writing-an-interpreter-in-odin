#+ feature dynamic-literals

package eval

import "../ast"
import "../object"
import "core:fmt"
import "core:strings"

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

eval :: proc(node: ast.Node, env: ^object.Env) -> object.Object {
	switch n in node.variant {
	case ast.Program:
		result: object.Object
		for stmt in n.stmts {
			result = eval(ast.Node{stmt}, env)
			#partial switch v in result {
			case object.Return_Value:
				return v.value^
			case object.Error:
				return v
			}
		}
		return result
	case ast.Stmt:
		switch s in n.variant {
		case ast.Expr_Stmt:
			return eval(ast.Node{s.expr}, env)
		case ast.Block_Stmt:
			result: object.Object
			for stmt in s.stmts {
				result = eval(ast.Node{stmt}, env)
				#partial switch v in result {
				case object.Return_Value, object.Error:
					return result
				}
			}
			return result
		case ast.Return_Stmt:
			val := eval(ast.Node{s.return_value}, env)
			if is_error(&val) {return val}
			return object.Return_Value{&val}
		case ast.Let_Stmt:
			val := eval(ast.Node{s.value}, env)
			if is_error(&val) {return val}
			object.env_set(env, s.name.value, val)
		}
	case ast.Expr:
		switch e in n.variant {
		case ast.Integer_Literal:
			return object.Integer{e.value}
		case ast.String_Literal:
			return object.String{e.value}
		case ast.Boolean:
			return e.value ? object.TRUE : object.FALSE
		case ast.Ident:
			if val, ok := object.env_get(env, e.value); ok {return val}
			if builtin, ok := builtins[e.value]; ok {return builtin}
			return new_error("identifier not found: %s", e.value)
		case ast.Function_Literal:
			params := e.parameters
			body := e.body
			return object.Function{parameters = params[:], body = body, env = env}
		case ast.Call_Expr:
			obj := eval(ast.Node{e.function^}, env)
			if is_error(&obj) {return obj}
			args := eval_expressions(e.arguments[:], env)
			if len(args) == 1 && is_error(&args[0]) {
				return args[0]
			}
			#partial switch v in obj {
			case object.Function:
				fn := v
				extended_env := object.env_extend(fn.env, context.temp_allocator)
				for param, i in fn.parameters {
					object.env_set(extended_env, param.value, args[i])
				}
				evaluated := eval(ast.Node{ast.Stmt{fn.body^}}, extended_env)
				if rv, ok := evaluated.(object.Return_Value); ok {
					return rv.value^
				}
				return evaluated
			case object.Builtin:
				return v.fn(..args)
			case:
				return new_error("not a function: %s", object.to_string(&obj))
			}
		case ast.Prefix_Expr:
			right := eval(ast.Node{e.right^}, env)
			if is_error(&right) {return right}
			switch e.op {
			case "!":
				b := is_truthy(&right)
				return b ? object.FALSE : object.TRUE
			case "-":
				if integer, ok := right.(object.Integer); ok {
					return object.Integer{value = -integer.value}
				} else {
					return new_error("unknown operator: %s%s", e.op, object.to_string(&right))
				}
			case:
				return new_error("unknown operator: %s%s", e.op, object.to_string(&right))
			}
		case ast.Infix_Expr:
			left := eval(ast.Node{e.left^}, env)
			if is_error(&left) {return left}
			right := eval(ast.Node{e.right^}, env)
			if is_error(&right) {return right}
			left_typeid := object.get_typeid(&left)
			right_typeid := object.get_typeid(&right)
			switch {
			case left_typeid != right_typeid:
				return new_error(
					"type mismatch: %s %s %s",
					object.to_string(&left),
					e.op,
					object.to_string(&right),
				)
			case left_typeid == object.Integer && right_typeid == object.Integer:
				l := left.(object.Integer).value
				r := right.(object.Integer).value
				switch e.op {
				case "+":
					return object.Integer{l + r}
				case "-":
					return object.Integer{l - r}
				case "*":
					return object.Integer{l * r}
				case "/":
					return object.Integer{l / r}
				case "<":
					return l < r ? object.TRUE : object.FALSE
				case ">":
					return l > r ? object.TRUE : object.FALSE
				case "==":
					return l == r ? object.TRUE : object.FALSE
				case "!=":
					return l != r ? object.TRUE : object.FALSE
				case:
					return new_error(
						"unknown operator: %s %s %s",
						object.to_string(&left),
						e.op,
						object.to_string(&right),
					)
				}
			case left_typeid == object.Boolean && right_typeid == object.Boolean:
				l := left.(object.Boolean).value
				r := right.(object.Boolean).value
				switch e.op {
				case "==":
					return l == r ? object.TRUE : object.FALSE
				case "!=":
					return l != r ? object.TRUE : object.FALSE
				case:
					return new_error(
						"unknown operator: %s %s %s",
						object.to_string(&left),
						e.op,
						object.to_string(&right),
					)
				}
			case left_typeid == object.String && right_typeid == object.String:
				l := left.(object.String).value
				r := right.(object.String).value
				switch e.op {
				case "+":
					s := strings.concatenate({l, r})
					return object.String{s}
				case:
					return new_error(
						"unknown operator: %s %s %s",
						object.to_string(&left),
						e.op,
						object.to_string(&right),
					)
				}
			case:
				return object.NULL
			}
		case ast.If_Expr:
			condition := eval(ast.Node{e.condition^}, env)
			if is_error(&condition) {return condition}
			if is_truthy(&condition) {
				obj := eval(ast.Node{ast.Stmt{e.consequence^}}, env)
				return obj
			} else if e.alternative != nil {
				obj := eval(ast.Node{ast.Stmt{e.alternative^}}, env)
				return obj
			} else {
				return object.NULL
			}
		case ast.Array_Literal:
			elems := eval_expressions(e.elements[:], env)
			if len(elems) == 1 && is_error(&elems[0]) {
				return elems[0]
			}
			return object.Array{elems}
		case ast.Index_Expr:
			left := eval(ast.Node{e.left^}, env)
			if is_error(&left) {return left}
			index := eval(ast.Node{e.index^}, env)
			if is_error(&index) {return index}
			left_type := object.get_typeid(&left)
			index_type := object.get_typeid(&index)
			switch {
			case left_type == object.Array && index_type == object.Integer:
				arr := left.(object.Array)
				index := index.(object.Integer).value

				if index < 0 || index >= i64(len(arr.elements)) {
					return object.NULL
				}
				elem := arr.elements[index]
				return elem
			case left_type == object.Hash:
				hashobj := left.(object.Hash)
				key := object.hash_key(&index)
				if key == {} {
					return new_error("unusable as hash key: %s", object.to_string(&index))
				}
				pair, ok := hashobj.pairs[key]
				if !ok {return object.NULL}
				return pair.val
			case:
				return new_error("index operator not support: %s", object.get_typeid(&left))
			}
		case ast.Hash_Literal:
			pairs := make(map[object.Hash_Key]object.Hash_Pair, env.allocator)
			for key_node, val_node in e.pairs {
				key := eval(ast.Node{key_node^}, env)
				if is_error(&key) {return key}

				hash_key := object.hash_key(&key)
				if hash_key == {} {
					return new_error("unusable as hash key: %s", object.to_string(&key))
				}
				val := eval(ast.Node{val_node}, env)
				if is_error(&val) {return val}

				pairs[hash_key] = object.Hash_Pair{hash_key, val}
			}
			return object.Hash{pairs = pairs}
		}
	}

	return {}
}

eval_expressions :: proc(exprs: []ast.Expr, env: ^object.Env) -> []object.Object {
	result := make([dynamic]object.Object, env.allocator)
	for expr in exprs {
		evaluated := eval(ast.Node{expr}, env)
		if is_error(&evaluated) {
			result := []object.Object{evaluated}
			return result
		}
		append(&result, evaluated)
	}
	return result[:]
}

is_truthy :: proc(obj: ^object.Object) -> bool {
	#partial switch v in obj {
	case object.Boolean:
		return v.value
	case object.Null:
		return false
	case:
		return true
	}
}

new_error :: proc(format: string, args: ..any) -> object.Object {
	msg := fmt.tprintf(format, ..args)
	return object.Error{msg}
}

is_error :: proc(obj: ^object.Object) -> bool {
	#partial switch &v in obj {
	case object.Error:
		return true
	case:
		return false
	}
}

