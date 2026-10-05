class_name ClipManifest
extends RefCounted
## The clip manifest (game/assets/kevin_iglesias/clip_manifest.json): every
## Iglesias clip the game uses, where it comes from in the packs, whether it
## is mirrored, whether it loops, and its four markers in source frames. It
## holds no animation data, so it is committed; the import tool converts the
## clips it names (tools/import_clips.gd).
##
## A clip's file in the packs is
## `<pack>/Animations/<Male|Female>/<dir>/<set>@<source>.fbx`, or, for a
## clip marked `shared` (the masked poses, whose files for both sets sit in
## one folder), `<pack>/Animations/<dir>/<set>@<source>.fbx`.
##
## A composed clip (authored-animation task 22) has no file of its own: the
## import tool builds it from two other clips, one on the upper body over
## the other's hips and legs (ImportClips.compose()), each from a source frame
## of its own ("compose": {"upper", "upper_from", "legs", "legs_from"}).
##
## Milestone-1 task 14 added the markers frame data and travel are generated
## from: each foot's contacts ("foot_contacts": {"left": [[plant, lift], ...],
## "right": [...]}, measured by tools/measure_feet.gd with FootLock's plant
## rule, FootContacts), and on a clip that sets a rules length its ready,
## in-hand, strike or kill frame (RULES_LENGTH_MARKERS, beside the four). A
## move's active frames, dodge-cancel window and branch points live on its
## entry in the move-clip table (MoveClips), since one clip serves moves of
## different timings.

const PATH: String = "res://assets/kevin_iglesias/clip_manifest.json"
## The markers, in the order they fall.
const MARKERS: Array[String] = ["windup", "contact", "contact_end", "settle"]
## The markers a clip that sets a rules length may add (milestone-1 task 14):
## the draw's ready frame (when "Fight!" is called), the pull-out's frame the
## weapon is in hand, the paired stomp's and leap's strike, a finisher's
## kill. No clip of today's sets one; the tasks that add those clips set them.
const RULES_LENGTH_MARKERS: Array[String] = ["ready", "in_hand", "strike", "kill"]
## The feet a clip's foot contacts are given for.
const FEET: Array[String] = ["left", "right"]
## Source clips are keyed at 30 frames a second.
const SOURCE_FPS: float = 30.0
## The catalogue's pages a clip can be on: a weapon's moves, bare hands,
## or the states shared by every weapon (tools/shot_scenes/clip_sheet.gd).
const GROUPS: Array[StringName] = [&"katana", &"greatsword", &"daggers", &"bare", &"states"]


## One clip of the manifest.
class Clip:
	## Its name in the libraries.
	var id: StringName
	var pack: String
	var dir: String
	## The clip's name in its file, after the set's `@`.
	var source: String
	var mirror: bool = false
	var loop: bool = false
	## Its files for every set sit in one folder, not the set's (file()).
	var shared: bool = false
	## Source frame of each marker, by MARKERS (and RULES_LENGTH_MARKERS) name.
	var markers: Dictionary[String, int] = {}
	## Each foot's contacts with the ground, [plant, lift] in source frames,
	## by "left" and "right" (FEET; tools/foot_contacts.gd measures them); empty when not measured.
	var foot_contacts: Dictionary = {}
	var provisional: bool = false
	## The catalogue pages it is a candidate on (GROUPS).
	var groups: Array[StringName] = []
	## A composed clip's two clips (ids of clips with files) and the source
	## frame each starts from; empty for a clip with a file.
	var upper: StringName = &""
	var upper_from: int = 0
	var legs: StringName = &""
	var legs_from: int = 0

	## Whether the import tool builds it from two other clips.
	func composed() -> bool:
		return upper != &""

	## The clip's file for a set, relative to the Iglesias packs' folder.
	func file(set_name: StringName, set_folder: String) -> String:
		if shared:
			return "%s/Animations/%s/%s@%s.fbx" % [pack, dir, set_name, source]
		return "%s/Animations/%s/%s/%s@%s.fbx" % [pack, set_folder, dir, set_name, source]


## Clip set name -> the packs' folder for it (Male or Female).
var sets: Dictionary[StringName, String] = {}
## By id, in id order.
var clips: Dictionary[StringName, Clip] = {}
## What is wrong with the file, one line each; empty when it read cleanly.
var errors: PackedStringArray = []


static func read(path: String = PATH) -> ClipManifest:
	var m: ClipManifest = ClipManifest.new()
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		m.errors.append("%s is not a JSON object" % path)
		return m
	var sets_data: Variant = (data as Dictionary).get("sets")
	if not sets_data is Dictionary or (sets_data as Dictionary).is_empty():
		m.errors.append("no sets")
	else:
		for key: Variant in sets_data:
			m.sets[StringName(key)] = str(sets_data[key])
	var clips_data: Variant = (data as Dictionary).get("clips")
	if not clips_data is Dictionary:
		m.errors.append("no clips")
		return m
	var ids: Array = (clips_data as Dictionary).keys()
	ids.sort()
	for key: Variant in ids:
		var c: Clip = m._clip(StringName(key), clips_data[key])
		if c != null:
			m.clips[c.id] = c
	for c: Clip in m.clips.values():
		if not c.composed():
			continue
		for part: StringName in [c.upper, c.legs]:
			if not m.clips.has(part) or m.clips[part].composed():
				m.errors.append("%s: composed from %s, which is not a clip with a file" % [c.id, part])
	return m


## The ids of the clips on a catalogue page, in order.
func in_group(group: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Clip in clips.values():
		if c.groups.has(group):
			out.append(c.id)
	return out


## The clips with files of their own (not composed), in id order.
func sourced() -> Array[Clip]:
	var out: Array[Clip] = []
	for c: Clip in clips.values():
		if not c.composed():
			out.append(c)
	return out


## The clips' ids, in order.
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(clips.keys())
	return out


func _clip(id: StringName, d: Variant) -> Clip:
	if not d is Dictionary:
		errors.append("%s: not an object" % id)
		return null
	var c: Clip = Clip.new()
	c.id = id
	var compose: Variant = (d as Dictionary).get("compose")
	if compose is Dictionary:
		c.upper = StringName(str(compose.get("upper", "")))
		c.legs = StringName(str(compose.get("legs", "")))
		if c.upper == &"" or c.legs == &"":
			errors.append("%s: a composed clip names its upper and legs clips" % id)
			c.upper = &"?" if c.upper == &"" else c.upper
		for field: String in ["upper_from", "legs_from"]:
			var v: Variant = compose.get(field, 0)
			if not (v is float or v is int) or float(v) != floorf(float(v)) or float(v) < 0.0:
				errors.append("%s: %s is not a whole source frame" % [id, field])
			else:
				c.set(field, int(v))
		if d.get("mirror", false) == true:
			errors.append("%s: a composed clip isn't mirrored" % id)
	elif compose != null:
		errors.append("%s: compose is not an object" % id)
	else:
		for field: String in ["pack", "dir", "source"]:
			if not (d as Dictionary).get(field) is String or str(d[field]) == "":
				errors.append("%s: no %s" % [id, field])
	c.pack = str(d.get("pack", ""))
	c.dir = str(d.get("dir", ""))
	c.source = str(d.get("source", ""))
	c.mirror = d.get("mirror", false) == true
	c.loop = d.get("loop", false) == true
	c.shared = d.get("shared", false) == true
	c.provisional = d.get("provisional", false) == true
	var groups: Variant = d.get("groups", [])
	if not groups is Array or (groups as Array).is_empty():
		errors.append("%s: no groups" % id)
	else:
		for g: Variant in groups:
			if not GROUPS.has(StringName(str(g))):
				errors.append("%s: unknown group %s" % [id, g])
			else:
				c.groups.append(StringName(str(g)))
	var marks: Variant = d.get("markers")
	if not marks is Dictionary:
		errors.append("%s: no markers" % id)
		return c
	var last: int = -1
	for name: String in MARKERS:
		var v: Variant = (marks as Dictionary).get(name)
		if not (v is float or v is int) or float(v) != floorf(float(v)) or float(v) < 0.0:
			errors.append("%s: marker %s missing or not a whole frame" % [id, name])
			continue
		c.markers[name] = int(v)
		if int(v) < last:
			errors.append("%s: marker %s comes before the one ahead of it" % [id, name])
		last = int(v)
	for name: Variant in marks:
		if RULES_LENGTH_MARKERS.has(str(name)):
			var v: Variant = marks[name]
			if not (v is float or v is int) or float(v) != floorf(float(v)) or float(v) < 0.0:
				errors.append("%s: marker %s is not a whole frame" % [id, name])
			else:
				c.markers[str(name)] = int(v)
		elif not MARKERS.has(str(name)):
			errors.append("%s: unknown marker %s" % [id, name])
	if (d as Dictionary).has("foot_contacts"):
		c.foot_contacts = _foot_contacts(id, d["foot_contacts"])
	return c


## A clip's foot contacts read from `d`, each mistake added to errors.
func _foot_contacts(id: StringName, d: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not d is Dictionary or (d as Dictionary).size() != FEET.size():
		errors.append("%s: foot_contacts gives left and right" % id)
		return out
	for side: String in FEET:
		var spans: Variant = (d as Dictionary).get(side)
		var ok: bool = spans is Array
		var last: int = -1
		var read: Array = []
		if ok:
			for s: Variant in spans:
				var pair: bool = s is Array and (s as Array).size() == 2 \
						and (s as Array).all(func(x: Variant) -> bool: return (x is float or x is int) and float(x) == floorf(float(x)))
				if not pair or int(s[0]) <= last or int(s[1]) < int(s[0]):
					ok = false
					break
				read.append([int(s[0]), int(s[1])])
				last = int(s[1])
		if not ok:
			errors.append("%s: foot_contacts %s must be [plant, lift] source frames, in order, each lift at or after its plant" % [id, side])
			continue
		out[side] = read
	return out
