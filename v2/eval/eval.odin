package eval

import "../ast"
import "../object"
import "core:fmt"

eval :: proc(node: ast.Node) -> object.Object {
	switch n in node.variant {
	case ast.Program:
		result: object.Object
		for stmt in n.stmts {
			result = eval(ast.Node{stmt})
		}
		return result
	case ast.Stmt:
		#partial switch s in n.variant {
		case ast.Expr_Stmt:
			return eval(ast.Node{s.expr})
		case ast.Block_Stmt:
			result: object.Object
			for stmt in s.stmts {
				result = eval(ast.Node{stmt^})
			}
			return result
		}
	case ast.Expr:
		#partial switch e in n.variant {
		case ast.Integer_Literal:
			return object.Integer{e.value}
		case ast.Boolean:
			return e.value ? object.TRUE : object.FALSE
		case ast.Prefix_Expr:
			switch e.op {
			case "!":
				obj := eval(ast.Node{e.right^})
				b := is_truthy(obj)
				return b ? object.FALSE : object.TRUE
			case "-":
				obj := eval(ast.Node{e.right^})
				if integer, ok := obj.(object.Integer); ok {
					return object.Integer{value = -integer.value}
				} else {
					return object.NULL
				}
			case:
				return object.NULL
			}
		case ast.Infix_Expr:
			left := eval(ast.Node{e.left^})
			right := eval(ast.Node{e.right^})
			left_typeid := typeid_of(&left)
			right_typeid := typeid_of(&right)
			switch {
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
					return object.NULL
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
					return object.NULL
				}
			case:
				return object.NULL
			}
		case ast.If_Expr:
			condition := eval(ast.Node{e.condition^})
			if is_truthy(condition) {
				obj := eval(ast.Node{ast.Stmt{e.consequence^}})
				return obj
			} else if e.alternative != nil {
				obj := eval(ast.Node{ast.Stmt{e.alternative^}})
				return obj
			} else {
				return object.NULL
			}
		}
	}

	return {}
}

typeid_of :: proc(obj: ^object.Object) -> typeid {
	switch v in obj {
	case object.Integer:
		return object.Integer
	case object.Boolean:
		return object.Boolean
	case object.Null:
		return object.Null
	}

	return {}
}

is_truthy :: proc(obj: object.Object) -> bool {
	#partial switch v in obj {
	case object.Boolean:
		return v.value
	case object.Null:
		return false
	case:
		return true
	}
}
