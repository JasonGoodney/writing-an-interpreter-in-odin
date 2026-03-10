package main

import "core:os"

main :: proc() {

	reader := os.to_reader(os.stdin)
	writer := os.to_writer(os.stdout)
	repl_start(reader, writer)
}

