package object

import "core:testing"

expect :: proc(t: ^testing.T, ok: bool, format: string, args: ..any) -> bool {
	result := testing.expectf(t, ok, format, ..args)
	assert(result)
	return true
}

@(test)
test_string_hash_key :: proc(t: ^testing.T) {
	hello1 := &String{"hello world"}
	hello2 := &String{"hello world"}
	diff1 := &String{"my name is johnny"}
	diff2 := &String{"my name is johnny"}

	expect(
		t,
		hash_key(hello1) == hash_key(hello2),
		"strings with the same content have different hash keys",
	)
	expect(
		t,
		hash_key(diff1) == hash_key(diff2),
		"strings with the same content have different hash keys",
	)
	expect(
		t,
		hash_key(hello1) != hash_key(diff1),
		"strings with the different content have same hash keys",
	)
}
