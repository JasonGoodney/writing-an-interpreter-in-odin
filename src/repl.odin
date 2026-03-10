package main

import "core:bufio"
import "core:fmt"
import "core:io"

Prompt :: ">> "

repl_start :: proc(_in: io.Reader, _out: io.Writer) {
	scanner := new(bufio.Scanner)
	scanner = bufio.scanner_init(scanner, _in)

	for {
		io.write_string(_out, Prompt)
		scanned := bufio.scan(scanner)
		if !scanned {
			return
		}

		line := bufio.scanner_text(scanner)

		lexer := lexer_init(line)
		for tok := next_token(lexer); tok.type != .EOF; tok = next_token(lexer) {
			s := fmt.tprintf("%v\n", tok)
			io.write_string(_out, s)
		}
	}
}

