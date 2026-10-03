class_name SwingFile
extends RefCounted
## Reads a weapon's swing file (tasks 7.2 and 7.4): one JSON file per weapon
## under DIR. It holds the weapon's guard, a pose for each part its swings
## move, and the swings, by move id, each {"tracks": {part: [key, ...]}}. Keys
## are objects of the fields below; vectors are [right, up, forward] (see Swing).
##
##   {"guard": {"right_hand": {"grip": [0.05, 1.1, 0.3], "blade": [0.1, 0.5, 0.86], "edge": [0, -1, 0]},
##              "body": {"torso": 0, "pelvis": 0}},
##    "swings": {"k_l1": {"tracks": {
##      "right_hand": [{"frame": 0, "grip": [0.07, 1.07, 0.36], "blade": [-0.12, 0.45, 0.88], "edge": [0, -1, 0], "ease": 0}, ...],
##      "body": [{"frame": 0, "torso": 0, "pelvis": 0}, ...]}}}}
##
## Each swing enters from the guard (or from the previous move's last key, when
## it follows one) and exits back to it, so the guard must have every part the
## swings move. A track that strikes (a hand or a foot) is keyed from the last
## frame of the startup through the last active frame, so the frames that sweep
## for hits are the same however the move was entered.
##
## A file with any mistake is refused whole, with an error per mistake, so a
## weapon never plays some moves on half-read data: an unknown move, field or
## part; a missing field; a frame that isn't whole, is negative or is past the
## move's last frame; keys out of order; a striking track that doesn't key the
## frames that can hit; a part the guard lacks; a vector that isn't three
## numbers; a blade with no direction or an edge along the blade; a negative
## ease. The swing editor (task 14b) writes these files back with a stable key
## order and fixed decimals.

const DIR: String = "res://sim/moves/swings/"

## The fields of a guard pose for each kind of part: true when required. A
## key of a swing's track has these, a frame (required) and an ease.
const LIMB_FIELDS: Dictionary[String, bool] = {"grip": true, "blade": true, "edge": true, "pole": false}
const BODY_FIELDS: Dictionary[String, bool] = {"torso": true, "pelvis": true, "pelvis_shift": false}
const KEY_FIELDS: Dictionary[String, bool] = {"frame": true, "ease": false}
const FILE_FIELDS: Array[String] = ["guard", "swings"]
const SWING_FIELDS: Array[String] = ["tracks"]


## Where the swings of the weapon `weapon_id` live.
static func path_for(weapon_id: StringName) -> String:
	return DIR + String(weapon_id) + ".json"


## Puts each swing of the file at `path` on its move in `moves`. A weapon with
## no file has no swings yet; a refused file gives none either.
static func attach(path: String, moves: Dictionary[StringName, AttackDef]) -> void:
	if not FileAccess.file_exists(path):
		return
	var swings: Dictionary[StringName, Swing] = read(path, moves)
	for id: StringName in swings:
		moves[id].swing = swings[id]


## The swings in the file at `path`, by move id, for the weapon whose moves
## are `moves`: none, with errors, when the file is refused.
static func read(path: String, moves: Dictionary[StringName, AttackDef]) -> Dictionary[StringName, Swing]:
	if not FileAccess.file_exists(path):
		push_error("%s: no such swing file" % path)
		return {}
	return parse(FileAccess.get_file_as_string(path), moves, path)


## The swings in a swing file's text, as read() gives them; `source` names the
## file in the errors.
static func parse(text: String, moves: Dictionary[StringName, AttackDef], source: String) -> Dictionary[StringName, Swing]:
	var errors: Array[String] = []
	var out: Dictionary[StringName, Swing] = {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		errors.append("line %d: %s" % [json.get_error_line(), json.get_error_message()])
	elif not json.data is Dictionary:
		errors.append("the file must be an object holding guard and swings")
	else:
		var data: Dictionary = json.data
		for field: Variant in data:
			if not FILE_FIELDS.has(str(field)):
				errors.append("unknown field %s" % field)
		var guard: Dictionary[StringName, Swing.KeyPose] = {}
		var guard_read: bool = false
		if not data.get("guard") is Dictionary or (data["guard"] as Dictionary).is_empty():
			errors.append("needs a guard, an object of parts")
		else:
			var before: int = errors.size()
			guard = _guard(data["guard"], errors)
			guard_read = errors.size() == before
		if not data.get("swings") is Dictionary:
			errors.append("needs swings, an object of moves")
		else:
			var swings: Dictionary = data["swings"]
			for move_id: Variant in swings:
				var id := StringName(str(move_id))
				if not moves.has(id):
					errors.append("%s: not a move of this weapon" % id)
					continue
				var swing: Swing = _swing(swings[move_id], moves[id], String(id), guard, guard_read, errors)
				if swing != null:
					out[id] = swing
	if not errors.is_empty():
		for e: String in errors:
			push_error("%s: %s (swing file refused)" % [source, e])
		return {}
	return out


static func _guard(record: Dictionary, errors: Array[String]) -> Dictionary[StringName, Swing.KeyPose]:
	var out: Dictionary[StringName, Swing.KeyPose] = {}
	for part_name: Variant in record:
		var part := StringName(str(part_name))
		var at: String = "guard.%s" % part
		if not Swing.PARTS.has(part):
			errors.append("%s: unknown part (the parts are %s)" % [at, ", ".join(Swing.PARTS)])
			continue
		var d: Variant = record[part_name]
		if not d is Dictionary:
			errors.append("%s: a guard pose must be an object" % at)
			continue
		var fields: Dictionary[String, bool] = BODY_FIELDS if part == &"body" else LIMB_FIELDS
		if not _has_fields(d, fields, at, errors):
			continue
		var k: Swing.KeyPose = Swing.KeyPose.new()
		if _pose(d, part == &"body", k, at, errors):
			out[part] = k
	return out


## `guard_read`: the guard was read without a mistake, so a part it lacks is
## the swing's mistake.
static func _swing(record: Variant, move: AttackDef, where: String, guard: Dictionary[StringName, Swing.KeyPose],
		guard_read: bool, errors: Array[String]) -> Swing:
	if not record is Dictionary:
		errors.append("%s: a swing must be an object" % where)
		return null
	for field: Variant in record:
		if not SWING_FIELDS.has(str(field)):
			errors.append("%s: unknown field %s" % [where, field])
	var tracks: Variant = (record as Dictionary).get("tracks")
	if not tracks is Dictionary or (tracks as Dictionary).is_empty():
		errors.append("%s: needs tracks, an object of parts" % where)
		return null
	var swing: Swing = Swing.new(move.total_frames(), guard)
	for part_name: Variant in tracks:
		var part := StringName(str(part_name))
		var at: String = "%s.%s" % [where, part]
		if not Swing.PARTS.has(part):
			errors.append("%s: unknown part (the parts are %s)" % [at, ", ".join(Swing.PARTS)])
			continue
		var before: int = errors.size()
		var keys: Array[Swing.KeyPose] = _keys(tracks[part_name], part == &"body", move.total_frames(), at, errors)
		if errors.size() != before:
			continue
		if part != &"body":
			# a striking track keys the frames whose sweeps can hit: from the
			# last startup frame (the first active frame sweeps from it) through
			# the last active frame
			if keys[0].frame > move.startup:
				errors.append("%s: the first key is at frame %d; it must be at frame %d or before, so hits don't depend on the entry"
						% [at, keys[0].frame, move.startup])
			if keys[-1].frame < move.startup + move.active:
				errors.append("%s: the last key is at frame %d; it must be at frame %d or after, so hits don't depend on the exit"
						% [at, keys[-1].frame, move.startup + move.active])
		if guard_read and not guard.has(part):
			errors.append("%s: the guard has no %s for the entry and exit" % [at, part])
		if errors.size() == before:
			swing.add_track(part, keys)
	return swing


static func _keys(list: Variant, body: bool, last_frame: int, where: String, errors: Array[String]) -> Array[Swing.KeyPose]:
	var out: Array[Swing.KeyPose] = []
	if not list is Array or (list as Array).is_empty():
		errors.append("%s: a track must be a list of keys" % where)
		return out
	var fields: Dictionary[String, bool] = (BODY_FIELDS if body else LIMB_FIELDS).duplicate()
	fields.merge(KEY_FIELDS)
	var previous: int = -1
	for i: int in (list as Array).size():
		var record: Variant = list[i]
		var at: String = "%s key %d" % [where, i]
		if not record is Dictionary:
			errors.append("%s: a key must be an object" % at)
			continue
		var d: Dictionary = record
		if not _has_fields(d, fields, at, errors):
			continue
		var k: Swing.KeyPose = Swing.KeyPose.new()
		var frame: Variant = d["frame"]
		if not _is_number(frame) or float(frame) != floorf(float(frame)):
			errors.append("%s: frame must be a whole number" % at)
			continue
		k.frame = int(frame)
		at = "%s (frame %d)" % [at, k.frame]
		if k.frame < 0:
			errors.append("%s: frame is negative" % at)
		elif k.frame > last_frame:
			errors.append("%s: frame is past the move, whose last frame is %d" % [at, last_frame])
		if i > 0 and k.frame <= previous:
			errors.append("%s: keys are unsorted (frame %d comes after frame %d)" % [at, k.frame, previous])
		previous = k.frame
		k.ease = _number(d, "ease", 1.0, at, errors)
		if k.ease < 0.0:
			errors.append("%s: ease must not be negative" % at)
		if _pose(d, body, k, at, errors):
			out.append(k)
	return out


## Whether `d` holds only `fields` and all the required ones; errors if not.
static func _has_fields(d: Dictionary, fields: Dictionary[String, bool], where: String, errors: Array[String]) -> bool:
	var ok: bool = true
	for field: Variant in d:
		if not fields.has(str(field)):
			errors.append("%s: unknown field %s" % [where, field])
			ok = false
	for field: String in fields:
		if fields[field] and not d.has(field):
			errors.append("%s: missing %s" % [where, field])
			ok = false
	return ok


## Reads the pose fields of `d` into `k`: the grip, blade, edge and pole of a
## hand or foot, or the coil and pelvis shift of the body. False, with an
## error, for a blade with no direction or an edge along the blade.
static func _pose(d: Dictionary, body: bool, k: Swing.KeyPose, where: String, errors: Array[String]) -> bool:
	if body:
		k.torso = _number(d, "torso", 0.0, where, errors)
		k.pelvis = _number(d, "pelvis", 0.0, where, errors)
		k.pelvis_shift = _vector(d, "pelvis_shift", where, errors)
		return true
	k.grip = _vector(d, "grip", where, errors)
	k.pole = _vector(d, "pole", where, errors)
	var blade: V3 = _vector(d, "blade", where, errors)
	var edge: V3 = _vector(d, "edge", where, errors)
	if V3.length(blade) < 1e-9:
		errors.append("%s: blade has no direction" % where)
		return false
	k.blade = V3.normalized(blade)
	var square: V3 = V3.sub(edge, V3.scale(k.blade, V3.dot(edge, k.blade)))
	if V3.length(square) < 1e-6:
		errors.append("%s: edge runs along the blade" % where)
		return false
	k.edge = V3.normalized(square)
	return true


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


static func _number(d: Dictionary, field: String, default: float, where: String, errors: Array[String]) -> float:
	if not d.has(field):
		return default
	if not _is_number(d[field]):
		errors.append("%s: %s must be a number" % [where, field])
		return default
	return float(d[field])


## The [right, up, forward] vector `field` of `d`, or zero when it's absent.
static func _vector(d: Dictionary, field: String, where: String, errors: Array[String]) -> V3:
	if not d.has(field):
		return V3.make()
	var v: Variant = d[field]
	if not v is Array or (v as Array).size() != 3 or not (_is_number(v[0]) and _is_number(v[1]) and _is_number(v[2])):
		errors.append("%s: %s must be three numbers [right, up, forward]" % [where, field])
		return V3.make()
	return V3.make(float(v[0]), float(v[1]), float(v[2]))
