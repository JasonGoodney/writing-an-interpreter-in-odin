#+ feature dynamic-literals

package eval

import "../ast"
import "../object"
import "core:fmt"
import "core:strings"

eval :: proc(node: ^ast.Node, env: ^object.Env) -> object.Object {
	switch n in node.derived {
	case ^ast.Program:
		result: object.Object
		for stmt in n.stmts {
			result = eval(stmt, env)
			#partial switch v in result {
			case object.Return_Value:
				return v.value^
			case object.Error:
				return v
			}
		}
		return result
	case ^ast.Expr_Stmt:
		return eval(n.expr, env)
	case ^ast.Block_Stmt:
		result: object.Object
		for stmt in n.stmts {
			result = eval(stmt, env)
			#partial switch v in result {
			case object.Return_Value, object.Error:
				return result
			}
		}
		return result
	case ^ast.Return_Stmt:
		val := eval(n.return_value, env)
		if is_error(&val) {return val}
		return object.Return_Value{&val}
	case ^ast.Let_Stmt:
		val := eval(n.value, env)
		if is_error(&val) {return val}
		object.env_set(env, n.name.value, val)
	case ^ast.Integer_Literal:
		return object.Integer{n.value}
	case ^ast.String_Literal:
		return object.String{n.value}
	case ^ast.Boolean:
		return n.value ? object.TRUE : object.FALSE
	case ^ast.Ident:
		if val, ok := object.env_get(env, n.value); ok {return val}
		if builtin, ok := builtins[n.value]; ok {return builtin}
		return new_error("identifier not found: %s", n.value)
	case ^ast.Function_Literal:
		params := n.parameters
		body := n.body
		return object.Function{parameters = params[:], body = body, env = env}
	case ^ast.Call_Expr:
		obj := eval(n.function, env)
		if is_error(&obj) {return obj}
		args := eval_expressions(n.arguments[:], env)
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
			evaluated := eval(fn.body, extended_env)
			if rv, ok := evaluated.(object.Return_Value); ok {
				return rv.value^
			}
			return evaluated
		case object.Builtin:
			return v.fn(..args)
		case:
			return new_error("not a function: %s", object.to_string(&obj))
		}
	case ^ast.Prefix_Expr:
		right := eval(n.right, env)
		if is_error(&right) {return right}
		switch n.op {
		case "!":
			b := is_truthy(&right)
			return b ? object.FALSE : object.TRUE
		case "-":
			if integer, ok := right.(object.Integer); ok {
				return object.Integer{value = -integer.value}
			} else {
				return new_error("unknown operator: %s%s", n.op, object.to_string(&right))
			}
		case:
			return new_error("unknown operator: %s%s", n.op, object.to_string(&right))
		}
	case ^ast.Infix_Expr:
		left := eval(n.left, env)
		if is_error(&left) {return left}
		right := eval(n.right, env)
		if is_error(&right) {return right}
		left_typeid := object.get_typeid(&left)
		right_typeid := object.get_typeid(&right)
		switch {
		case left_typeid != right_typeid:
			return new_error(
				"type mismatch: %s %s %s",
				object.to_string(&left),
				n.op,
				object.to_string(&right),
			)
		case left_typeid == object.Integer && right_typeid == object.Integer:
			l := left.(object.Integer).value
			r := right.(object.Integer).value
			switch n.op {
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
					n.op,
					object.to_string(&right),
				)
			}
		case left_typeid == object.Boolean && right_typeid == object.Boolean:
			l := left.(object.Boolean).value
			r := right.(object.Boolean).value
			switch n.op {
			case "==":
				return l == r ? object.TRUE : object.FALSE
			case "!=":
				return l != r ? object.TRUE : object.FALSE
			case:
				return new_error(
					"unknown operator: %s %s %s",
					object.to_string(&left),
					n.op,
					object.to_string(&right),
				)
			}
		case left_typeid == object.String && right_typeid == object.String:
			l := left.(object.String).value
			r := right.(object.String).value
			switch n.op {
			case "+":
				s := strings.concatenate({l, r})
				return object.String{s}
			case:
				return new_error(
					"unknown operator: %s %s %s",
					object.to_string(&left),
					n.op,
					object.to_string(&right),
				)
			}
		case:
			return object.NULL
		}
	case ^ast.If_Expr:
		condition := eval(n.condition, env)
		if is_error(&condition) {return condition}
		if is_truthy(&condition) {
			obj := eval(n.consequence, env)
			return obj
		} else if n.alternative != nil {
			obj := eval(n.alternative, env)
			return obj
		} else {
			return object.NULL
		}
	case ^ast.Array_Literal:
		elems := eval_expressions(n.elements[:], env)
		if len(elems) == 1 && is_error(&elems[0]) {
			return elems[0]
		}
		return object.Array{elems}
	case ^ast.Index_Expr:
		left := eval(n.left, env)
		if is_error(&left) {return left}
		index := eval(n.index, env)
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
	case ^ast.Hash_Literal:
		pairs := make(map[object.Hash_Key]object.Hash_Pair, env.allocator)
		for key_node, val_node in n.pairs {
			key := eval(key_node, env)
			if is_error(&key) {return key}

			hash_key := object.hash_key(&key)
			if hash_key == {} {
				return new_error("unusable as hash key: %s", object.to_string(&key))
			}
			val := eval(val_node, env)
			if is_error(&val) {return val}

			pairs[hash_key] = object.Hash_Pair{hash_key, val}
		}
		return object.Hash{pairs = pairs}
	}

	return {}
}

eval_expressions :: proc(exprs: []^ast.Expr, env: ^object.Env) -> []object.Object {
	result := make([dynamic]object.Object, env.allocator)
	for expr in exprs {
		evaluated := eval(expr, env)
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
