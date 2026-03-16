package main

import "core:log"
import "core:os"

main :: proc() {
	context.logger = log.create_console_logger()

	reader := os.to_reader(os.stdin)
	writer := os.to_writer(os.stdout)
	repl_start(reader, writer)
}

