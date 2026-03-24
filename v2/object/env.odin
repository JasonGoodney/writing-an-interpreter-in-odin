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

env_extend :: proc(outer: ^Env, allocator := context.allocator) -> ^Env {
	env := new(Env, allocator)
	env.store = make(type_of(env.store), allocator)
	env.outer = outer
	env.allocator = allocator
	return env
}

env_get :: proc(env: ^Env, name: string) -> (obj: Object, ok: bool) {
	if env == nil || env == {} {return {}, false}
	obj, ok = env.store[name]
	if !ok && env.outer != nil {
		obj, ok = env_get(env.outer, name)
	}
	return obj, ok
}

env_set :: proc(env: ^Env, name: string, value: Object) -> Object {
	if env == nil {return {}}
	env.store[name] = value
	return value
}

