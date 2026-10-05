class_name SimState
extends RefCounted
## The rules' snapshots and state hash (milestone-1 tasks 5, 134 and 6), so a
## replay can be checked step by step and a match saved and restored.
##
## A snapshot is a Dictionary held in memory: a copy of every field the rules
## own, field by field. Each rules class captures itself with capture(), which
## copies all of its script variables except those it names as not state
## (back links such as a fighter's world, and output such as the world's
## events), and turns its links to other rules objects into fighter ids
## itself; apply() puts a capture back. Copies never share a mutable object
## with the live rules, in either direction, so a snapshot can be restored
## any number of times. The content the rules read (a WeaponDef, an
## AttackDef, a FighterBody, the computer's AIParams) never changes during a
## match and stays shared.
##
## state_hash() is SHA-256 over a canonical form of a snapshot: the content
## by its id, V3 and V2 as their numbers, any other object as its fields in
## order, then var_to_bytes(), which writes every float exactly.

## Script variables are those with this usage flag (not the engine's own).
const _SCRIPT_VAR: int = PROPERTY_USAGE_SCRIPT_VARIABLE

## Script -> its script variables' names.
static var _fields: Dictionary = {}


## A copy of every script variable of `obj` except those named in `skip`.
static func capture(obj: Object, skip: Array[StringName] = []) -> Dictionary:
	var out: Dictionary = {}
	for n: StringName in fields(obj):
		if not skip.has(n):
			out[n] = copy(obj.get(n))
	return out


## Puts a capture back into `obj` (a copy of it, so the capture stays as it
## was).
static func apply(obj: Object, state: Dictionary) -> void:
	for n: Variant in state:
		obj.set(n, copy(state[n]))


## The names of `obj`'s script variables, in declaration order.
static func fields(obj: Object) -> Array[StringName]:
	var script: Script = obj.get_script()
	var known: Variant = _fields.get(script)
	if known != null:
		return known
	var out: Array[StringName] = []
	for p: Dictionary in obj.get_property_list():
		if int(p["usage"]) & _SCRIPT_VAR:
			out.append(StringName(p["name"]))
	_fields[script] = out
	return out


## Whether `v` is content: read by the rules, never changed during a match.
static func is_content(v: Object) -> bool:
	return v is WeaponDef or v is AttackDef or v is FighterBody or v is AIBrain.AIParams


## A deep copy of a value the rules own: arrays (typed ones stay typed) and
## dictionaries element by element, packed arrays duplicated, content shared,
## and any other object (V3, an AttackState, a Tap) rebuilt field by field.
static func copy(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var a: Array = (v as Array).duplicate()
			for i: int in a.size():
				a[i] = copy(a[i])
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = (v as Dictionary).duplicate()
			for k: Variant in d:
				d[k] = copy(d[k])
			return d
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
				TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, \
				TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return v.duplicate()
		TYPE_OBJECT:
			var o: Object = v
			if o == null or is_content(o):
				return o
			if o is Fighter or o is World:
				push_error("SimState: a %s is not copied by value; store its id" % o.get_class())
				return null
			var c: Object = (o.get_script() as Script).new()
			for n: StringName in fields(o):
				c.set(n, copy(o.get(n)))
			return c
	return v


## The canonical form of a snapshot that state_hash() hashes.
static func canonical(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var a: Array = []
			for e: Variant in v:
				a.append(canonical(e))
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in v:
				d[String(k) if k is StringName else k] = canonical(v[k])
			return d
		TYPE_STRING_NAME:
			return String(v)
		TYPE_OBJECT:
			var o: Object = v
			if o == null:
				return null
			if o is V3:
				return [o.x, o.y, o.z]
			if o is V2:
				return [o.x, o.z]
			if o is WeaponDef:
				return "weapon:" + String(o.id)
			if o is AttackDef:
				return "move:" + String(o.id)
			if o is FighterBody:
				return "body:" + String(o.id)
			var d: Dictionary = {}
			for n: StringName in fields(o):
				d[String(n)] = canonical(o.get(n))
			return d
	return v


## SHA-256 (hex) of a snapshot's canonical form.
static func state_hash(snapshot: Variant) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(canonical(snapshot)))
	return ctx.finish().hex_encode()
