extends SceneTree
## Builds the hand-keyed clip library (KeyedClips): every key-pose file in
## KeyedClips.KEYS_FOLDER solved on the Hunter's skeleton (KeyedPose) and
## saved together at KeyedClips.PATH, as text so a re-key shows in review.
##
## Run: node scripts/godot.mjs script res://tools/build_keyed_clips.gd
##
## A key file names its clip ("name"), its length in rules frames
## ("frames"), the CC0 clip whose first frame gives the bones no key poses
## ("base", a name in the UAL library) and its keys (see KeyedPose).


func _initialize() -> void:
	var model: FighterModel = FighterLook.instantiate_fighter(&"hunter")
	model.autoplay_idle = false
	root.add_child(model)
	var out: AnimationLibrary = AnimationLibrary.new()
	var files: PackedStringArray = DirAccess.get_files_at(KeyedClips.KEYS_FOLDER)
	for file: String in files:
		if not file.ends_with(".json"):
			continue
		var path: String = KeyedClips.KEYS_FOLDER.path_join(file)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			printerr("build_keyed_clips: %s is not a JSON object" % path)
			quit(1)
			return
		var problem: String = check(data)
		if problem != "":
			printerr("build_keyed_clips: %s: %s" % [path, problem])
			quit(1)
			return
		var base: Animation = FighterModel.ANIMATION_LIBRARY.get_animation(StringName(data["base"]))
		var anim: Animation = KeyedPose.build(data, model.skeleton, base)
		out.add_animation(StringName(data["name"]), anim)
		print("build_keyed_clips: %s, %d keys over %d frames" % [data["name"], (data["keys"] as Array).size(), int(data["frames"])])
	var err: Error = ResourceSaver.save(out, KeyedClips.PATH)
	if err != OK:
		printerr("build_keyed_clips: cannot save %s (%s)" % [KeyedClips.PATH, error_string(err)])
		quit(1)
		return
	print("build_keyed_clips: %d clips saved to %s" % [out.get_animation_list().size(), KeyedClips.PATH])
	quit(0)


## What is wrong with key file `data`, or "".
static func check(data: Dictionary) -> String:
	for field: String in ["name", "frames", "base", "keys"]:
		if not data.has(field):
			return "no \"%s\"" % field
	if not FighterModel.ANIMATION_LIBRARY.has_animation(StringName(data["base"])):
		return "base clip %s is not in the UAL library" % data["base"]
	var keys: Array = data["keys"]
	if keys.size() < 2:
		return "fewer than two keys"
	var last: float = -1.0
	var limbs: String = ""
	for key: Dictionary in keys:
		var f: float = float(key.get("f", -1.0))
		if f <= last or f > float(data["frames"]):
			return "key frames must rise within 0..frames (at %s)" % key.get("f")
		last = f
		# every key poses the same limbs, so each track has a key at each
		var these: String = "%s|%s" % [(key.get("legs", {}) as Dictionary).keys(), (key.get("arms", {}) as Dictionary).keys()]
		if limbs != "" and these != limbs:
			return "key %d poses other limbs than the first" % int(f)
		limbs = these
	return ""
