package ast

import "../token"
import "base:intrinsics"
import "core:mem"
import "core:strings"

new :: proc {
	new_node,
	new_node_from_token,
}

new_node :: proc($T: typeid, allocator := context.allocator) -> ^T {
	n, _ := mem.new(T, allocator)
	n.derived = n

	when intrinsics.type_has_field(T, "derived_expr") {
		n.derived_expr = n
	}
	when intrinsics.type_has_field(T, "derived_stmt") {
		n.derived_stmt = n
	}
	return n
}

new_node_from_token :: proc($T: typeid, token: token.Token, allocator := context.allocator) -> ^T {
	n, _ := mem.new(T, allocator)
	n.token = token
	n.derived = n

	when intrinsics.type_has_field(T, "derived_expr") {
		n.derived_expr = n
	}
	when intrinsics.type_has_field(T, "derived_stmt") {
		n.derived_stmt = n
	}
	return n
}

Node :: struct {
	token:   token.Token,
	derived: Any_Node,
}

Prog :: struct {
	using prog_base: Node,
	stmts:           []Stmt,
}

Expr :: struct {
	using expr_base: Node,
	derived_expr:    Any_Expr,
}

Stmt :: struct {
	using stmt_base: Node,
	derived_stmt:    Any_Stmt,
}

Any_Node :: union {
	^Program,
	^Let_Stmt,
	^Return_Stmt,
	^Expr_Stmt,
	^Block_Stmt,
	^Ident,
	^Integer_Literal,
	^Boolean,
	^String_Literal,
	^Array_Literal,
	^Hash_Literal,
	^Prefix_Expr,
	^Infix_Expr,
	^If_Expr,
	^Function_Literal,
	^Call_Expr,
	^Index_Expr,
}

Any_Stmt :: union {
	^Let_Stmt,
	^Return_Stmt,
	^Expr_Stmt,
	^Block_Stmt,
}

Any_Expr :: union {
	^Ident,
	^Integer_Literal,
	^Boolean,
	^String_Literal,
	^Array_Literal,
	^Hash_Literal,
	^Prefix_Expr,
	^Infix_Expr,
	^If_Expr,
	^Function_Literal,
	^Call_Expr,
	^Index_Expr,
}

to_string :: proc(node: ^Node, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	defer strings.builder_destroy(&sb)
	write_node(&sb, node)
	s := strings.to_string(sb)
	return strings.clone(s, allocator)
}

write_string :: strings.write_string
@(private)
write_node :: proc(sb: ^strings.Builder, node: ^Node) {
	switch v in node.derived {
	case ^Program:
		for stmt in v.stmts {
			write_node(sb, stmt)
		}
	case ^Let_Stmt:
		write_string(sb, v.token.literal)
		write_string(sb, " ")
		write_node(sb, v.name)
		write_string(sb, " = ")
		write_node(sb, v.value)
		write_string(sb, ";")
	case ^Return_Stmt:
		if v.return_value != nil {
			write_string(sb, v.token.literal)
			write_string(sb, " ")
			write_node(sb, v.return_value)
		}
	case ^Expr_Stmt:
		if v.expr != nil {
			write_node(sb, v.expr)
		}
	case ^Block_Stmt:
		for stmt in v.stmts {
			write_node(sb, stmt)
		}
	case ^Ident:
		write_string(sb, v.value)
	case ^Integer_Literal:
		write_string(sb, v.token.literal)
	case ^Boolean:
		write_string(sb, v.token.literal)
	case ^String_Literal:
		write_string(sb, v.token.literal)
	case ^Array_Literal:
		write_string(sb, "[")
		delim := false
		for elem in v.elements {
			if delim {write_string(sb, ", ")}
			delim = true

			write_node(sb, elem)

		}
		write_string(sb, "]")
	case ^Hash_Literal:
		write_string(sb, "{")
		delim := false
		for key, &val in v.pairs {
			if delim {write_string(sb, ", ")}
			delim = true

			write_node(sb, key)
			write_string(sb, ":")
			write_node(sb, val)

		}
		write_string(sb, "}")
	case ^Prefix_Expr:
		write_string(sb, "(")
		write_string(sb, v.op)
		write_node(sb, v.right)
		write_string(sb, ")")
	case ^Infix_Expr:
		write_string(sb, "(")
		write_node(sb, v.left)
		write_string(sb, " ")
		write_string(sb, v.op)
		write_string(sb, " ")
		write_node(sb, v.right)
		write_string(sb, ")")
	case ^If_Expr:
		write_string(sb, "if")
		write_node(sb, v.condition)
		write_string(sb, " ")
		write_node(sb, v.consequence)
		if v.alternative != nil {
			write_string(sb, "else")
			write_node(sb, v.alternative)
		}
	case ^Function_Literal:
		write_string(sb, v.token.literal)
		write_string(sb, "(")
		delim := false
		for param in v.parameters {
			if delim {write_string(sb, ", ")}
			delim = true
			write_node(sb, param)

		}
		write_string(sb, ")")
	case ^Call_Expr:
		write_node(sb, v.function)
		write_string(sb, "(")
		delim := false
		for arg in v.arguments {
			if delim {write_string(sb, ", ")}
			delim = true
			write_node(sb, arg)
		}
		write_string(sb, ")")
	case ^Index_Expr:
		write_string(sb, "(")
		write_node(sb, v.left)
		write_string(sb, "[")
		write_node(sb, v.index)
		write_string(sb, "])")
	}
}

// ======= Program =============================
Program :: struct {
	using node: Node,
	stmts:      []^Stmt,
}

// ======= Statements =============================

Let_Stmt :: struct {
	using node: Stmt,
	name:       ^Ident,
	value:      ^Expr,
}

Return_Stmt :: struct {
	using node:   Stmt,
	return_value: ^Expr,
}

Expr_Stmt :: struct {
	using node: Stmt,
	expr:       ^Expr,
}

Block_Stmt :: struct {
	using node: Stmt,
	stmts:      []^Stmt,
}

// ======= Expression =============================

Ident :: struct {
	using node: Expr,
	value:      string,
}

Integer_Literal :: struct {
	using node: Expr,
	value:      i64,
}

String_Literal :: struct {
	using node: Expr,
	value:      string,
}

Boolean :: struct {
	using node: Expr,
	value:      bool,
}

Prefix_Expr :: struct {
	using node: Expr,
	op:         string,
	right:      ^Expr,
}

Infix_Expr :: struct {
	using node: Expr,
	op:         string,
	left:       ^Expr,
	right:      ^Expr,
}

If_Expr :: struct {
	using node:  Expr,
	condition:   ^Expr,
	consequence: ^Block_Stmt,
	alternative: ^Block_Stmt,
}

Function_Literal :: struct {
	using node: Expr, // 'fn' token
	parameters: []^Ident,
	body:       ^Block_Stmt,
}

Call_Expr :: struct {
	using node: Expr, // '(' token,
	function:   ^Expr,
	arguments:  []^Expr,
}

Array_Literal :: struct {
	using node: Expr,
	elements:   []^Expr,
}

Index_Expr :: struct {
	using node: Expr,
	left:       ^Expr,
	index:      ^Expr,
}

Hash_Literal :: struct {
	using node: Expr,
	pairs:      map[^Expr]^Expr,
}
