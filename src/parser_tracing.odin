package main

import "core:fmt"
import "core:strings"

traceLevel := 0

traceIdentPlaceholder :: "  "

identLevel :: proc(allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	defer strings.builder_destroy(&sb)
	for i := 0; i < traceLevel; i += 1 {
		strings.write_string(&sb, traceIdentPlaceholder)
	}
	indent := strings.clone(strings.to_string(sb), allocator)
	return indent
}

tracePrint :: proc(fs: string, allocator := context.allocator) {
	fmt.printf("%s%s\n", identLevel(allocator), fs)
}

incIdent :: proc() {traceLevel = traceLevel + 1}
decIdent :: proc() {traceLevel = traceLevel - 1}

trace :: proc(msg: string, allocator := context.allocator) -> string {
	incIdent()
	tracePrint(strings.concatenate({"BEGIN ", msg}, allocator), allocator)
	return msg
}

untrace :: proc(msg: string, allocator := context.allocator) {
	tracePrint(strings.concatenate({"END ", msg}, allocator), allocator)
	decIdent()
}

