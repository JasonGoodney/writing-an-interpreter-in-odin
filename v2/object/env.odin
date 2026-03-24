package object

import "base:runtime"
import "core:strings"
Env :: struct {
	store:     map[string]Object,
	outer:     ^Env,
	allocator: runtime.Allocator,
}

env_init :: proc(allocator := context.allocator) -> Env {
	return Env{allocator = allocator}
}

env_extend :: proc(outer: ^Env, allocator := context.allocator) -> Env {
	return Env{outer = outer, allocator = allocator}
}

env_get :: proc(env: ^Env, name: string) -> (obj: Object, ok: bool) {
	if env == nil {return {}, false}
	obj, ok = env.store[name]
	if !ok && env.outer != nil {
		obj, ok = env_get(env.outer, name)
	}
	return obj, ok
}

env_set :: proc(env: ^Env, name: string, value: Object) -> Object {
	if env == nil {return {}}
	env.store[strings.clone(name)] = value
	return value
}
