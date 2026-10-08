class_name FrameDataRows
extends RefCounted
## The frame-data table's rows as the bake writes them (milestone-1 task
## 16; the rules read the table through FrameDataTable): each move's band
## kind, its chain, its generated frame data and travel, the gaits' measured
## speeds, the rules-length clips' lengths, the checksums, and the table's
## text, laid out the same way every run so the same bake writes the same
## bytes.

const ImportClips := preload("res://tools/import_clips.gd")

## The timing band table's rows (docs/specs/milestone-1.md), a move's kind.
const BAND_KINDS: Array[StringName] = [
	&"string_light", &"string_light_1h", &"string_last_1h", &"string_light_2h", &"string_last_2h",
	&"string_heavy", &"grip_heavy_1h", &"grip_heavy_2h", &"grip_heavy_follow_up", &"iai_draw", &"iai_follow_up", &"unblockable",
	&"sprint_light", &"sprint_heavy", &"dodge_light", &"dodge_heavy", &"backstep_light", &"backstep_heavy",
	&"jump_light", &"jump_heavy", &"block_ability", &"ultimate", &"counter_lunge",
]
## The rules-length clips this plan adds that have no clip yet: the starts,
## stops and pivots (task 57), the stomp's and the leap's paired clips (80,
## 81), the pull-out (87), the disarmed gaits (88), the finishers (104,
## 105), the draw (110), the round-end beats and the victory poses (111).
## Each task that keys one takes it off; task 112 finds the list empty.
const NOT_KEYED_YET: Array[String] = [
	"start", "stop", "pivot", "paired_stomp", "paired_leap", "pull_out", "disarmed_gait",
	"finisher_katana", "finisher_fists", "draw", "round_end_beat", "victory_pose",
]
## The order a row's fields are written in.
const FIELD_ORDER: Array[String] = [
	"kind", "chain", "stand_in", "startup", "active", "recovery", "landing", "hold", "dodge_cancel", "branches",
	"frames", "markers", "speed", "heading", "stride", "foot_contacts", "travel", "source_sha256", "digest",
]
## The rules-length clips the rules move a fighter by (milestone-1 task 99):
## their rows carry the body's travel over each rules frame, as a move's do.
## The recall burst's blasted fall.
const TRAVEL_CLIPS: Array[StringName] = [&"BlastedFall"]
const STATE_CLIPS: String = "res://assets/kevin_iglesias/state_clips.json"
const ABOUT: String = "The frame-data table (milestone-1 task 16): each move's frame data and travel generated from its clip at 1.0x by its markers (tools/frame_data_generator.gd), each gait's measured speed and each rules-length clip's length, with the checksums of their source clips and a digest of each row with its swing file's record (FrameDataTable). Written with the swing files by node scripts/godot.mjs bake; never edited by hand."


## The band kind of move `id` on weapon `w` (BAND_KINDS): by the slot it is
## played from (sprint, dodge, backstep, jump), else a counter lunge, a
## block ability (unblockable or not), an ultimate, an Iai draw (a stance
## charge, or the variant one draws as), a grip's own heavy keyed for it
## (grip_heavy_1h, grip_heavy_2h; KE task 16), a grip heavy's follow-up
## (Rising Heaven, after Heaven Splitter; KE task 17), an Iai follow-up (a
## heavy one follows), a light of the string, or a heavy of it. A move has one kind
## wherever it is played from.
static func kind_of(w: WeaponDef, id: StringName) -> StringName:
	var m: AttackDef = w.moves[id]
	for slot: Array in [[w.sprint_light, &"sprint_light"], [w.sprint_heavy, &"sprint_heavy"],
			[w.dodge_light, &"dodge_light"], [w.dodge_heavy, &"dodge_heavy"],
			[w.back_light, &"backstep_light"], [w.back_heavy, &"backstep_heavy"],
			[w.jump_light, &"jump_light"], [w.jump_heavy, &"jump_heavy"]]:
		if slot[0] == id:
			return slot[1]
	if m.special == &"counterLunge":
		return &"counter_lunge"
	if w.abilities.has(id):
		return &"unblockable" if m.unblockable else &"block_ability"
	if m.kind == &"ultimate":
		return &"ultimate"
	if is_iai_draw(w, id):
		return &"iai_draw"
	if m.kind == &"heavy" and m.grip != &"":
		for g: WeaponGrip in w.grips:
			if g.id == m.grip and g.heavy == id:
				return StringName("grip_heavy_" + ("1h" if m.grip == WeaponGrip.ONE_HANDED else "2h"))
	if m.kind == &"heavy":
		for g: WeaponGrip in w.grips:
			var heavy: AttackDef = w.moves.get(g.heavy, null)
			if heavy != null and heavy.grip == g.id and heavy.chain_heavy == id:
				return &"grip_heavy_follow_up"
	if m.kind != &"light":
		for other: StringName in w.moves:
			if is_iai_draw(w, other) and (w.moves[other] as AttackDef).chain_heavy == id:
				return &"iai_follow_up"
	if m.kind == &"light" and m.grip != &"":
		return grip_kind(w, id)
	return &"string_light" if m.kind == &"light" else &"string_heavy"


## A grip's own string hit's kind (KE task 11): its grip's light row
## (string_light_1h, string_light_2h), or its grip's last-hit row
## (string_last_1h, string_last_2h; D16) for the string's last hit.
static func grip_kind(w: WeaponDef, id: StringName) -> StringName:
	var m: AttackDef = w.moves[id]
	var suffix: String = "1h" if m.grip == WeaponGrip.ONE_HANDED else "2h"
	for g: WeaponGrip in w.grips:
		if g.id == m.grip and g.hit(WeaponGrip.STRING_HITS) == id:
			return StringName("string_last_" + suffix)
	return StringName("string_light_" + suffix)


## Whether move `id` is drawn from a stance: a charge walked in (the Iai),
## or the variant such a charge draws as.
static func is_iai_draw(w: WeaponDef, id: StringName) -> bool:
	if (w.moves[id] as AttackDef).charge_move:
		return true
	for other: StringName in w.moves:
		var m: AttackDef = w.moves[other]
		if m.charge_move and m.release_variant == id:
			return true
	return false


## The clips that set a rules length and exist today: every clip of the
## manifest the state clips name (StateClips' file), in id order.
static func rules_length_clips(manifest: ClipManifest, path: String = STATE_CLIPS) -> Array[StringName]:
	var found: Dictionary[StringName, bool] = {}
	_collect(JSON.parse_string(FileAccess.get_file_as_string(path)), manifest, found)
	var out: Array[StringName] = []
	out.assign(found.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func _collect(v: Variant, manifest: ClipManifest, found: Dictionary[StringName, bool]) -> void:
	if v is Dictionary:
		for k: Variant in v:
			if k != "about":
				_collect(v[k], manifest, found)
	elif v is Array:
		for x: Variant in v:
			_collect(x, manifest, found)
	elif v is String and manifest.clips.has(StringName(v)):
		found[StringName(v)] = true


## The gait clips the fighters walk, run and sprint on (Locomotion's pack
## clips), in id order.
static func gait_clips() -> Array[StringName]:
	var found: Dictionary[StringName, bool] = {}
	for gait: StringName in Locomotion.PACK_CLIPS:
		for c: Variant in Locomotion.PACK_CLIPS[gait]:
			if str(c) != "":
				found[StringName(str(c))] = true
	var out: Array[StringName] = []
	out.assign(found.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


## SHA-256 of the source files of clips `ids` (a manifest clip's FBX for
## HumanM or its export, a composed clip's two clips', a CC0 clip's library),
## each named, in order; empty, with an error, when one isn't there.
static func source_checksum(manifest: ClipManifest, ids: Array[StringName], errors: Array[String]) -> String:
	var lines: PackedStringArray = []
	for id: StringName in ids:
		var files: PackedStringArray = []
		if ClipChain.is_cc0(id):
			files.append(FighterModel.ANIMATION_LIBRARY.resource_path)
		elif manifest.clips.has(id):
			var clip: ClipManifest.Clip = manifest.clips[id]
			for part: ClipManifest.Clip in ([manifest.clips[clip.upper], manifest.clips[clip.legs]] if clip.composed() else [clip]):
				files.append(ImportClips.source_path(manifest, &"HumanM", part))
		for f: String in files:
			if not FileAccess.file_exists(f):
				errors.append("%s: no source file %s" % [id, f])
				return ""
			lines.append("%s %s" % [id, FileAccess.get_sha256(f)])
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update("\n".join(lines).to_utf8_buffer())
	return ctx.finish().hex_encode()


## A chain as the table records it: each part's clip and source frames
## ("from" and "to", or "hold": frames held at "from").
static func chain_record(parts: Array[ClipChain.Part]) -> Array:
	var out: Array = []
	for p: ClipChain.Part in parts:
		var d: Dictionary = {"clip": String(p.id), "from": p.from}
		if p.hold > 0.0:
			d["hold"] = p.hold
		else:
			d["to"] = p.to
		out.append(d)
	return out


## The band kinds of the jump attacks, whose keyed rows carry their landing
## recovery (milestone-1 tasks 59 and 94).
const JUMP_KINDS: Array[StringName] = [&"jump_light", &"jump_heavy"]


## A move's row from its generated frame data (without its digest). A keyed
## jump attack's landing is its recovery: it holds its last active pose to
## the touchdown, then plays its recovery (ClipDirector.attack_frame()).
static func move_row(kind: StringName, parts: Array[ClipChain.Part], stand_in: bool, r: FrameDataGenerator.Result, sha: String) -> Dictionary:
	var row: Dictionary = {"kind": String(kind), "chain": chain_record(parts)}
	if stand_in:
		row["stand_in"] = true
	row["startup"] = r.startup
	row["active"] = r.active
	row["recovery"] = r.recovery
	if JUMP_KINDS.has(kind) and not stand_in:
		row["landing"] = r.recovery
	if r.hold != AttackDef.UNSET and not stand_in:
		row["hold"] = r.hold
	if not r.dodge_cancel.is_empty():
		row["dodge_cancel"] = Array(r.dodge_cancel)
	if not r.branches.is_empty():
		var b: Dictionary = {}
		for follow: StringName in r.branches:
			b[String(follow)] = Array(r.branches[follow])
		row["branches"] = b
	row["travel"] = r.travel_record()
	row["source_sha256"] = sha
	return row


## A gait clip's row: its measure (FrameDataGenerator.gait()), its length
## in rules frames and its foot contacts.
static func gait_row(measure: Dictionary, length: float, contacts: Dictionary, sha: String) -> Dictionary:
	return {"frames": roundi(length * ClipTiming.RULES_FPS), "speed": snappedf(measure["speed"], 0.0001),
		"heading": snappedf(measure["heading"], 0.01), "stride": snappedf(measure["stride"], 0.0001),
		"foot_contacts": contacts, "source_sha256": sha}


## A rules-length clip's row: its length and its markers (the manifest's,
## whole source frames) in rules frames at 1.0x, and for one of TRAVEL_CLIPS
## its travel (clip_travel()).
static func clip_row(clip: ClipManifest.Clip, length: float, sha: String, travel: Array = []) -> Dictionary:
	var markers: Dictionary = {}
	for name: String in ClipManifest.MARKERS + ClipManifest.RULES_LENGTH_MARKERS:
		if clip.markers.has(name):
			markers[name] = roundi(clip.markers[name] * MoveClips.RULES_PER_SOURCE)
	var row: Dictionary = {"frames": roundi(length * ClipTiming.RULES_FPS), "markers": markers}
	if not travel.is_empty():
		row["travel"] = travel
	row["source_sha256"] = sha
	return row


## The body's travel over a rules-length clip (one of TRAVEL_CLIPS), read by
## the frame-data generator from its markers (its windup, contact,
## contact_end and settle as a move's windup, active_start, active_end and
## settle), one rules frame to a row; empty, with an error, when it can't be.
static func clip_travel(pose: Callable, length: float, id: StringName, clip: ClipManifest.Clip, errors: Array[String]) -> Array:
	var m: Dictionary = clip.markers
	var markers: Dictionary = {"windup": m.get("windup"), "active_start": m.get("contact"), "active_end": m.get("contact_end"), "settle": m.get("settle")}
	var why: Array[String] = []
	var r: FrameDataGenerator.Result = FrameDataGenerator.generate(pose, length, markers, clip.foot_contacts, [] as Array[StringName], why)
	if r == null:
		errors.append("%s: %s" % [id, "; ".join(why)])
		return []
	return r.travel_record()


## `row` as the table will read it back, with its digest (FrameDataTable.
## digest()) over it and `swing_record` (the move's record as read back from
## its swing file; null for none).
static func sealed(row: Dictionary, swing_record: Variant) -> Dictionary:
	var read: Dictionary = JSON.parse_string(_value("", row))
	read["digest"] = FrameDataTable.digest(read, swing_record)
	return read


## The table's text: the about line, then the moves by weapon, the gaits and
## the clips, one row to a line, the fields in FIELD_ORDER, then the clips
## not keyed yet.
static func table_text(moves: Dictionary, gaits: Dictionary, clips: Dictionary, not_keyed: Array) -> String:
	var lines: PackedStringArray = ["{", "\t\"about\": %s," % JSON.stringify(ABOUT), "\t\"moves\": {"]
	var weapons: Array = moves.keys()
	for i: int in weapons.size():
		lines.append("\t\t\"%s\": {" % weapons[i])
		_rows(lines, moves[weapons[i]], "\t\t\t")
		lines.append("\t\t}%s" % ("," if i < weapons.size() - 1 else ""))
	lines.append("\t},")
	lines.append("\t\"gaits\": {")
	_rows(lines, gaits, "\t\t")
	lines.append("\t},")
	lines.append("\t\"clips\": {")
	_rows(lines, clips, "\t\t")
	lines.append("\t},")
	lines.append("\t\"not_keyed_yet\": %s" % _value("", not_keyed))
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _rows(lines: PackedStringArray, rows: Dictionary, indent: String) -> void:
	var ids: Array = rows.keys()
	for i: int in ids.size():
		lines.append("%s\"%s\": %s%s" % [indent, ids[i], _value("", rows[ids[i]]), "," if i < ids.size() - 1 else ""])


static func _value(field: String, v: Variant) -> String:
	if v is Dictionary:
		var keys: Array = FIELD_ORDER.filter(func(k: String) -> bool: return (v as Dictionary).has(k))
		for k: Variant in v:
			if not keys.has(str(k)):
				keys.append(str(k))
		var fields: PackedStringArray = []
		for k: String in keys:
			fields.append("%s: %s" % [JSON.stringify(k), _value(k, v[k])])
		return "{%s}" % ", ".join(fields)
	if v is Array or v is PackedInt32Array or v is PackedFloat64Array:
		return "[%s]" % ", ".join(Array(v).map(func(x: Variant) -> String: return _value(field, x)))
	if typeof(v) == TYPE_BOOL:
		return "true" if v else "false"
	if v is String or v is StringName:
		return JSON.stringify(str(v))
	var x: float = float(v)
	if x == roundf(x):
		return str(int(x))
	return String.num(x, 4)
