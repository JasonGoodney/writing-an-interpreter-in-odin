package eval

import "../ast"
import "../object"
import "core:fmt"

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
		#partial switch s in n.variant {
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
		#partial switch e in n.variant {
		case ast.Integer_Literal:
			return object.Integer{e.value}
		case ast.Boolean:
			return e.value ? object.TRUE : object.FALSE
		case ast.Ident:
			val, ok := object.env_get(env, e.value)
			if !ok {
				return new_error("identifier not found: %s", e.value)
			}
			return val
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
			fn, ok := obj.(object.Function)
			if !ok {
				return new_error("not a function: %s", object.to_string(&obj))
			}
			extended_env := object.env_extend(fn.env, context.temp_allocator)
			for param, i in fn.parameters {
				object.env_set(&extended_env, param.value, args[i])
			}
			evaluated := eval(ast.Node{ast.Stmt{fn.body^}}, &extended_env)
			if rv, ok := evaluated.(object.Return_Value); ok {
				return rv.value^
			}
			return evaluated
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
		}
	}

	return {}
}

eval_expressions :: proc(exprs: []ast.Expr, env: ^object.Env) -> []object.Object {
	result := make([dynamic]object.Object)
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

