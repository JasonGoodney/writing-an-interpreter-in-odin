package repl

import "../lexer"
import "core:bufio"
import "core:fmt"
import "core:io"

start :: proc(_in: io.Reader, _out: io.Writer) {
	scanner := new(bufio.Scanner)
	scanner = bufio.scanner_init(scanner, _in)

	for {
		allocator := context.temp_allocator
		defer free_all(allocator)

		io.write_string(_out, ">> ")
		scanned := bufio.scan(scanner)
		if !scanned {
			return
		}
		line := bufio.scanner_text(scanner)
		l := lexer.init(line, allocator)

		for tok := lexer.next_token(l); tok.type != .EOF; tok = lexer.next_token(l) {
			fmt.printf("%v\n", tok)
		}
	}
}
