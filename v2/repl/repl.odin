package repl

import "../ast"
import "../eval"
import "../lexer"
import "../object"
import "../parser"
import "core:bufio"
import "core:fmt"
import "core:io"

start :: proc(reader: io.Reader, writer: io.Writer) {
	scanner := new(bufio.Scanner)
	scanner = bufio.scanner_init(scanner, reader)

	for {
		allocator := context.temp_allocator
		defer free_all(allocator)

		io.write_string(writer, ">> ")
		scanned := bufio.scan(scanner)
		if !scanned {
			return
		}
		line := bufio.scanner_text(scanner)
		l := lexer.init(line, allocator)
		p := parser.init(l, allocator)
		program := parser.parse_program(p)
		if len(p.errors) > 0 {
			for err in p.errors {
				io.write_string(writer, "\t")
				io.write_string(writer, err)
				io.write_string(writer, "\n")
			}
		}

		evaluated := eval.eval(ast.Node{program})
		if evaluated != {} {
			io.write_string(writer, object.inspect(&evaluated))
			io.write_string(writer, "\n")
		}
	}
}
