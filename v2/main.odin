package main

import "core:os"
import "repl"

main :: proc() {
	repl.start(os.to_reader(os.stdin), os.to_writer(os.stdout))
}
