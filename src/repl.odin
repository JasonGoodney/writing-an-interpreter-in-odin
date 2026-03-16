package main

import "core:bufio"
import "core:fmt"
import "core:io"
import "core:strings"

Prompt :: ">> "

repl_start :: proc(_in: io.Reader, _out: io.Writer) {
	scanner := new(bufio.Scanner)
	scanner = bufio.scanner_init(scanner, _in)

	for {
		alloc := context.temp_allocator
		defer free_all(alloc)

		io.write_string(_out, Prompt)
		scanned := bufio.scan(scanner)
		if !scanned {
			return
		}

		line := bufio.scanner_text(scanner)
		lexer := lexer_init(line, alloc)
		parser := parser_init(lexer, alloc)
		program := parse_program(parser)

		if len(parser.errors) > 0 {
			for msg in parser.errors {
				s := strings.concatenate({"\t", msg, "\n"})
				io.write_string(_out, s)
			}
			continue
		}

		io.write_string(_out, to_string(program))
		io.write_string(_out, "\n")
	}
}

