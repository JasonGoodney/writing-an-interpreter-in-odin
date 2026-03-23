package object

Env :: struct {
	store: map[string]Object,
}

env_init :: proc(allocator := context.allocator) -> Env {
	return Env{}
}

env_get :: proc(env: ^Env, name: string) -> (obj: Object, ok: bool) {
	if env == nil {return {}, false}
	return env.store[name]
}

env_set :: proc(env: ^Env, name: string, value: Object) -> Object {
	if env == nil {return {}}
	env.store[name] = value
	return value
}
