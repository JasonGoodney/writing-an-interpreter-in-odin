package ast

import "../token"
import "core:fmt"
import "core:strings"

Node_Kind :: enum {
	Program,
	Let_Stmt,
	Ret_Stmt,
	Expr_Stmt,
	Block_Stmt,
	Ident,
	Int_Lit,
	Bool_Lit,
	String_Lit,
	Array_Lit,
	Hash_Lit,
	Fn_Lit,
	Prefix_Expr,
	Infix_Expr,
	If_Expr,
	Call_Expr,
	Index_Expr,
}

Node :: struct {
	kind:              Node_Kind,
	token:             token.Token,
	program_stmts:     []Node,
	let_stmt_name:     ^Node,
	let_stmt_val:      ^Node,
	ret_stmt_val:      ^Node,
	expr_stmt_expr:    ^Node,
	block_stmt_stmts:  []Node,
	ident_val:         string,
	int_lit_val:       i64,
	bool_lit_val:      bool,
	string_lit_val:    string,
	array_lit_elems:   []Node,
	hash_lit_pairs:    ^map[^Node]Node,
	fn_lit_params:     []Node,
	fn_lit_body:       ^Node,
	prefix_expr_op:    string,
	prefix_expr_right: ^Node,
	infix_expr_op:     string,
	infix_expr_left:   ^Node,
	infix_expr_right:  ^Node,
	if_expr_cond:      ^Node,
	if_expr_then:      ^Node,
	if_expr_else:      ^Node,
	call_expr_fn:      ^Node,
	call_expr_args:    []Node,
	index_expr_left:   ^Node,
	index_expr_index:  ^Node,
}

to_string :: proc(node: ^Node, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	defer strings.builder_destroy(&sb)
	write_node(&sb, node)
	s := strings.clone(strings.to_string(sb), allocator)
	return s
}

write_string :: strings.write_string
write_node :: proc(sb: ^strings.Builder, node: ^Node) {
	switch node.kind {
	case .Program:
		for &stmt in node.program_stmts {
			write_node(sb, &stmt)
		}
	case .Let_Stmt:
		write_string(sb, node.token.literal)
		write_string(sb, " ")
		write_node(sb, node.let_stmt_name)
		write_string(sb, " = ")
		write_node(sb, node.let_stmt_val)
		write_string(sb, ";")
	case .Ret_Stmt:
		if node.ret_stmt_val == {} {
			write_string(sb, node.token.literal)
			write_string(sb, " ")
			write_node(sb, node.ret_stmt_val)
		}
	case .Expr_Stmt:
		if node.expr_stmt_expr == {} {
			write_node(sb, node.expr_stmt_expr)
		}
	case .Block_Stmt:
		for &stmt in node.block_stmt_stmts {
			write_node(sb, &stmt)
		}
	case .Ident:
		write_string(sb, node.ident_val)
	case .Int_Lit:
		write_string(sb, node.token.literal)
	case .Bool_Lit:
		write_string(sb, node.token.literal)
	case .String_Lit:
		write_string(sb, node.token.literal)
	case .Array_Lit:
		write_string(sb, "[")
		delim := false
		for &elem in node.array_lit_elems {
			if delim {
				write_string(sb, ", ")
			}
			write_node(sb, &elem)
			delim = true
		}
		write_string(sb, "]")
	case .Hash_Lit:
		write_string(sb, "{")
		delim := false
		for key, &val in node.hash_lit_pairs {
			if delim {
				write_string(sb, ", ")
			}
			write_node(sb, key)
			write_string(sb, ":")
			write_node(sb, &val)
			delim = true
		}
		write_string(sb, "}")
	case .Prefix_Expr:
		write_string(sb, "(")
		write_string(sb, node.prefix_expr_op)
		write_node(sb, node.prefix_expr_right)
		write_string(sb, ")")
	case .Infix_Expr:
		write_string(sb, "(")
		write_node(sb, node.infix_expr_left)
		write_string(sb, " ")
		write_string(sb, node.prefix_expr_op)
		write_string(sb, " ")
		write_node(sb, node.prefix_expr_right)
		write_string(sb, ")")
	case .If_Expr:
		write_string(sb, "if")
		write_node(sb, node.if_expr_cond)
		write_string(sb, " ")
		write_node(sb, node.if_expr_then)
		if node.if_expr_else != nil {
			write_string(sb, "else")
			write_node(sb, node.if_expr_else)
		}
	case .Fn_Lit:
		write_string(sb, node.token.literal)
		write_string(sb, "(")
		delim := false
		for &param in node.fn_lit_params {
			if delim {
				write_string(sb, ", ")
				write_node(sb, &param)
			}
		}
		write_string(sb, ")")
	case .Call_Expr:
		write_string(sb, node.token.literal)
		write_string(sb, "(")
		delim := false
		for &arg in node.call_expr_args {
			if delim {
				write_string(sb, ", ")
				write_node(sb, &arg)
			}
		}
		write_string(sb, ")")
	case .Index_Expr:
		write_string(sb, "(")
		write_node(sb, node.index_expr_left)
		write_string(sb, "[")
		write_node(sb, node.index_expr_index)
		write_string(sb, "])")
	}
}

// to_string :: proc {
// 	program_to_string,
// 	stmt_to_string,
// 	expr_to_string,
// 	let_stmt_to_string,
// 	return_stmt_to_string,
// 	expr_stmt_to_string,
// 	block_stmt_to_string,
// 	ident_to_string,
// 	integer_literal_to_string,
// 	boolean_to_string,
// 	prefix_expr_to_string,
// 	infix_expr_to_string,
// 	if_expr_to_string,
// 	function_literal_to_string,
// 	call_expr_to_string,
// 	string_literal_to_string,
// 	array_literal_to_string,
// 	index_expr_to_string,
// 	hash_literal_to_string,
// }

// // ======= Program =============================
// Program :: struct {
// 	stmts: [dynamic]Stmt,
// }
// program_to_string :: proc(program: ^Program) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	defer strings.builder_destroy(&sb)
// 	for &s in program.stmts {
// 		str := to_string(&s)
// 		strings.write_string(&sb, str)
// 	}

// 	str := strings.clone(strings.to_string(sb), context.temp_allocator)
// 	return str
// }

// // ======= Statements =============================
// Stmt :: struct {
// 	variant: union {
// 		Let_Stmt,
// 		Return_Stmt,
// 		Expr_Stmt,
// 		Block_Stmt,
// 	},
// }
// stmt_to_string :: proc(stmt: ^Stmt) -> string {
// 	switch &v in stmt.variant {
// 	case Let_Stmt:
// 		return to_string(&v)
// 	case Return_Stmt:
// 		return to_string(&v)
// 	case Expr_Stmt:
// 		return to_string(&v)
// 	case Block_Stmt:
// 		return to_string(&v)
// 	case:
// 		return fmt.tprintf("Unknown statement: %v", stmt)
// 	}
// }

// Let_Stmt :: struct {
// 	token: token.Token,
// 	name:  Ident,
// 	value: Expr,
// }
// let_stmt_to_string :: proc(stmt: ^Let_Stmt) -> string {
// 	return fmt.tprintf(
// 		"%s %s = %s;",
// 		stmt.token.literal,
// 		to_string(&stmt.name),
// 		to_string(&stmt.value),
// 	)
// }

// Return_Stmt :: struct {
// 	token:        token.Token,
// 	return_value: Expr,
// }
// return_stmt_to_string :: proc(stmt: ^Return_Stmt) -> string {
// 	if stmt.return_value == {} {return ""}
// 	return fmt.tprintf("{} {};", stmt.token.literal, to_string(&stmt.return_value))
// }

// Expr_Stmt :: struct {
// 	token: token.Token,
// 	expr:  Expr,
// }
// expr_stmt_to_string :: proc(stmt: ^Expr_Stmt) -> string {
// 	if stmt.expr == {} {return ""}
// 	return to_string(&stmt.expr)
// }

// Block_Stmt :: struct {
// 	token: token.Token,
// 	stmts: [dynamic]Stmt,
// }
// block_stmt_to_string :: proc(stmt: ^Block_Stmt) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	for &s in stmt.stmts {
// 		strings.write_string(&sb, stmt_to_string(&s))
// 	}
// 	return strings.clone(strings.to_string(sb), context.temp_allocator)
// }

// // ======= Expression =============================
// Expr :: struct {
// 	variant: union {
// 		Ident,
// 		Integer_Literal,
// 		Boolean,
// 		Prefix_Expr,
// 		Infix_Expr,
// 		If_Expr,
// 		Function_Literal,
// 		Call_Expr,
// 		String_Literal,
// 		Array_Literal,
// 		Index_Expr,
// 		Hash_Literal,
// 	},
// }
// expr_to_string :: proc(expr: ^Expr) -> string {
// 	switch &v in expr.variant {
// 	case Ident:
// 		return to_string(&v)
// 	case Integer_Literal:
// 		return to_string(&v)
// 	case Boolean:
// 		return to_string(&v)
// 	case Prefix_Expr:
// 		return to_string(&v)
// 	case Infix_Expr:
// 		return to_string(&v)
// 	case If_Expr:
// 		return to_string(&v)
// 	case Function_Literal:
// 		return to_string(&v)
// 	case Call_Expr:
// 		return to_string(&v)
// 	case String_Literal:
// 		return to_string(&v)
// 	case Array_Literal:
// 		return to_string(&v)
// 	case Index_Expr:
// 		return to_string(&v)
// 	case Hash_Literal:
// 		return to_string(&v)
// 	case:
// 		return fmt.tprintf("Unknown expression: %v", expr)
// 	}
// }

// Ident :: struct {
// 	token: token.Token,
// 	value: string,
// }
// ident_to_string :: proc(expr: ^Ident) -> string {
// 	return expr.value
// }

// Integer_Literal :: struct {
// 	token: token.Token,
// 	value: i64,
// }
// integer_literal_to_string :: proc(expr: ^Integer_Literal) -> string {
// 	return expr.token.literal
// }

// String_Literal :: struct {
// 	token: token.Token,
// 	value: string,
// }
// string_literal_to_string :: proc(expr: ^String_Literal) -> string {
// 	return expr.token.literal
// }

// Boolean :: struct {
// 	token: token.Token,
// 	value: bool,
// }
// boolean_to_string :: proc(expr: ^Boolean) -> string {
// 	return expr.token.literal
// }

// Prefix_Expr :: struct {
// 	token: token.Token,
// 	op:    string,
// 	right: ^Expr,
// }
// prefix_expr_to_string :: proc(expr: ^Prefix_Expr) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, "(")
// 	strings.write_string(&sb, expr.op)
// 	strings.write_string(&sb, to_string(expr.right))
// 	strings.write_string(&sb, ")")
// 	return strings.clone(strings.to_string(sb), context.temp_allocator)
// }

// Infix_Expr :: struct {
// 	token: token.Token,
// 	op:    string,
// 	left:  ^Expr,
// 	right: ^Expr,
// }
// infix_expr_to_string :: proc(expr: ^Infix_Expr) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, "(")
// 	strings.write_string(&sb, to_string(expr.left))
// 	strings.write_string(&sb, " ")
// 	strings.write_string(&sb, expr.op)
// 	strings.write_string(&sb, " ")
// 	strings.write_string(&sb, to_string(expr.right))
// 	strings.write_string(&sb, ")")
// 	return strings.clone(strings.to_string(sb), context.temp_allocator)
// }

// If_Expr :: struct {
// 	token:       token.Token,
// 	condition:   ^Expr,
// 	consequence: ^Block_Stmt,
// 	alternative: ^Block_Stmt,
// }

// if_expr_to_string :: proc(expr: ^If_Expr) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, "if")
// 	strings.write_string(&sb, to_string(expr.condition))
// 	strings.write_string(&sb, " ")
// 	strings.write_string(&sb, to_string(expr.consequence))
// 	if expr.alternative != nil {
// 		strings.write_string(&sb, "else ")
// 		strings.write_string(&sb, to_string(expr.alternative))
// 	}

// 	return strings.clone(strings.to_string(sb), context.temp_allocator)
// }

// Function_Literal :: struct {
// 	token:      token.Token, // 'fn' token
// 	parameters: ^[dynamic]Ident,
// 	body:       ^Block_Stmt,
// }
// function_literal_to_string :: proc(expr: ^Function_Literal) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, expr.token.literal)
// 	strings.write_string(&sb, "(")
// 	if len(expr.parameters) > 0 {
// 		strings.write_string(&sb, to_string(&expr.parameters[0]))
// 		for i := 1; i < len(expr.parameters); i += 1 {
// 			strings.write_string(&sb, ", ")
// 			strings.write_string(&sb, to_string(&expr.parameters[i]))
// 		}
// 	}
// 	strings.write_string(&sb, ")")
// 	strings.write_string(&sb, to_string(expr.body))

// 	return strings.clone(strings.to_string(sb), context.temp_allocator)
// }

// Call_Expr :: struct {
// 	token:     token.Token, // '(' token,
// 	function:  ^Expr,
// 	arguments: ^[dynamic]Expr,
// }
// call_expr_to_string :: proc(expr: ^Call_Expr) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, to_string(expr.function))
// 	strings.write_string(&sb, "(")
// 	if len(expr.arguments) > 0 {
// 		strings.write_string(&sb, to_string(&expr.arguments[0]))
// 		for i := 1; i < len(expr.arguments); i += 1 {
// 			strings.write_string(&sb, ", ")
// 			strings.write_string(&sb, to_string(&expr.arguments[i]))
// 		}
// 	}
// 	strings.write_string(&sb, ")")

// 	return strings.clone(strings.to_string(sb), context.temp_allocator)
// }

// Array_Literal :: struct {
// 	token:    token.Token,
// 	elements: ^[dynamic]Expr,
// }
// array_literal_to_string :: proc(expr: ^Array_Literal) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, "[")
// 	if len(expr.elements) > 0 {
// 		strings.write_string(&sb, to_string(&expr.elements[0]))
// 		for i := 1; i < len(expr.elements); i += 1 {
// 			strings.write_string(&sb, ", ")
// 			strings.write_string(&sb, to_string(&expr.elements[i]))
// 		}
// 	}
// 	strings.write_string(&sb, "]")
// 	return strings.clone(strings.to_string(sb), context.temp_allocator)
// }

// Index_Expr :: struct {
// 	token: token.Token,
// 	left:  ^Expr,
// 	index: ^Expr,
// }
// index_expr_to_string :: proc(expr: ^Index_Expr) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, "(")
// 	strings.write_string(&sb, to_string(expr.left))
// 	strings.write_string(&sb, "[")
// 	strings.write_string(&sb, to_string(expr.index))
// 	strings.write_string(&sb, "])")
// 	return strings.clone(strings.to_string(sb))
// }

// Hash_Literal :: struct {
// 	token: token.Token,
// 	// keys:  ^[dynamic]Expr,
// 	// vals:  ^[dynamic]Expr,
// 	pairs: ^map[^Expr]Expr,
// }

// hash_literal_to_string :: proc(expr: ^Hash_Literal) -> string {
// 	sb := strings.builder_make(context.temp_allocator)
// 	strings.write_string(&sb, "{")

// 	pairs := make([dynamic]string, context.temp_allocator)
// 	// for &k, i in expr.keys {
// 	// 	key := expr_to_string(&k)
// 	// 	val := expr_to_string(&expr.vals[i])
// 	// 	str := strings.concatenate({key, ":", val}, context.temp_allocator)
// 	// 	append(&pairs, str)
// 	// }

// 	for k, &v in expr.pairs {
// 		key := expr_to_string(k)
// 		val := expr_to_string(&v)
// 		str := strings.concatenate({key, ":", val}, context.temp_allocator)
// 		append(&pairs, str)
// 	}

// 	strings.write_string(&sb, strings.join(pairs[:], ", ", context.temp_allocator))
// 	strings.write_string(&sb, "}")
// 	return strings.clone(strings.to_string(sb))
// }
