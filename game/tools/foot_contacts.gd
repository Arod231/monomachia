class_name FootContacts
extends RefCounted
## Each foot's contacts with the ground on a clip (milestone-1 task 14): the
## source frame a foot comes down (its plant) and the last source frame it
## stays down before it lifts (its lift), by FootLock's plant rule (the one
## PoseCheck's foot-slide measure uses, task 9): a foot is planted when its
## ankle comes within FootLock.PLANT_HEIGHT of its rest height, and stays
## planted until it rises above FootLock.LIFT_HEIGHT. FootLock's other
## release, a foot carried FootLock.SLIDE from where it came down, is left
## out: it is measured in the world, where the fighter's travel cancels the
## backward sweep of a clip played in place (a run's planted foot moves some
## 20 cm a source frame in the clip's own space).
##
## The clip manifest records each clip's contacts ("foot_contacts":
## {"left": [[plant, lift], ...], "right": [...]}, ClipManifest.Clip.foot_contacts);
## tools/measure_feet.gd measures them from the clip libraries and writes
## them there. Frame data and travel are generated from them (tasks 15, 16).

## The feet, by the manifest's name for each and the skeleton's side.
const SIDES: Dictionary[String, String] = {"left": "Left", "right": "Right"}
## The clip set the contacts are measured on: the Hunter's.
const SET: StringName = &"HumanM"


## One foot's contacts, [plant, lift] in source frames, from its ankle at
## each whole source frame of the clip (`ankles`, from frame 0, in the
## skeleton's space, up +Y) and the ankle's rest height. A foot down at the
## clip's end lifts on its last frame.
static func spans(ankles: PackedVector3Array, rest_height: float) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var held: bool = false
	var plant: int = -1
	for f: int in ankles.size():
		var a: Vector3 = ankles[f]
		if held and a.y > rest_height + FootLock.LIFT_HEIGHT:
			out.append(PackedInt32Array([plant, f - 1]))
			held = false
		if not held and a.y <= rest_height + FootLock.PLANT_HEIGHT:
			held = true
			plant = f
	if held:
		out.append(PackedInt32Array([plant, ankles.size() - 1]))
	return out


## The Hunter under `parent`, holding nothing, with the HumanM clips.
static func hunter(parent: Node) -> FighterModel:
	var model: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	model.autoplay_idle = false
	parent.add_child(model)
	model.animation_player.add_animation_library(SET, ClipLibraries.load_set(SET))
	return model


## Clip `id`'s contacts on `model` ({"left": [[plant, lift], ...], "right": ...}),
## sampled at each whole source frame.
static func measure(model: FighterModel, id: StringName) -> Dictionary:
	var poser: ClipPoser = ClipPoser.new(model, [ClipChain.qualified(SET, String(id))] as Array[String])
	var frames: int = roundi(poser.length * ClipManifest.SOURCE_FPS) + 1
	var sk: Skeleton3D = model.skeleton
	# Arrays of positions, not packed arrays: a packed array read out of a
	# Dictionary is a copy, and appending to it is lost
	var ankles: Dictionary = {}
	for side: String in SIDES:
		ankles[side] = []
	for f: int in frames:
		poser.pose(minf(float(f) / ClipManifest.SOURCE_FPS, poser.length))
		for side: String in SIDES:
			(ankles[side] as Array).append(sk.get_bone_global_pose(sk.find_bone(SIDES[side] + "Foot")).origin)
	var out: Dictionary = {}
	for side: String in SIDES:
		var rest: float = model.rig.rest_foot(SIDES[side]).y
		var found: Array = []
		for s: PackedInt32Array in spans(PackedVector3Array(ankles[side]), rest):
			found.append([s[0], s[1]])
		out[side] = found
	return out


## Whether two clips' contacts are the same frames.
static func same(a: Dictionary, b: Dictionary) -> bool:
	return json_text(a) == json_text(b)


## The manifest's `text` with each clip's "foot_contacts" set to
## `measured`'s (by clip id): replaced where there is one, else added after
## the clip's markers. Every other byte is left alone.
static func write(text: String, measured: Dictionary, errors: Array[String]) -> String:
	for id: Variant in measured:
		var value: String = json_text(measured[id])
		var why: Array[String] = []
		var span: Vector2i = SourceEdit.find_value(text, ["clips", String(id), "foot_contacts"] as Array[String], why)
		if span.x >= 0:
			text = text.substr(0, span.x) + value + text.substr(span.y)
			continue
		why.clear()
		var markers: Vector2i = SourceEdit.find_value(text, ["clips", String(id), "markers"] as Array[String], why)
		if markers.x < 0:
			errors.append("%s: %s" % [id, "; ".join(why)])
			continue
		text = text.substr(0, markers.y) + ",\n\t\t\t\"foot_contacts\": " + value + text.substr(markers.y)
	return text


## The manifest's text for a clip's contacts: {"left": [[a, b], ...], "right": [...]},
## on one line.
static func json_text(contacts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for side: String in SIDES:
		var spans_text: PackedStringArray = []
		for s: Variant in contacts.get(side, []):
			spans_text.append("[%d, %d]" % [int(s[0]), int(s[1])])
		parts.append("\"%s\": [%s]" % [side, ", ".join(spans_text)])
	return "{%s}" % ", ".join(parts)
